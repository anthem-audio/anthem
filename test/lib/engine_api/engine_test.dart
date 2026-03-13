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
  _TestEngineConnector Function() getConnector,
) async {
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

    setUp(() {
      project = MockProjectModel();
      visualizationProvider = MockVisualizationProvider();
      processingGraph = MockProcessingGraphModel();
      nodes = AnthemObservableMap<Id, NodeModel>();

      when(project.visualizationProvider).thenReturn(visualizationProvider);
      when(project.processingGraph).thenReturn(processingGraph);
      when(processingGraph.nodes).thenReturn(nodes);

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
        expect(connector.startHeartbeatTimerCallCount, 0);

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitResponse(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );

        await startFuture;

        expect(engine.engineState, EngineState.running);
        expect(connector.startHeartbeatTimerCallCount, 1);
        verify(project.initializeEngine()).called(1);
      },
    );

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

        await startFuture;

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [
            EngineReadyCheckRequest,
            ModelInitRequest,
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
      'AudioReadyEvent updates audio state and completes audioReadyFuture',
      () async {
        await _startEngineThroughInit(engine, () => connector);

        final audioReadyFuture = engine.audioReadyFuture;
        connector.emitResponse(AudioReadyEvent(id: -1));

        await audioReadyFuture;

        expect(engine.isAudioReady, isTrue);
      },
    );

    test(
      'VisualizationUpdateEvent is forwarded to the project visualization provider',
      () async {
        await _startEngineThroughInit(engine, () => connector);

        final update = VisualizationUpdateEvent(
          id: -1,
          items: [
            VisualizationItem(id: 'cpu', values: [0.5]),
          ],
        );

        connector.emitResponse(update);

        verify(visualizationProvider.processVisualizationUpdate(any)).called(1);
      },
    );

    test('plugin change events schedule a node state update', () async {
      final node = MockNodeModel();
      nodes[1] = node;

      await _startEngineThroughInit(engine, () => connector);

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

      await _startEngineThroughInit(engine, () => connector);

      connector.emitResponse(PluginLoadedEvent(id: -1, nodeId: 1));

      await pluginLoadedCompleter.future;

      expect(pluginLoadedCompleter.isCompleted, isTrue);
    });
  });
}
