/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem_codegen/include.dart' show AnthemObservableMap;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<ProjectModel>(),
  MockSpec<VisualizationProvider>(),
  MockSpec<ProcessingGraphModel>(),
  MockSpec<NodeModel>(),
])
import 'engine_test.mocks.dart';

class _TestEngineConnector extends EngineConnectorBase {
  final Completer<bool> _onInitCompleter = Completer<bool>();
  final void Function()? _onExit;

  final List<Request> sentRequests = [];
  var startHeartbeatTimerCallCount = 0;
  var isDisposed = false;

  _TestEngineConnector({
    required super.kDebugMode,
    super.noHeartbeat = false,
    super.onReply,
    void Function()? onExit,
  }) : _onExit = onExit {
    onInit = _onInitCompleter.future;
  }

  void completeInit([bool success = true]) {
    if (!_onInitCompleter.isCompleted) {
      _onInitCompleter.complete(success);
    }
  }

  void emitResponse(Response response) {
    final payload = utf8.encode(jsonEncode(response.toJson()));
    final framedResponse = Uint8List(payload.length + 8);
    final header = ByteData.sublistView(framedResponse, 0, 8);
    header.setUint64(0, payload.length, Endian.host);
    framedResponse.setRange(8, framedResponse.length, payload);
    onReceive(framedResponse);
  }

  void emitExit() {
    _onExit?.call();
  }

