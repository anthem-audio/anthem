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
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/project_engine_controller.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestEngineConnector extends EngineConnectorBase {
  final Completer<bool> _onInitCompleter = Completer<bool>();
  final void Function()? _onExit;
  final List<Request> sentRequests = [];

  var isDisposed = false;
  var startHeartbeatTimerCallCount = 0;

  _TestEngineConnector({
    required super.kDebugMode,
    super.noHeartbeat = false,
    super.onReply,
    this._onExit,
  }) {
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

class _RecordingProcessingGraphApi implements ProcessingGraphApi {
  final calls = <String>[];
  var didInitialize = true;

  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async {
    calls.add('initialize');
    return ProcessingGraphNodeInitialization(
      didInitialize: didInitialize,
      results: [],
    );
  }

  @override
  Future<void> publish() async {
    calls.add('publish');
  }

  @override
  Future<String> getPluginState(Id nodeId) async => '';

  @override
  void openPluginWindow(Id nodeId) {}

  @override
  void sendLiveEvent(Id liveEventProviderNodeId, Object event) {}

  @override
  void setPluginParameterValue(Id nodeId, int controlPortId, double value) {}

  @override
  void setPluginState(Id nodeId, String state) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectModel project;
  late ProjectController projectController;
  late ProjectEngineController projectEngineController;
  late _TestEngineConnector connector;
  late _RecordingProcessingGraphApi processingGraphApi;

  setUp(() {
    project = ProjectModel.create();

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

    project.engine = Engine(
      123,
      project,
      engineConnectorFactory: createConnector,
    );
    processingGraphApi = _RecordingProcessingGraphApi();
    project.engine.processingGraphApi = processingGraphApi;

    projectController = ProjectController(project, ProjectViewModel());
    projectEngineController = ProjectEngineController(
      project,
      projectController,
    );
  });

  tearDown(() {
    projectEngineController.dispose();
    project.dispose();
  });

  test('start can start the engine process without audio', () async {
    final startFuture = projectEngineController.start(startAudio: false);

    connector.completeInit();
    await _flushMicrotasks();

    final readyCheckRequest = _latestRequest<EngineReadyCheckRequest>(
      connector,
    )!;
    connector.emitResponse(
      EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
    );
    await _flushMicrotasks();

    final modelInitRequest = _latestRequest<ModelInitRequest>(connector)!;
    connector.emitResponse(
      ModelInitResponse(id: modelInitRequest.id, success: true),
    );

    await startFuture;

    expect(project.engine.engineState, EngineState.running);
    expect(project.engine.isAudioReady, isFalse);
    expect(_latestRequest<StartAudioRequest>(connector), isNull);
    await project.waitForFirstSync().timeout(const Duration(seconds: 1));
  });

  test('start starts audio and publishes the processing graph', () async {
    final startFuture = projectEngineController.start();

    connector.completeInit();
    await _flushMicrotasks();

    final readyCheckRequest = _latestRequest<EngineReadyCheckRequest>(
      connector,
    )!;
    connector.emitResponse(
      EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
    );
    await _flushMicrotasks();

    final modelInitRequest = _latestRequest<ModelInitRequest>(connector)!;
    connector.emitResponse(
      ModelInitResponse(id: modelInitRequest.id, success: true),
    );

    final startAudioRequest = await _waitForRequest<StartAudioRequest>(
      connector,
    );
    connector.emitResponse(
      StartAudioResponse(
        id: startAudioRequest.id,
        success: true,
        audioConfig: EngineAudioConfig(
          sampleRate: 48000,
          blockSize: 256,
          inputChannelCount: 2,
          outputChannelCount: 2,
        ),
      ),
    );

    await startFuture;

    expect(project.engine.engineState, EngineState.running);
    expect(project.engine.isAudioReady, isTrue);
    expect(processingGraphApi.calls, orderedEquals(['initialize', 'publish']));
    await project.waitForFirstSync().timeout(const Duration(seconds: 1));
  });

  test(
    'audio session invalidation restarts audio and republishes graph',
    () async {
      final startFuture = projectEngineController.start();

      connector.completeInit();
      await _flushMicrotasks();

      final readyCheckRequest = _latestRequest<EngineReadyCheckRequest>(
        connector,
      )!;
      connector.emitResponse(
        EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
      );
      await _flushMicrotasks();

      final modelInitRequest = _latestRequest<ModelInitRequest>(connector)!;
      connector.emitResponse(
        ModelInitResponse(id: modelInitRequest.id, success: true),
      );

      final startAudioRequest = await _waitForRequest<StartAudioRequest>(
        connector,
      );
      connector.emitResponse(
        StartAudioResponse(
          id: startAudioRequest.id,
          success: true,
          audioConfig: EngineAudioConfig(
            sampleRate: 48000,
            blockSize: 256,
            inputChannelCount: 2,
            outputChannelCount: 2,
          ),
        ),
      );

      await startFuture;

      final previousStartAudioRequestCount = connector.sentRequests
          .whereType<StartAudioRequest>()
          .length;

      connector.emitResponse(
        AudioSessionInvalidatedEvent(
          id: -1,
          reason: 'The audio device restarted.',
        ),
      );

      final stopAudioRequest = await _waitForRequest<StopAudioRequest>(
        connector,
      );
      connector.emitResponse(
        StopAudioResponse(id: stopAudioRequest.id, success: true),
      );

      final restartedStartAudioRequest =
          await _waitForNewRequest<StartAudioRequest>(
            connector,
            previousStartAudioRequestCount,
          );
      connector.emitResponse(
        StartAudioResponse(
          id: restartedStartAudioRequest.id,
          success: true,
          audioConfig: EngineAudioConfig(
            sampleRate: 44100,
            blockSize: 512,
            inputChannelCount: 0,
            outputChannelCount: 2,
          ),
        ),
      );

      await _flushMicrotasks();

      expect(project.engine.isAudioReady, isTrue);
      expect(project.engine.audioConfig?.sampleRate, equals(44100));
      expect(project.engine.audioConfig?.blockSize, equals(512));
      expect(
        processingGraphApi.calls,
        orderedEquals(['initialize', 'publish', 'initialize', 'publish']),
      );
    },
  );

  test('start completes when startup audio fails', () async {
    final startFuture = projectEngineController.start();

    connector.completeInit();
    await _flushMicrotasks();

    final readyCheckRequest = _latestRequest<EngineReadyCheckRequest>(
      connector,
    )!;
    connector.emitResponse(
      EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
    );
    await _flushMicrotasks();

    final modelInitRequest = _latestRequest<ModelInitRequest>(connector)!;
    connector.emitResponse(
      ModelInitResponse(id: modelInitRequest.id, success: true),
    );

    final startAudioRequest = await _waitForRequest<StartAudioRequest>(
      connector,
    );
    connector.emitResponse(
      StartAudioResponse(
        id: startAudioRequest.id,
        success: false,
        error: 'No audio device available.',
      ),
    );

    await startFuture;

    expect(project.engine.engineState, EngineState.running);
    expect(project.engine.isAudioReady, isFalse);
    expect(project.engine.audioConfig, isNull);
    expect(processingGraphApi.calls, isEmpty);
    await project.waitForFirstSync().timeout(const Duration(seconds: 1));
  });

  test('explicit startAudio throws when audio fails', () async {
    final startFuture = projectEngineController.start(startAudio: false);

    connector.completeInit();
    await _flushMicrotasks();

    final readyCheckRequest = _latestRequest<EngineReadyCheckRequest>(
      connector,
    )!;
    connector.emitResponse(
      EngineReadyCheckResponse(id: readyCheckRequest.id, success: true),
    );
    await _flushMicrotasks();

    final modelInitRequest = _latestRequest<ModelInitRequest>(connector)!;
    connector.emitResponse(
      ModelInitResponse(id: modelInitRequest.id, success: true),
    );

    await startFuture;

    final startAudioFuture = projectEngineController.startAudio();
    final startAudioRequest = await _waitForRequest<StartAudioRequest>(
      connector,
    );
    connector.emitResponse(
      StartAudioResponse(
        id: startAudioRequest.id,
        success: false,
        error: 'No audio device available.',
      ),
    );

    await expectLater(startAudioFuture, throwsA(isA<StateError>()));
    expect(project.engine.engineState, EngineState.running);
    expect(project.engine.isAudioReady, isFalse);
    expect(project.engine.audioConfig, isNull);
  });
}

T? _latestRequest<T extends Request>(_TestEngineConnector connector) {
  for (final request in connector.sentRequests.reversed) {
    if (request is T) {
      return request;
    }
  }

  return null;
}

Future<T> _waitForRequest<T extends Request>(
  _TestEngineConnector connector,
) async {
  for (var i = 0; i < 20; i++) {
    final request = _latestRequest<T>(connector);
    if (request != null) {
      return request;
    }

    await _flushMicrotasks();
  }

  fail('Timed out waiting for ${T.toString()}.');
}

Future<T> _waitForNewRequest<T extends Request>(
  _TestEngineConnector connector,
  int previousCount,
) async {
  for (var i = 0; i < 20; i++) {
    final requests = connector.sentRequests.whereType<T>().toList();
    if (requests.length > previousCount) {
      return requests.last;
    }

    await _flushMicrotasks();
  }

  fail('Timed out waiting for new ${T.toString()}.');
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
