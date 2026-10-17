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
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/visualization/visualization.dart';
import 'package:anthem_codegen/include.dart'
    show AnthemObservableList, AnthemObservableMap;
import 'package:flutter/foundation.dart';
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

  final List<IpcMessage> sentRequests = [];
  var startHeartbeatTimerCallCount = 0;
  var finalizeVisualizationSharedMemorySetupCallCount = 0;
  var isDisposed = false;
  Object? sendError;
  Completer<void>? shutdownCompletion;
  int? reportedExitCode;

  @override
  int? get processExitCode => reportedExitCode;

  _TestEngineConnector({
    required super.kDebugMode,
    super.noHeartbeat = false,
    super.onMessage,
    super.onConnectionClosed,
    this._onExit,
  }) {
    onInit = _onInitCompleter.future;
  }

  void completeInit([bool success = true]) {
    if (!_onInitCompleter.isCompleted) {
      _onInitCompleter.complete(success);
    }
  }

  void emitMessage(IpcMessage message) {
    onReceive(_frameMessage(message));
  }

  void emitExit() {
    _onExit?.call();
  }

  @override
  void sendBytes(Uint8List bytes) {
    final error = sendError;
    if (error != null) throw error;
    sentRequests.add(
      IpcMessage.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      ),
    );
  }

  @override
  void startHeartbeatTimer() {
    startHeartbeatTimerCallCount++;
  }

  @override
  void finalizeVisualizationSharedMemorySetup() {
    finalizeVisualizationSharedMemorySetupCallCount++;
  }

  @override
  Future<void> shutdown({Duration timeout = const Duration(seconds: 5)}) async {
    dispose();
    final completion = shutdownCompletion;
    if (completion != null) await completion.future;
  }

  @override
  void dispose() {
    completeInit(false);
    isDisposed = true;
    super.dispose();
  }
}

Uint8List _frameMessage(IpcMessage response) {
  final payload = utf8.encode(jsonEncode(response.toJson()));
  final framedResponse = Uint8List(payload.length + 8);
  final header = ByteData.sublistView(framedResponse, 0, 8);
  // Payloads fit in 32 bits; the upper half is already zero. JavaScript does
  // not implement ByteData's 64-bit accessors.
  header.setUint32(
    Endian.host == Endian.little ? 0 : 4,
    payload.length,
    Endian.host,
  );
  framedResponse.setRange(8, framedResponse.length, payload);
  return framedResponse;
}