  @override
  void send(Uint8List bytes) {
    sentRequests.add(
      Request.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>),
    );
  }

  @override
  void startHeartbeatTimer() {
    startHeartbeatTimerCallCount++;
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _startEngineThroughInit(
  Engine engine,
  _TestEngineConnector Function() getConnector, {
  required EngineAudioConfig audioConfig,
}) async {
  final startFuture = engine.start();
  final connector = getConnector();

  connector.completeInit();
  await _flushMicrotasks();

  final readyCheckRequest =
      connector.sentRequests.single as EngineReadyCheckRequest;
  connector.emitResponse(
    EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
  );
  await _flushMicrotasks();

  final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
  connector.emitResponse(
    ModelInitResponse(id: modelInitRequest.id, success: true),
  );
  await _flushMicrotasks();

  final startAudioRequest = connector.sentRequests[2] as StartAudioRequest;
  connector.emitResponse(
    StartAudioResponse(
      id: startAudioRequest.id,
      success: true,
      audioConfig: audioConfig,
    ),
  );

  await startFuture;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Engine', () {
    late MockProjectModel project;
    late MockVisualizationProvider visualizationProvider;
    late MockProcessingGraphModel processingGraph;
    late AnthemObservableMap<Id, NodeModel> nodes;
    late _TestEngineConnector connector;
    late Engine engine;
    late EngineAudioConfig startupAudioConfig;

    setUp(() {
      project = MockProjectModel();
      visualizationProvider = MockVisualizationProvider();
      processingGraph = MockProcessingGraphModel();
      nodes = AnthemObservableMap<Id, NodeModel>();

      when(project.visualizationProvider).thenReturn(visualizationProvider);
      when(project.processingGraph).thenReturn(processingGraph);
      when(processingGraph.nodes).thenReturn(nodes);
      startupAudioConfig = EngineAudioConfig(
        sampleRate: 48000,
        blockSize: 256,
        inputChannelCount: 2,
        outputChannelCount: 2,
      );

      EngineConnectorBase createConnector(
        int id, {
        required bool kDebugMode,
        void Function(Response)? onReply,
        void Function()? onExit,
        bool noHeartbeat = false,
        String? enginePathOverride,
      }) {
        connector = _TestEngineConnector(
          kDebugMode: kDebugMode,
          noHeartbeat: noHeartbeat,
          onReply: onReply,
          onExit: onExit,
        );
        return connector;
      }

      engine = Engine(123, project, engineConnectorFactory: createConnector);

      when(
        project.initializeEngine(),
      ).thenAnswer((_) => engine.modelSyncApi.initModel('test project'));
    });

    test(
      'start sends a ready check first, then flushes model init, then starts heartbeat',
      () async {
        EngineAudioConfig? audioConfigWhenRunning;
        engine.engineStateStream.listen((state) {
          if (state == EngineState.running) {
            audioConfigWhenRunning = engine.audioConfig;
          }
        });

        final startFuture = engine.start();

        connector.completeInit();
        await _flushMicrotasks();

        expect(engine.engineState, EngineState.starting);
        expect(connector.sentRequests, hasLength(1));
        expect(connector.sentRequests.single, isA<EngineReadyCheckRequest>());
        expect(connector.startHeartbeatTimerCallCount, 0);

        final readyCheckRequest =
            connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitResponse(
          EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
        );

        await _flushMicrotasks();

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [EngineReadyCheckRequest, ModelInitRequest],
        );
        expect(engine.engineState, EngineState.starting);
        expect(engine.audioConfig, isNull);
        expect(connector.startHeartbeatTimerCallCount, 0);

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitResponse(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );
        await _flushMicrotasks();

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [EngineReadyCheckRequest, ModelInitRequest, StartAudioRequest],
        );
        expect(engine.audioConfig, isNull);

        final startAudioRequest =
            connector.sentRequests[2] as StartAudioRequest;
        connector.emitResponse(
          StartAudioResponse(
            id: startAudioRequest.id,
            success: true,
            audioConfig: startupAudioConfig,
          ),
        );

        await startFuture;
        await _flushMicrotasks();

        expect(engine.engineState, EngineState.running);
        expect(connector.startHeartbeatTimerCallCount, 1);
        expect(engine.audioConfig?.sampleRate, startupAudioConfig.sampleRate);
        expect(engine.audioConfig?.blockSize, startupAudioConfig.blockSize);
        expect(
          audioConfigWhenRunning?.sampleRate,
          startupAudioConfig.sampleRate,
        );
        expect(audioConfigWhenRunning?.blockSize, startupAudioConfig.blockSize);
        expect(
          audioConfigWhenRunning?.inputChannelCount,
          startupAudioConfig.inputChannelCount,
        );
        expect(
          audioConfigWhenRunning?.outputChannelCount,
          startupAudioConfig.outputChannelCount,
        );
        verify(project.initializeEngine()).called(1);
      },
    );

    test('startup can skip audio init and graph compile', () async {
      final startFuture = engine.start(initializeAudio: false);

      connector.completeInit();
      await _flushMicrotasks();

      final readyCheckRequest =
          connector.sentRequests.single as EngineReadyCheckRequest;
      connector.emitResponse(
        EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
      );

      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [EngineReadyCheckRequest, ModelInitRequest],
      );

      final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
      connector.emitResponse(
        ModelInitResponse(id: modelInitRequest.id, success: true),
      );

      await startFuture;
      await _flushMicrotasks();

      expect(engine.engineState, EngineState.running);
      expect(engine.audioConfig, isNull);
      expect(connector.startHeartbeatTimerCallCount, 1);

      final compileFuture = engine.processingGraphApi.compile();
      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [
          EngineReadyCheckRequest,
          ModelInitRequest,
          CompileProcessingGraphRequest,
        ],
      );

      final compileRequest =
          connector.sentRequests[2] as CompileProcessingGraphRequest;
      connector.emitResponse(
        CompileProcessingGraphResponse(id: compileRequest.id, success: true),
      );

      await compileFuture;
      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [
          EngineReadyCheckRequest,
          ModelInitRequest,
          CompileProcessingGraphRequest,
        ],
      );
      verify(project.initializeEngine()).called(1);
    });

    test(
      'startup-safe requests queue during startup and flush in order',
      () async {
        final startFuture = engine.start();

        connector.completeInit();
        await _flushMicrotasks();

        final readyCheckRequest =
            connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitResponse(
          EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
        );

        await _flushMicrotasks();

        engine.visualizationApi.setUpdateInterval(12.5);
        engine.modelSyncApi.updateModel(
          updateKind: FieldUpdateKind.set,
          fieldAccesses: [
            FieldAccess(fieldType: FieldType.raw, fieldName: 'name'),
          ],
          serializedValue: '"Queued update"',
        );

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [EngineReadyCheckRequest, ModelInitRequest],
        );

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitResponse(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );
        await _flushMicrotasks();

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [EngineReadyCheckRequest, ModelInitRequest, StartAudioRequest],
        );

        final startAudioRequest =
            connector.sentRequests[2] as StartAudioRequest;
        connector.emitResponse(
          StartAudioResponse(
            id: startAudioRequest.id,
            success: true,
            audioConfig: startupAudioConfig,
          ),
        );

        await startFuture;

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [
            EngineReadyCheckRequest,
            ModelInitRequest,
            StartAudioRequest,
            SetVisualizationUpdateIntervalRequest,
            ModelUpdateRequest,
          ],
        );
      },
    );

    test(
      'stop during startup handshake disposes the connector and returns to stopped',
      () async {
        final startFuture = engine.start();

        connector.completeInit();
        await _flushMicrotasks();

        expect(connector.sentRequests.single, isA<EngineReadyCheckRequest>());

        await engine.stop();
        await startFuture;

        expect(engine.engineState, EngineState.stopped);
        expect(connector.isDisposed, isTrue);
        expect(connector.startHeartbeatTimerCallCount, 0);
      },
    );

    test(
      'audio startup failure stops the engine after model init succeeds',
      () async {
        final startFuture = engine.start();

        connector.completeInit();
        await _flushMicrotasks();

        final readyCheckRequest =
            connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitResponse(
          EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
        );
        await _flushMicrotasks();

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitResponse(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );
        await _flushMicrotasks();

        final startAudioRequest =
            connector.sentRequests[2] as StartAudioRequest;
        connector.emitResponse(
          StartAudioResponse(
            id: startAudioRequest.id,
            success: false,
            error: 'No audio device available.',
          ),
        );

        await startFuture;

        expect(engine.engineState, EngineState.stopped);
        expect(engine.audioConfig, isNull);
        expect(connector.isDisposed, isTrue);
        expect(connector.startHeartbeatTimerCallCount, 0);
      },
    );

    test(
      'AudioReadyEvent updates audio state and completes audioReadyFuture',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );

        final audioReadyFuture = engine.audioReadyFuture;
        final restartedAudioConfig = EngineAudioConfig(
          sampleRate: 44100,
          blockSize: 512,
          inputChannelCount: 0,
          outputChannelCount: 2,
        );
        connector.emitResponse(
          AudioReadyEvent(id: -1, audioConfig: restartedAudioConfig),
        );

        await audioReadyFuture;

        expect(engine.isAudioReady, isTrue);
        expect(engine.audioConfig?.sampleRate, restartedAudioConfig.sampleRate);
        expect(engine.audioConfig?.blockSize, restartedAudioConfig.blockSize);
      },
    );

    test(
      'VisualizationUpdateEvent is forwarded to the project visualization provider',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );

        final update = VisualizationUpdateEvent(
          id: -1,
          items: [
            VisualizationItem(
              id: 'cpu',
              valueType: VisualizationValueType.doubleValue,
              values: [0.5],
              sampleTimestamps: [1],
            ),
          ],
        );

        connector.emitResponse(update);

        verify(visualizationProvider.processVisualizationUpdate(any)).called(1);
      },
    );

    test('plugin change events schedule a node state update', () async {
      final node = MockNodeModel();
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitResponse(
        PluginChangedEvent(
          id: -1,
          nodeId: 1,
          latencyChanged: false,
          parameterInfoChanged: false,
          programChanged: false,
          nonParameterStateChanged: true,
        ),
      );
      connector.emitResponse(
        PluginParameterChangedEvent(
          id: -1,
          nodeId: 1,
          parameterIndex: 0,
          newValue: 0.75,
        ),
      );

      verify(node.scheduleDebouncedStateUpdate()).called(2);
    });

    test('PluginLoadedEvent completes the node plugin completer', () async {
      final node = MockNodeModel();
      final pluginLoadedCompleter = Completer<void>();
      when(node.pluginLoadedCompleter).thenReturn(pluginLoadedCompleter);
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitResponse(PluginLoadedEvent(id: -1, nodeId: 1));

      await pluginLoadedCompleter.future;

      expect(pluginLoadedCompleter.isCompleted, isTrue);
    });

    test('stopping the engine clears the engine audio config', () async {
      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      expect(engine.audioConfig, isNotNull);

      connector.emitExit();
      await _flushMicrotasks();

      expect(engine.engineState, EngineState.stopped);
      expect(engine.audioConfig, isNull);
    });
  });
}