Uint8List _frameMessages(Iterable<IpcMessage> responses) {
  final builder = BytesBuilder();
  for (final response in responses) {
    builder.add(_frameMessage(response));
  }
  return builder.toBytes();
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _startEngineThroughInit(
  Engine engine,
  _TestEngineConnector Function() getConnector, {
  required AudioProcessingConfigDto audioConfig,
}) async {
  final startFuture = engine.start();
  await _flushMicrotasks();
  final connector = getConnector();

  connector.completeInit();
  await _flushMicrotasks();

  final readyCheckRequest =
      connector.sentRequests.single as EngineReadyCheckRequest;
  connector.emitMessage(
    EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
  );
  await _flushMicrotasks();

  final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
  connector.emitMessage(
    ModelInitResponse(id: modelInitRequest.id, success: true),
  );
  await _flushMicrotasks();

  final startAudioRequest = connector.sentRequests[2] as StartAudioRequest;
  connector.emitMessage(
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

  test('sequence compile requests have distinct wire types', () {
    final arrangementRequest = CompileArrangementRequest(
      id: 1,
      tracksToRebuild: <Id>[2],
      invalidationRanges: <InvalidationRange>[
        InvalidationRange(start: 3, end: 4),
      ],
    );
    final arrangementJson = arrangementRequest.toJson();

    expect(arrangementJson['__type'], 'CompileArrangementRequest');
    expect(arrangementJson, isNot(contains('arrangementId')));
    expect(Request.fromJson(arrangementJson), isA<CompileArrangementRequest>());

    final patternRequest = CompilePatternRequest(id: 5, patternId: 6);
    final patternJson = patternRequest.toJson();

    expect(patternJson['__type'], 'CompilePatternRequest');
    expect(patternJson['patternId'], 6);
    expect(Request.fromJson(patternJson), isA<CompilePatternRequest>());
  });

  test('engine connector decodes responses split across transport chunks', () {
    final responses = <IpcMessage>[];
    final connector = _TestEngineConnector(
      kDebugMode: false,
      onMessage: responses.add,
    );
    final frame = _frameMessage(
      EngineReadyCheckResponse(id: 12, success: true),
    );

    for (var i = 0; i < frame.length; i++) {
      connector.onReceive(Uint8List.sublistView(frame, i, i + 1));
    }

    expect(responses, hasLength(1));
    expect(responses.single, isA<EngineReadyCheckResponse>());
    expect((responses.single as Response).id, 12);
  });

  group('Engine', () {
    late MockProjectModel project;
    late MockVisualizationProvider visualizationProvider;
    late MockProcessingGraphModel processingGraph;
    late AnthemObservableMap<Id, NodeModel> nodes;
    late _TestEngineConnector connector;
    late Engine engine;
    late AudioProcessingConfigDto startupAudioConfig;

    setUp(() {
      project = MockProjectModel();
      visualizationProvider = MockVisualizationProvider();
      processingGraph = MockProcessingGraphModel();
      nodes = AnthemObservableMap<Id, NodeModel>();

      when(project.visualizationProvider).thenReturn(visualizationProvider);
      when(project.processingGraph).thenReturn(processingGraph);
      when(processingGraph.nodes).thenReturn(nodes);
      startupAudioConfig = AudioProcessingConfigDto(
        sampleRate: 48000,
        blockSize: 256,
        inputChannelCount: 2,
        outputChannelCount: 2,
      );
      EngineConnectorBase createConnector(
        int id, {
        required bool kDebugMode,
        void Function(IpcMessage)? onMessage,
        void Function()? onExit,
        void Function()? onConnectionClosed,
        bool noHeartbeat = false,
        String? enginePathOverride,
      }) {
        connector = _TestEngineConnector(
          kDebugMode: kDebugMode,
          noHeartbeat: noHeartbeat,
          onMessage: onMessage,
          onExit: onExit,
          onConnectionClosed: onConnectionClosed,
        );
        return connector;
      }

      engine = Engine(123, project, engineConnectorFactory: createConnector);

      when(project.initializeEngine())
          .thenAnswer((_) => engine.modelSyncApi.initModel('test project'));
    });

    test('engine requests receive responses during startup and render without completing UI requests', () async {
      final startup = engine.start(initializeAudio: false);
      connector.completeInit();
      await _flushMicrotasks();
      final readyRequest =
          connector.sentRequests.single as EngineReadyCheckRequest;

      connector.emitMessage(AudioSessionInvalidatedEvent(reason: 'test'));
      await _flushMicrotasks();
      expect(engine.engineState, EngineState.starting);

      connector.emitMessage(
        TestUiEchoRequest(id: readyRequest.id, value: 'during startup'),
      );
      await _flushMicrotasks();
      expect(engine.engineState, EngineState.starting);
      final reply = connector.sentRequests.last as RequestErrorResponse;
      expect(reply.id, readyRequest.id);
      expect(reply.code, RequestErrorCode.unsupported);
      expect(reply.message, 'Unsupported engine request: TestUiEchoRequest.');

      connector.emitMessage(
        EngineReadyCheckResponse(id: readyRequest.id, success: true),
      );
      await _flushMicrotasks();
      final modelInit = connector.sentRequests.last as ModelInitRequest;
      connector.emitMessage(ModelInitResponse(id: modelInit.id, success: true));
      await startup;
      expect(engine.engineState, EngineState.running);

      engine.holdRequestsForRender();
      connector.emitMessage(TestUiEchoRequest(id: 42, value: 'during render'));
      await _flushMicrotasks();
      final renderReply = connector.sentRequests.last as RequestErrorResponse;
      expect(renderReply.id, 42);
      expect(renderReply.code, RequestErrorCode.unsupported);
      engine.releaseRequestsHeldForRender();
      connector.emitExit();
      await engine.dispose();
    });

    test('start sends a ready check first, then flushes model init, then enables desktop heartbeat', () async {
      AudioProcessingConfigDto? audioConfigWhenRunning;
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
      connector.emitMessage(
        EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
      );

      await _flushMicrotasks();

      expect(connector.finalizeVisualizationSharedMemorySetupCallCount, 1);

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [EngineReadyCheckRequest, ModelInitRequest],
      );
      expect(engine.engineState, EngineState.starting);
      expect(engine.audioConfig, isNull);
      expect(connector.startHeartbeatTimerCallCount, 0);

      final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
      connector.emitMessage(
        ModelInitResponse(id: modelInitRequest.id, success: true),
      );
      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [EngineReadyCheckRequest, ModelInitRequest, StartAudioRequest],
      );
      expect(engine.audioConfig, isNull);

      final startAudioRequest = connector.sentRequests[2] as StartAudioRequest;
      connector.emitMessage(
        StartAudioResponse(
          id: startAudioRequest.id,
          success: true,
          audioConfig: startupAudioConfig,
        ),
      );

      await startFuture;
      await _flushMicrotasks();

      expect(engine.engineState, EngineState.running);
      expect(connector.startHeartbeatTimerCallCount, kIsWeb ? 0 : 1);
      expect(engine.audioConfig?.sampleRate, startupAudioConfig.sampleRate);
      expect(engine.audioConfig?.blockSize, startupAudioConfig.blockSize);
      expect(audioConfigWhenRunning?.sampleRate, startupAudioConfig.sampleRate);
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
    });

    test('startup can skip audio init and graph publish', () async {
      final startFuture = engine.start(initializeAudio: false);

      connector.completeInit();
      await _flushMicrotasks();

      final readyCheckRequest =
          connector.sentRequests.single as EngineReadyCheckRequest;
      connector.emitMessage(
        EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
      );

      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [EngineReadyCheckRequest, ModelInitRequest],
      );

      final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
      connector.emitMessage(
        ModelInitResponse(id: modelInitRequest.id, success: true),
      );

      await startFuture;
      await _flushMicrotasks();

      expect(engine.engineState, EngineState.running);
      expect(engine.audioConfig, isNull);
      expect(connector.startHeartbeatTimerCallCount, kIsWeb ? 0 : 1);

      final initializeFuture = engine.processingGraphApi.initializeNodes();
      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [
          EngineReadyCheckRequest,
          ModelInitRequest,
          InitializeProcessingGraphNodesRequest,
        ],
      );

      final initializeRequest =
          connector.sentRequests[2] as InitializeProcessingGraphNodesRequest;
      connector.emitMessage(
        InitializeProcessingGraphNodesResponse(
          id: initializeRequest.id,
          didInitialize: true,
          results: [
            ProcessingGraphNodeInitializationResult(nodeId: 7, success: true),
          ],
        ),
      );

      final initialization = await initializeFuture;
      expect(initialization.didInitialize, isTrue);
      expect(initialization.results, hasLength(1));
      expect(initialization.results.single.nodeId, equals(7));
      expect(initialization.results.single.success, isTrue);

      final publishFuture = engine.processingGraphApi.publish();
      await _flushMicrotasks();

      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [
          EngineReadyCheckRequest,
          ModelInitRequest,
          InitializeProcessingGraphNodesRequest,
          PublishProcessingGraphRequest,
        ],
      );

      final publishRequest =
          connector.sentRequests[3] as PublishProcessingGraphRequest;
      connector.emitMessage(
        PublishProcessingGraphResponse(id: publishRequest.id, success: true),
      );

      await publishFuture;
      expect(
        connector.sentRequests.map((request) => request.runtimeType).toList(),
        [
          EngineReadyCheckRequest,
          ModelInitRequest,
          InitializeProcessingGraphNodesRequest,
          PublishProcessingGraphRequest,
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
        connector.emitMessage(
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
        connector.emitMessage(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );
        await _flushMicrotasks();

        expect(
          connector.sentRequests.map((request) => request.runtimeType).toList(),
          [EngineReadyCheckRequest, ModelInitRequest, StartAudioRequest],
        );

        final startAudioRequest =
            connector.sentRequests[2] as StartAudioRequest;
        connector.emitMessage(
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
      'stopping cancels the session before Exit and process cleanup finish',
      () async {
        final states = <EngineState>[];
        final subscription = engine.engineStateStream.listen(states.add);
        addTearDown(subscription.cancel);
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        final ended = engine.sessionEnded;
        final pending = expectLater(
          engine.modelSyncApi.debugGetEngineJson(),
          throwsStateError,
        );
        engine.holdRequestsForRender();
        final held = expectLater(
          engine.processingGraphApi.publish(),
          throwsStateError,
        );
        connector.shutdownCompletion = Completer<void>();

        final stopping = engine.stop();
        expect(engine.engineState, EngineState.stopping);
        expect(engine.isRunning, isFalse);
        expect(engine.isAudioReady, isFalse);
        expect(engine.audioConfig, isNull);
        await ended;
        await pending;
        await held;
        await expectLater(
          engine.modelSyncApi.debugGetEngineJson(),
          throwsStateError,
        );
        await _flushMicrotasks();

        final exit = connector.sentRequests.last as Exit;
        connector.emitMessage(ExitReply(id: exit.id));
        await _flushMicrotasks();
        expect(connector.isDisposed, isTrue);
        expect(engine.engineState, EngineState.stopping);

        connector.shutdownCompletion!.complete();
        await stopping;
        await _flushMicrotasks();
        expect(engine.engineState, EngineState.stopped);
        expect(states, [
          EngineState.starting,
          EngineState.running,
          EngineState.stopping,
          EngineState.stopped,
        ]);
      },
    );

    test(
      'a send failure ends the session and fails pending requests',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        final pending = expectLater(
          engine.modelSyncApi.debugGetEngineJson(
            timeout: const Duration(days: 1),
          ),
          throwsStateError,
        );
        final sentBeforeFailure = connector.sentRequests.length;
        connector.shutdownCompletion = Completer<void>();
        connector.sendError = StateError('IPC write failed.');

        final failedSend = expectLater(
          engine.modelSyncApi.debugGetEngineJson(
            timeout: const Duration(days: 1),
          ),
          throwsStateError,
        );
        await pending;
        await failedSend;
        await engine.sessionEnded;
        expect(connector.isDisposed, isTrue);
        expect(engine.engineState, EngineState.stopping);
        expect(connector.sentRequests, hasLength(sentBeforeFailure));

        connector.shutdownCompletion!.complete();
        await engine.stop();
        expect(engine.engineState, EngineState.stopped);
      },
    );

    test(
      'connection loss ends only its own session and waits for cleanup',
      () async {
        await engine.sessionEnded;
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        final firstConnector = connector;
        final firstSession = engine.sessionEnded;
        firstConnector.shutdownCompletion = Completer<void>();
        firstConnector.dispose();
        expect(engine.engineState, EngineState.stopping);
        await firstSession;
        firstConnector.shutdownCompletion!.complete();
        await engine.stop();
        expect(engine.engineState, EngineState.stopped);

        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        var replacementEnded = false;
        final replacementSession = engine.sessionEnded;
        expect(replacementSession, isNot(same(firstSession)));
        unawaited(
          replacementSession.then<void>((_) {
            replacementEnded = true;
          }),
        );
        firstConnector.emitExit();
        await _flushMicrotasks();
        expect(engine.engineState, EngineState.running);
        expect(replacementEnded, isFalse);
        await firstSession;

        connector.dispose();
        await engine.stop();
        await replacementSession;
      },
    );

    test(
      'cleanup failure leaves the engine stopping until cleanup succeeds',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        connector.shutdownCompletion = Completer<void>();
        connector.dispose();
        final failedCleanup = expectLater(engine.stop(), throwsStateError);
        await engine.sessionEnded;
        await _flushMicrotasks();
        connector.shutdownCompletion!.completeError(
          StateError('Cleanup failed.'),
        );
        await failedCleanup;
        expect(engine.engineState, EngineState.stopping);

        connector.shutdownCompletion = Completer<void>()..complete();
        await engine.stop();
        expect(engine.engineState, EngineState.stopped);
      },
    );

    test('confirmed process exit ends stopping even when shutdown reports an error', () async {
      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );
      connector.shutdownCompletion = Completer<void>();
      connector.dispose();
      final stopping = expectLater(engine.stop(), throwsStateError);
      await _flushMicrotasks();
      connector.reportedExitCode = 9;
      connector.shutdownCompletion!.completeError(StateError('Forced exit.'));
      await stopping;
      expect(engine.engineState, EngineState.stopped);
    });

    test(
      'restart waits for process cleanup before creating a new connector',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        final original = connector;
        original.shutdownCompletion = Completer<void>();
        original.dispose();
        final restart = engine.start(initializeAudio: false);
        await _flushMicrotasks();
        expect(connector, same(original));
        expect(engine.engineState, EngineState.stopping);

        original.shutdownCompletion!.complete();
        await _flushMicrotasks();
        expect(connector, isNot(same(original)));
        connector.completeInit();
        await _flushMicrotasks();
        final ready = connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitMessage(
          EngineReadyCheckResponse(id: ready.id, success: true),
        );
        await _flushMicrotasks();
        final init = connector.sentRequests.last as ModelInitRequest;
        connector.emitMessage(ModelInitResponse(id: init.id, success: true));
        await restart;
        expect(engine.engineState, EngineState.running);
        connector.dispose();
        await engine.stop();
      },
    );

    test('connection loss during initialization waits for cleanup before start returns', () async {
      final startup = engine.start(initializeAudio: false);
      connector.shutdownCompletion = Completer<void>();
      var startupFinished = false;
      unawaited(
        startup.then<void>((_) {
          startupFinished = true;
        }),
      );
      connector.dispose();
      await engine.sessionEnded;
      await _flushMicrotasks();
      expect(engine.engineState, EngineState.stopping);
      expect(startupFinished, isFalse);

      connector.shutdownCompletion!.complete();
      await startup;
      expect(engine.engineState, EngineState.stopped);
    });

    test('stop during startup handshake disposes the connector and returns to stopped', () async {
      final startFuture = engine.start();

      connector.completeInit();
      await _flushMicrotasks();

      expect(connector.sentRequests.single, isA<EngineReadyCheckRequest>());

      await engine.stop();
      await startFuture;

      expect(engine.engineState, EngineState.stopped);
      expect(connector.isDisposed, isTrue);
      expect(connector.startHeartbeatTimerCallCount, 0);
    });

    test('shared memory setup failure stops startup', () async {
      final startFuture = engine.start();

      connector.completeInit();
      await _flushMicrotasks();

      final readyCheckRequest =
          connector.sentRequests.single as EngineReadyCheckRequest;
      connector.emitMessage(
        EngineReadyCheckResponse(
          id: readyCheckRequest.id,
          success: false,
          error: 'Could not open shared memory.',
        ),
      );

      await startFuture;

      expect(engine.engineState, EngineState.stopped);
      expect(connector.isDisposed, isTrue);
      expect(connector.finalizeVisualizationSharedMemorySetupCallCount, 0);
      expect(connector.sentRequests, hasLength(1));
    });

    test(
      'audio startup failure stops the engine after model init succeeds',
      () async {
        final startFuture = engine.start();

        connector.completeInit();
        await _flushMicrotasks();

        final readyCheckRequest =
            connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitMessage(
          EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
        );
        await _flushMicrotasks();

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitMessage(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );
        await _flushMicrotasks();

        final startAudioRequest =
            connector.sentRequests[2] as StartAudioRequest;
        connector.emitMessage(
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

    test('AudioReadyEvent updates audio state', () async {
      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      final restartedAudioConfig = AudioProcessingConfigDto(
        sampleRate: 44100,
        blockSize: 512,
        inputChannelCount: 0,
        outputChannelCount: 2,
      );
      connector.emitMessage(AudioReadyEvent(audioConfig: restartedAudioConfig));

      expect(engine.isAudioReady, isTrue);
      expect(engine.audioConfig?.sampleRate, restartedAudioConfig.sampleRate);
      expect(engine.audioConfig?.blockSize, restartedAudioConfig.blockSize);
    });

    test(
      'AudioSessionInvalidatedEvent clears audio state and allows stop',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );

        final invalidationReasons = <String?>[];
        final subscription = engine.audioSessionInvalidatedStream.listen(
          invalidationReasons.add,
        );

        connector.emitMessage(
          AudioSessionInvalidatedEvent(reason: 'The audio device restarted.'),
        );

        await _flushMicrotasks();

        expect(engine.isAudioReady, isFalse);
        expect(engine.audioConfig, isNull);
        expect(
          invalidationReasons,
          orderedEquals(['The audio device restarted.']),
        );

        final stopAudioFuture = engine.stopAudio();
        await _flushMicrotasks();

        expect(connector.sentRequests.last, isA<StopAudioRequest>());

        final stopAudioRequest =
            connector.sentRequests.last as StopAudioRequest;
        connector.emitMessage(
          StopAudioResponse(id: stopAudioRequest.id, success: true),
        );

        await stopAudioFuture;
        await subscription.cancel();

        expect(engine.engineState, EngineState.running);
        expect(engine.isAudioReady, isFalse);
        expect(engine.audioConfig, isNull);
      },
    );

    test('stopAudio sends StopAudioRequest and clears audio state without stopping engine', () async {
      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      expect(engine.isAudioReady, isTrue);

      final stopAudioFuture = engine.stopAudio();
      await _flushMicrotasks();

      expect(connector.sentRequests.last, isA<StopAudioRequest>());

      final stopAudioRequest = connector.sentRequests.last as StopAudioRequest;
      connector.emitMessage(
        StopAudioResponse(id: stopAudioRequest.id, success: true),
      );

      await stopAudioFuture;

      expect(engine.engineState, EngineState.running);
      expect(engine.isAudioReady, isFalse);
      expect(engine.audioConfig, isNull);
      expect(connector.startHeartbeatTimerCallCount, kIsWeb ? 0 : 1);
    });

    test(
      'startAudio can start audio after startup skipped audio init',
      () async {
        final startFuture = engine.start(initializeAudio: false);

        connector.completeInit();
        await _flushMicrotasks();

        final readyCheckRequest =
            connector.sentRequests.single as EngineReadyCheckRequest;
        connector.emitMessage(
          EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
        );
        await _flushMicrotasks();

        final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
        connector.emitMessage(
          ModelInitResponse(id: modelInitRequest.id, success: true),
        );

        await startFuture;
        await _flushMicrotasks();

        expect(engine.engineState, EngineState.running);
        expect(engine.audioConfig, isNull);

        final startAudioFuture = engine.startAudio();
        await _flushMicrotasks();

        expect(connector.sentRequests.last, isA<StartAudioRequest>());

        final startAudioRequest =
            connector.sentRequests.last as StartAudioRequest;
        connector.emitMessage(
          StartAudioResponse(
            id: startAudioRequest.id,
            success: true,
            audioConfig: startupAudioConfig,
          ),
        );

        final audioConfig = await startAudioFuture;

        expect(audioConfig.sampleRate, startupAudioConfig.sampleRate);
        expect(engine.audioConfig?.sampleRate, startupAudioConfig.sampleRate);
        expect(engine.isAudioReady, isTrue);
      },
    );

    test('render API starts a render session and forwards progress', () async {
      final startFuture = engine.start(initializeAudio: false);

      connector.completeInit();
      await _flushMicrotasks();

      final readyCheckRequest =
          connector.sentRequests.single as EngineReadyCheckRequest;
      connector.emitMessage(
        EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
      );
      await _flushMicrotasks();

      final modelInitRequest = connector.sentRequests[1] as ModelInitRequest;
      connector.emitMessage(
        ModelInitResponse(id: modelInitRequest.id, success: true),
      );

      await startFuture;
      await _flushMicrotasks();

      final renderEvents = <IpcEvent>[];
      final subscription = engine.renderEventStream.listen(renderEvents.add);

      final startRenderFuture = engine.renderApi.startRenderAudioSession(
        sampleRate: 48000,
        blockSize: 256,
        outputChannelCount: 2,
      );
      await _flushMicrotasks();

      final startRenderRequest =
          connector.sentRequests.last as StartRenderAudioSessionRequest;
      connector.emitMessage(
        StartRenderAudioSessionResponse(
          id: startRenderRequest.id,
          success: true,
          audioConfig: AudioProcessingConfigDto(
            sampleRate: 48000,
            blockSize: 256,
            inputChannelCount: 0,
            outputChannelCount: 2,
          ),
        ),
      );

      final audioConfig = await startRenderFuture;

      expect(audioConfig.sampleRate, equals(48000));
      expect(engine.isAudioReady, isTrue);
      expect(engine.audioConfig?.blockSize, equals(256));

      final renderFuture = engine.renderApi.renderAudio(
        renderId: 42,
        outputPath: r'C:\renders\test.wav',
        format: RenderAudioFormat.wav,
        startTick: 0,
        endTick: 384,
        includeTail: false,
        bitDepth: 32,
        qualityOptionIndex: 0,
        sampleFormat: RenderAudioSampleFormat.floatingPoint,
      );
      await _flushMicrotasks();

      final renderRequest = connector.sentRequests.last as RenderAudioRequest;
      expect(renderRequest.renderId, equals(42));
      expect(renderRequest.outputPath, equals(r'C:\renders\test.wav'));
      expect(renderRequest.format, equals(RenderAudioFormat.wav));
      expect(renderRequest.startTick, equals(0));
      expect(renderRequest.endTick, equals(384));
      expect(renderRequest.includeTail, isFalse);
      expect(renderRequest.bitDepth, equals(32));
      expect(renderRequest.qualityOptionIndex, equals(0));
      expect(
        renderRequest.sampleFormat,
        equals(RenderAudioSampleFormat.floatingPoint),
      );

      connector.emitMessage(RenderStartedEvent(renderId: 42));
      connector.emitMessage(RenderProgressEvent(renderId: 42, progress: 0.5));
      connector.emitMessage(RenderCompletedEvent(renderId: 42));
      connector.emitMessage(
        RenderAudioResponse(id: renderRequest.id, success: true, renderId: 42),
      );

      final renderStartResult = await renderFuture;
      await _flushMicrotasks();

      await subscription.cancel();

      expect(renderStartResult.renderId, equals(42));
      expect(renderEvents, hasLength(3));
      expect(renderEvents[0], isA<RenderStartedEvent>());
      expect(renderEvents[1], isA<RenderProgressEvent>());
      expect(renderEvents[2], isA<RenderCompletedEvent>());
      expect((renderEvents[1] as RenderProgressEvent).progress, equals(0.5));
    });

    test(
      'render hold queues ordinary requests while render API requests continue',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );

        engine.holdRequestsForRender();
        expect(engine.areRequestsHeldForRender, isTrue);

        final previousModelUpdateCount = connector.sentRequests
            .whereType<ModelUpdateRequest>()
            .length;
        final previousPublishCount = connector.sentRequests
            .whereType<PublishProcessingGraphRequest>()
            .length;

        engine.modelSyncApi.updateModel(
          updateKind: FieldUpdateKind.set,
          fieldAccesses: [
            FieldAccess(fieldType: FieldType.raw, fieldName: 'name'),
          ],
          serializedValue: '"Queued during render"',
        );
        final publishFuture = engine.processingGraphApi.publish();
        await _flushMicrotasks();

        expect(
          connector.sentRequests.whereType<ModelUpdateRequest>(),
          hasLength(previousModelUpdateCount),
        );
        expect(
          connector.sentRequests.whereType<PublishProcessingGraphRequest>(),
          hasLength(previousPublishCount),
        );

        final renderPublishFuture = engine.processingGraphApi
            .publishForRender();
        await _flushMicrotasks();

        expect(
          connector.sentRequests.whereType<PublishProcessingGraphRequest>(),
          hasLength(previousPublishCount + 1),
        );
        final renderPublishRequest = connector.sentRequests
            .whereType<PublishProcessingGraphRequest>()
            .last;
        connector.emitMessage(
          PublishProcessingGraphResponse(
            id: renderPublishRequest.id,
            success: true,
          ),
        );
        await renderPublishFuture;

        await _flushMicrotasks();
        expect(
          connector.sentRequests.whereType<ModelUpdateRequest>(),
          hasLength(previousModelUpdateCount),
        );
        expect(
          connector.sentRequests.whereType<PublishProcessingGraphRequest>(),
          hasLength(previousPublishCount + 1),
        );

        engine.releaseRequestsHeldForRender();
        await _flushMicrotasks();

        expect(engine.areRequestsHeldForRender, isFalse);
        expect(
          connector.sentRequests.whereType<ModelUpdateRequest>(),
          hasLength(previousModelUpdateCount + 1),
        );
        expect(
          connector.sentRequests.whereType<PublishProcessingGraphRequest>(),
          hasLength(previousPublishCount + 2),
        );

        final publishRequest = connector.sentRequests
            .whereType<PublishProcessingGraphRequest>()
            .last;
        connector.emitMessage(
          PublishProcessingGraphResponse(id: publishRequest.id, success: true),
        );

        await publishFuture;
      },
    );

    test(
      'binary visualization records retain their metadata when forwarded',
      () async {
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        final record = VisualizationRecord(
          sequence: 1,
          generation: 2,
          sampleRate: 48000,
          newestSampleTimestamp: 0,
          items: [],
          discontinuity: true,
        );
        connector.handleVisualizationRecord(record);
        verify(visualizationProvider.processVisualizationRecord(record))
            .called(1);
      },
    );

    test('connector continues processing later responses after a handler exception', () {
      final receivedResponses = <IpcMessage>[];
      final connector = _TestEngineConnector(
        kDebugMode: false,
        onMessage: (response) {
          if (response is AudioSessionInvalidatedEvent) {
            throw StateError('Synthetic event handler failure.');
          }

          receivedResponses.add(response);
        },
      );

      connector.onReceive(
        _frameMessages([
          AudioSessionInvalidatedEvent(reason: 'device disconnected'),
          StopAudioResponse(id: 7, success: true),
        ]),
      );

      expect(receivedResponses, hasLength(1));
      expect(receivedResponses.single, isA<StopAudioResponse>());
    });

    test('plugin change events schedule a node state update', () async {
      final node = MockNodeModel();
      when(node.controlInputPorts).thenReturn(
        AnthemObservableList.of([
          NodePortModel(
            nodeId: 1,
            id: 100,
            config: NodePortConfigModel(
              dataType: NodePortDataType.control,
              parameterConfig: ParameterConfigModel(
                id: 100,
                factoryDefaultValue: 0,
              ),
            ),
          ),
        ]),
      );
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitMessage(
        PluginChangedEvent(
          nodeId: 1,
          latencyChanged: false,
          parameterInfoChanged: false,
          programChanged: false,
          nonParameterStateChanged: true,
        ),
      );
      connector.emitMessage(
        PluginParameterChangedEvent(nodeId: 1, controlPortId: 100, value: 0.75),
      );

      verify(node.touchControlInputParameter(any)).called(1);
      verify(node.scheduleDebouncedStateUpdate()).called(2);
    });

    test('plugin parameter snapshots update values without scheduling state update', () async {
      final node = MockNodeModel();
      final port = NodePortModel(
        nodeId: 1,
        id: 100,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: 100,
            factoryDefaultValue: 0,
            displayMode: ParameterDisplayMode.pluginText,
          ),
        ),
      );

      when(node.controlInputPorts).thenReturn(AnthemObservableList.of([port]));
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitMessage(
        PluginParameterSnapshotEvent(
          nodeId: 1,
          parameterValues: [
            ProcessingGraphParameterValue(
              controlPortId: 100,
              value: 0.25,
              displayText: '440',
            ),
          ],
        ),
      );

      expect(port.parameterValue, 0.25);
      expect(port.parameterDisplayText, '440');
      verifyNever(node.touchControlInputParameter(any));
      verifyNever(node.scheduleDebouncedStateUpdate());
    });

    test('plugin parameter gestures push one undo command', () async {
      final node = MockNodeModel();
      final port = NodePortModel(
        nodeId: 1,
        id: 100,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: 100,
            factoryDefaultValue: 0,
          ),
        ),
      );
      port.parameterValue = 0.25;

      when(node.controlInputPorts).thenReturn(AnthemObservableList.of([port]));
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitMessage(
        PluginParameterGestureEvent(
          nodeId: 1,
          controlPortId: 100,
          isStarting: true,
        ),
      );
      connector.emitMessage(
        PluginParameterChangedEvent(nodeId: 1, controlPortId: 100, value: 0.75),
      );
      connector.emitMessage(
        PluginParameterGestureEvent(
          nodeId: 1,
          controlPortId: 100,
          isStarting: false,
        ),
      );

      final capturedCommand =
          verify(project.push(captureAny)).captured.single
              as SetParameterValueCommand;
      expect(capturedCommand.nodeId, equals(1));
      expect(capturedCommand.controlPortId, equals(100));
      expect(capturedCommand.oldValue, equals(0.25));
      expect(capturedCommand.newValue, equals(0.75));
    });

    test(
      'restarting the engine discards unfinished plugin parameter gestures',
      () async {
        final node = MockNodeModel();
        final port = NodePortModel(
          nodeId: 1,
          id: 100,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: 100,
              factoryDefaultValue: 0,
            ),
          ),
        );
        port.parameterValue = 0.25;
        when(node.controlInputPorts)
            .thenReturn(AnthemObservableList.of([port]));
        nodes[1] = node;

        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );
        connector.emitMessage(
          PluginParameterGestureEvent(
            nodeId: 1,
            controlPortId: 100,
            isStarting: true,
          ),
        );
        connector.emitMessage(
          PluginParameterChangedEvent(
            nodeId: 1,
            controlPortId: 100,
            value: 0.75,
          ),
        );

        connector.dispose();
        connector.emitExit();
        await _startEngineThroughInit(
          engine,
          () => connector,
          audioConfig: startupAudioConfig,
        );

        connector.emitMessage(
          PluginParameterGestureEvent(
            nodeId: 1,
            controlPortId: 100,
            isStarting: false,
          ),
        );
        verifyNever(project.push(any));

        connector.emitMessage(
          PluginParameterGestureEvent(
            nodeId: 1,
            controlPortId: 100,
            isStarting: true,
          ),
        );
        connector.emitMessage(
          PluginParameterChangedEvent(
            nodeId: 1,
            controlPortId: 100,
            value: 0.5,
          ),
        );
        connector.emitMessage(
          PluginParameterGestureEvent(
            nodeId: 1,
            controlPortId: 100,
            isStarting: false,
          ),
        );

        final command =
            verify(project.push(captureAny)).captured.single
                as SetParameterValueCommand;
        expect(command.oldValue, 0.75);
        expect(command.newValue, 0.5);
      },
    );

    test('plugin parameter gesture start touches parameter', () async {
      final port = NodePortModel(
        nodeId: 1,
        id: 100,
        config: NodePortConfigModel(
          dataType: NodePortDataType.control,
          parameterConfig: ParameterConfigModel(
            id: 100,
            factoryDefaultValue: 0,
          ),
        ),
      );
      final node = NodeModel(
        id: 1,
        controlInputPorts: AnthemObservableList.of([port]),
      );
      nodes[1] = node;

      await _startEngineThroughInit(
        engine,
        () => connector,
        audioConfig: startupAudioConfig,
      );

      connector.emitMessage(
        PluginParameterGestureEvent(
          nodeId: 1,
          controlPortId: 100,
          isStarting: true,
        ),
      );
      connector.emitMessage(
        PluginParameterGestureEvent(
          nodeId: 1,
          controlPortId: 100,
          isStarting: false,
        ),
      );

      expect(node.lastChangedControlPortId, equals(100));
      verifyNever(project.push(any));
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

      connector.emitMessage(PluginLoadedEvent(nodeId: 1));

      await pluginLoadedCompleter.future;

      expect(pluginLoadedCompleter.isCompleted, isTrue);
    });

    test(
      'audio and render notifications survive restart and close on disposal',
      () async {
        final invalidations = <String?>[];
        final renderEvents = <IpcEvent>[];
        final audioClosed = Completer<void>();
        final renderClosed = Completer<void>();
        final audioSubscription = engine.audioSessionInvalidatedStream.listen(
          invalidations.add,
          onDone: audioClosed.complete,
        );
        final renderSubscription = engine.renderEventStream.listen(
          renderEvents.add,
          onDone: renderClosed.complete,
        );
        addTearDown(audioSubscription.cancel);
        addTearDown(renderSubscription.cancel);

        for (var attempt = 0; attempt < 2; attempt++) {
          await _startEngineThroughInit(
            engine,
            () => connector,
            audioConfig: startupAudioConfig,
          );
          connector.emitMessage(
            RenderProgressEvent(renderId: attempt, progress: 0.5),
          );
          connector.emitMessage(
            AudioSessionInvalidatedEvent(reason: 'device restart $attempt'),
          );
          await _flushMicrotasks();

          expect(engine.isAudioReady, isFalse);
          expect(engine.audioConfig, isNull);
          expect(audioClosed.isCompleted, isFalse);
          expect(renderClosed.isCompleted, isFalse);

          connector.emitMessage(
            AudioReadyEvent(audioConfig: startupAudioConfig),
          );
          expect(engine.isAudioReady, isTrue);
          connector.dispose();
          connector.emitExit();
          expect(engine.isAudioReady, isFalse);
          expect(engine.audioConfig, isNull);
        }

        await _flushMicrotasks();
        expect(invalidations, ['device restart 0', 'device restart 1']);
        expect(
          renderEvents.whereType<RenderProgressEvent>().map(
            (event) => event.renderId,
          ),
          [0, 1],
        );
        expect(audioClosed.isCompleted, isFalse);
        expect(renderClosed.isCompleted, isFalse);

        await engine.dispose();
        await Future.wait([audioClosed.future, renderClosed.future]);
      },
    );

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
