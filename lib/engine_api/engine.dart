/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'dart:collection';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/project_engine_event_handler.dart';
import 'package:anthem/logic/project_engine_request_handler.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

part 'api/model_sync_api.dart';
part 'api/processing_graph_api.dart';
part 'api/render_api.dart';
part 'api/sequencer_api.dart';
part 'api/visualization_api.dart';
part 'engine_audio_session.dart';

final _log = Logger('engine');

enum EngineState {
  /// No engine session is active, and cleanup has finished.
  stopped,

  /// The engine is connecting and initializing its project state.
  starting,

  /// Startup has completed and ordinary requests can be sent.
  running,

  /// The session has ended; shutdown and process cleanup are still in progress.
  stopping,
}

var _engineIdGenerator = 0;

typedef EngineConnectorFactory = EngineConnectorBase Function(
  int id, {
  required bool kDebugMode,
  void Function(IpcMessage)? onMessage,
  void Function()? onExit,
  void Function()? onConnectionClosed,
  bool noHeartbeat,
  String? enginePathOverride,
});

EngineConnectorBase _defaultEngineConnectorFactory(
  int id, {
  required bool kDebugMode,
  void Function(IpcMessage)? onMessage,
  void Function()? onExit,
  void Function()? onConnectionClosed,
  bool noHeartbeat = false,
  String? enginePathOverride,
}) => EngineConnector(
  id,
  kDebugMode: kDebugMode,
  onMessage: onMessage,
  onExit: onExit,
  onConnectionClosed: onConnectionClosed,
  noHeartbeat: noHeartbeat,
  enginePathOverride: enginePathOverride,
);

/// Returns a unique engine ID for associating a project with an engine
/// instance.
int getEngineID() => _engineIdGenerator++;

/// Controls how a request behaves while the engine is in [EngineState.starting].
enum StartupSendBehavior {
  /// Queue the request and replay it in-order after the startup handshake
  /// completes.
  ///
  /// This is for durable state-sync style messages where replaying them later
  /// is still correct, as long as relative ordering is preserved.
  queueDuringStartup,

  /// Reject the request unless the engine is fully running.
  ///
  /// This is for requests where delaying them would change their meaning or
  /// mislead the caller, such as "read current engine state" operations.
  requireRunning,

  /// Ignore the request whenever the engine is not running.
  ///
  /// This is for ephemeral actions that should not be replayed later, such as
  /// live input events.
  dropDuringStartup,

  /// Send the request immediately once the socket is available, bypassing the
  /// startup queue.
  ///
  /// This is reserved for internal control-plane messages that are used to
  /// bring the engine to a state where the queued requests can safely flush.
  bypassStartupQueue,
}

class _QueuedEngineRequest {
  final Request request;
  final Completer<Response>? responseCompleter;
  final Duration? timeout;

  _QueuedEngineRequest(
    this.request, {
    this.responseCompleter,
    required this.timeout,
  });
}

class _PendingReply {
  final void Function(Response response) onReply;
  final void Function(Object error) onError;
  final Timer? timeoutTimer;

  _PendingReply({
    required this.onReply,
    required this.onError,
    required this.timeoutTimer,
  });
}

/// Engine class, used for communicating with the Anthem engine process.
///
/// This class manages the low-level IPC connection between the UI and engine
/// processes and presents a higher-level async API to the rest of the UI.
class Engine {
  int id;
  EngineConnectorBase? _connector;
  EngineConnectorBase get _engineConnector => _connector!;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;
  int _sessionGeneration = 0;
  Completer<void> _sessionEnded = Completer<void>()..complete();

  int? get processId => _connector?.processId;
  int? get processExitCode => _connector?.processExitCode;

  /// The project that this engine is attached to
  ProjectModel project;

  late final EngineAudioSession _audioSession;

  late ModelSyncApi modelSyncApi;
  late ProcessingGraphApi processingGraphApi;
  late RenderApi renderApi;
  late SequencerApi sequencerApi;
  late VisualizationApi visualizationApi;

  final Map<int, _PendingReply> _replyFunctions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  final StreamController<EngineState> _engineStateStreamController =
      StreamController.broadcast();
  late final Stream<EngineState> engineStateStream;
  Stream<String?> get audioSessionInvalidatedStream =>
      _audioSession.invalidatedStream;
  Stream<IpcEvent> get renderEventStream => renderApi.events;
  Completer<void> _readyForMessagesCompleter = Completer<void>();

  EngineState _engineState = EngineState.stopped;

  /// The engine's current lifecycle state.
  EngineState get engineState => _engineState;

  /// Completes when this session enters [EngineState.stopping].
  ///
  /// Retain the returned future for work belonging to the current session.
  /// Starting the engine again creates a new future; the previous one stays
  /// completed. Before the first start, this future is already complete.
  Future<void> get sessionEnded => _sessionEnded.future;

  /// Returns whether the engine has completed startup and is ready for request
  /// traffic.
  bool get isRunning => _engineState == EngineState.running;
  bool _socketReady = false;
  bool _canFlushStartupQueue = false;
  bool _autoFlushStartupQueue = false;
  bool _isFlushingStartupQueue = false;
  final ListQueue<_QueuedEngineRequest> _startupQueue = ListQueue();

  int _renderRequestHoldCount = 0;
  bool _isFlushingRenderHeldRequests = false;

  // Timeouts are stored with requests held during render and only start when
  // the request is actually dispatched to the engine.
  final ListQueue<_QueuedEngineRequest> _renderHeldRequestQueue = ListQueue();

  /// Returns whether request traffic is currently held during render.
  bool get areRequestsHeldForRender => _renderRequestHoldCount > 0;

  /// Returns whether the engine's audio thread has finished starting.
  bool get isAudioReady => _audioSession.isReady;

  /// The engine's current audio device configuration.
  ///
  /// Returns `null` whenever the current config is not valid, including while
  /// the engine is stopped, while startup is still in progress, or after the
  /// audio device has been torn down.
  AudioProcessingConfigDto? get audioConfig => _audioSession.config;

  /// Returns a [Future] that completes when the engine is ready to receive
  /// messages.
  ///
  /// If the engine is already running, this will complete immediately. If not,
  /// it will wait for the engine to start and then complete.
  ///
  /// Note that if the engine is stopped and not starting, this will wait for
  /// the engine to start, which may never happen.
  Future<void> get readyForMessages => _engineState == EngineState.running
      ? Future.value()
      : _readyForMessagesCompleter.future;

  final List<void Function()> _startupCallbacks = [];

  /// Adds a callback to be called when the engine is started.
  void onStart(
    void Function() callback, {
    required bool runNowIfEngineRunning,
  }) {
    if (_engineState == EngineState.running && runNowIfEngineRunning) {
      callback();
    }
    _startupCallbacks.add(callback);
  }

  final String? enginePathOverride;
  final EngineConnectorFactory _engineConnectorFactory;
  final ProjectEngineRequestHandler _requestHandler;
  final ProjectEngineEventHandler _eventHandler;

  /// Attaches no-op completion handlers so a future cannot surface as an
  /// unhandled async error.
  ///
  /// This does not change the behavior of awaiting the original future later.
  /// It only ensures that if control flow moves on before the future settles,
  /// a later error will still be observed.
  void _consumeFutureError<T>(Future<T> future) {
    unawaited(future.then<void>((_) {}, onError: (_, _) {}));
  }

  void _failPendingReplies(Object error) {
    for (final pendingReply in _replyFunctions.values) {
      pendingReply.timeoutTimer?.cancel();
      pendingReply.onError(error);
    }
    _replyFunctions.clear();
  }

  void _clearStartupQueue(Object error) {
    while (_startupQueue.isNotEmpty) {
      final queuedRequest = _startupQueue.removeFirst();
      queuedRequest.responseCompleter?.completeError(error);
    }
    _isFlushingStartupQueue = false;
    _autoFlushStartupQueue = false;
    _canFlushStartupQueue = false;
  }

  void _clearRenderHeldRequests(Object error) {
    while (_renderHeldRequestQueue.isNotEmpty) {
      final queuedRequest = _renderHeldRequestQueue.removeFirst();
      queuedRequest.responseCompleter?.completeError(error);
    }

    _renderRequestHoldCount = 0;
    _isFlushingRenderHeldRequests = false;
  }

  void holdRequestsForRender() {
    if (_engineState != EngineState.running) {
      throw StateError('Engine must be running to hold requests for render.');
    }

    _renderRequestHoldCount++;
  }

  void releaseRequestsHeldForRender() {
    if (_renderRequestHoldCount == 0) {
      return;
    }

    _renderRequestHoldCount--;
    if (_renderRequestHoldCount == 0) {
      _flushRenderHeldRequests();
    }
  }

  void _queueRenderHeldRequest(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration? timeout = const Duration(seconds: 5),
  }) {
    _renderHeldRequestQueue.add(
      _QueuedEngineRequest(
        request,
        responseCompleter: responseCompleter,
        timeout: timeout,
      ),
    );
  }

  void _flushRenderHeldRequests() {
    if (_isFlushingRenderHeldRequests ||
        areRequestsHeldForRender ||
        _engineState != EngineState.running) {
      return;
    }

    _isFlushingRenderHeldRequests = true;

    try {
      while (_renderHeldRequestQueue.isNotEmpty &&
          _engineState == EngineState.running &&
          !areRequestsHeldForRender) {
        final queuedRequest = _renderHeldRequestQueue.removeFirst();

        if (queuedRequest.responseCompleter != null) {
          _dispatchRequestWithReply(
            queuedRequest.request,
            responseCompleter: queuedRequest.responseCompleter,
            timeout: queuedRequest.timeout,
          );
        } else {
          _dispatchRequestNoReply(queuedRequest.request);
        }
      }
    } finally {
      _isFlushingRenderHeldRequests = false;
    }
  }

  void _setEngineState(EngineState state) {
    if (state == _engineState) return;
    assert(switch ((_engineState, state)) {
      (EngineState.stopped, EngineState.starting) ||
      (EngineState.starting, EngineState.running) ||
      (EngineState.starting, EngineState.stopping) ||
      (EngineState.running, EngineState.stopping) ||
      (EngineState.stopping, EngineState.stopped) => true,
      _ => false,
    });
    _engineState = state;
    _audioSession._handleEngineStateChanged(state);

    if (state == EngineState.running &&
        !_readyForMessagesCompleter.isCompleted) {
      _readyForMessagesCompleter.complete();
    }

    if (state == EngineState.stopping) {
      _sessionEnded.complete();
      _clearStartupQueue(
        StateError('Engine stopped before startup completed.'),
      );
      _clearRenderHeldRequests(
        StateError('Engine stopped while requests were held for render.'),
      );
      _failPendingReplies(
        StateError('Engine stopped while waiting for reply.'),
      );
      _eventHandler.handleEngineStopped();

      if (_readyForMessagesCompleter.isCompleted) {
        _readyForMessagesCompleter = Completer<void>();
      }
    }
    if (state == EngineState.stopped) {
      _socketReady = false;
    }

    if (!_engineStateStreamController.isClosed) {
      _engineStateStreamController.add(state);
    }
  }

  Engine(
    this.id,
    this.project, {
    this.enginePathOverride,
    EngineConnectorFactory? engineConnectorFactory,
  }) : _engineConnectorFactory =
           engineConnectorFactory ?? _defaultEngineConnectorFactory,
       _requestHandler = ProjectEngineRequestHandler(project),
       _eventHandler = ProjectEngineEventHandler(project) {
    _audioSession = EngineAudioSession(this);
    engineStateStream = _engineStateStreamController.stream;

    modelSyncApi = ModelSyncApi(this);
    processingGraphApi = ProcessingGraphApi(this);
    renderApi = RenderApi(this);
    sequencerApi = SequencerApi(this);
    visualizationApi = VisualizationApi(this);
  }

  void _onMessage(IpcMessage message) {
    if (message is Request) {
      if (_engineState == EngineState.stopping) {
        _engineConnector.sendMessage(
          RequestErrorResponse(
            id: message.id,
            code: RequestErrorCode.failed,
            message: 'Engine session is stopping.',
          ),
        );
        return;
      }
      unawaited(_handleRequestFromEngine(message));
    } else if (message is Response) {
      _onResponse(message);
    } else if (message is IpcEvent &&
        (_engineState == EngineState.starting || isRunning)) {
      _onEvent(message);
    }
  }

  Future<void> _handleRequestFromEngine(Request request) async {
    // Keep replies on this connection if the engine restarts while handling
    // the request.
    final connector = _engineConnector;
    final session = _sessionEnded;
    Response response;
    try {
      response = await _requestHandler.handleRequest(
        request,
        sessionEnded: session.future,
      );
      if (response.id != request.id) {
        throw StateError(
          'Response ID ${response.id} does not match request ID ${request.id}.',
        );
      }
    } catch (error, stackTrace) {
      _log.warning(
        'Failed to handle engine request ${request.runtimeType}.',
        error,
        stackTrace,
      );
      response = RequestErrorResponse(
        id: request.id,
        code: error is UnsupportedError
            ? RequestErrorCode.unsupported
            : RequestErrorCode.failed,
        message: error.toString(),
      );
    }

    if (!session.isCompleted) connector.sendMessage(response);
  }

  void _onResponse(Response response) {
    if (response is HeartbeatReply) {
      _engineConnector.acknowledgeHeartbeat();
      return;
    }

    final pendingReply = _replyFunctions.remove(response.id);
    if (pendingReply != null) {
      _audioSession._handleResponse(response);
      pendingReply.onReply(response);
      pendingReply.timeoutTimer?.cancel();
    }
  }

  void _onEvent(IpcEvent event) {
    if (_audioSession._handleEvent(event)) return;
    if (renderApi._handleEvent(event)) return;
    _eventHandler.handleEvent(event);
  }

  void _onConnectionClosed(int sessionGeneration) {
    if (sessionGeneration != _sessionGeneration ||
        _engineState == EngineState.stopped) {
      return;
    }
    _socketReady = false;
    _failPendingReplies(
      StateError('Engine connection closed before replying.'),
    );
    unawaited(
      stop().catchError((Object error, StackTrace stackTrace) {
        _log.warning('Engine $id cleanup failed.', error, stackTrace);
      }),
    );
  }

  /// Stops the engine and releases its resources.
  ///
  /// Cleanup failures can be retried by calling dispose again. The engine cannot
  /// restart once disposal has begun.
  Future<void> dispose() => _disposeFuture ??= _dispose().catchError((
    Object error,
    StackTrace stack,
  ) {
    _disposeFuture = null;
    Error.throwWithStackTrace(error, stack);
  });

  Future<void> _dispose() async {
    try {
      await stop();
    } finally {
      _engineStateStreamController.close();
      _audioSession._dispose();
      renderApi._dispose();
    }
  }

  /// Ends the current session and waits for process cleanup to finish.
  Future<void> stop() {
    final existing = _stopFuture;
    if (existing != null) return existing;
    if (_engineState == EngineState.stopped) return Future.value();

    final sendExit = isRunning && _socketReady;
    _setEngineState(EngineState.stopping);
    // Install the stop future before shutdown can report connection closure.
    return _stopFuture = Future<void>.microtask(() => _stop(sendExit: sendExit))
        .whenComplete(() => _stopFuture = null);
  }

  Future<void> _stop({required bool sendExit}) async {
    final connector = _connector;
    if (connector != null) {
      if (sendExit && _socketReady) {
        try {
          // Exit is the only request dispatched after entering stopping.
          await _dispatchRequestWithReply(Exit(id: connector.getRequestId()));
        } catch (error, stackTrace) {
          _log.warning(
            'Engine $id did not acknowledge exit.',
            error,
            stackTrace,
          );
        }
      }
      try {
        await connector.shutdown();
      } catch (_) {
        // Shutdown can report that a forced termination was necessary even
        // after confirming the process has exited.
        if (connector.processExitCode != null) {
          await _requestHandler.closeSession();
          _setEngineState(EngineState.stopped);
        }
        rethrow;
      }
    }
    await _requestHandler.closeSession();
    _setEngineState(EngineState.stopped);
  }

  /// Starts the audio thread without restarting the engine process.
  Future<AudioProcessingConfigDto> startAudio() => _audioSession.start();

  Future<AudioProcessingConfigDto> startAudioForRender() =>
      _audioSession.start(bypassRenderRequestHold: true);

  /// Stops the audio thread without stopping the engine process.
  Future<void> stopAudio() => _audioSession.stop();

  Future<void> stopAudioForRender() =>
      _audioSession.stop(bypassRenderRequestHold: true);

  bool _isStartingSession(int generation) =>
      generation == _sessionGeneration && _engineState == EngineState.starting;

  /// Starts the engine process, and attaches to it.
  Future<void> start({bool initializeAudio = true}) async {
    if (_disposeFuture != null || _engineStateStreamController.isClosed) {
      throw StateError('Engine $id is disposed.');
    }
    final stopping = _stopFuture;
    if (stopping != null) await stopping;
    if (_disposeFuture != null || _engineStateStreamController.isClosed) {
      throw StateError('Engine $id is disposed.');
    }
    if (_engineState != EngineState.stopped) return;

    final generation = ++_sessionGeneration;
    _sessionEnded = Completer<void>();
    _setEngineState(EngineState.starting);

    try {
      _connector = _engineConnectorFactory(
        id,
        kDebugMode: kDebugMode,
        onMessage: _onMessage,
        onExit: () => _onConnectionClosed(generation),
        onConnectionClosed: () => _onConnectionClosed(generation),
        enginePathOverride: enginePathOverride,
      );
      _engineConnector.onVisualizationRecord =
          project.visualizationProvider.processVisualizationRecord;

      final modelInitFuture = project.initializeEngine();
      _consumeFutureError(modelInitFuture);
      final success = await _engineConnector.onInit;
      if (!_isStartingSession(generation)) return;
      if (!success) {
        await stop();
        return;
      }
      _socketReady = true;

      final response = await _request(
        EngineReadyCheckRequest(id: _getRequestId()),
        startupBehavior: StartupSendBehavior.bypassStartupQueue,
      ) as EngineReadyCheckResponse;
      if (!_isStartingSession(generation)) return;
      if (!response.success) {
        throw StateError(
          'Engine startup handshake failed: ${response.error ?? 'Unknown error.'}',
        );
      }
      _engineConnector.finalizeVisualizationSharedMemorySetup();

      _canFlushStartupQueue = true;
      if (_startupQueue.isEmpty ||
          _startupQueue.first.request is! ModelInitRequest) {
        throw StateError(
          'Startup queue must begin with ModelInitRequest before startup messages flush.',
        );
      }
      _flushStartupQueue(maxRequests: 1);

      final didInitializeProject = await modelInitFuture;
      if (!_isStartingSession(generation)) return;
      if (!didInitializeProject.success) {
        throw StateError(
          'Engine model init failed: ${didInitializeProject.error ?? 'Unknown error.'}',
        );
      }
      if (initializeAudio) {
        await _audioSession._start(
          startupBehavior: StartupSendBehavior.bypassStartupQueue,
        );
      }
      if (!_isStartingSession(generation)) return;
      _autoFlushStartupQueue = true;
      _flushStartupQueue();
    } catch (error, stackTrace) {
      if (!_isStartingSession(generation)) return;
      _log.severe('Engine $id startup handshake failed.', error, stackTrace);
      await stop();
      return;
    } finally {
      // A cancelled startup finishes only after its session has been cleaned up.
      final stopping = _stopFuture;
      if (generation == _sessionGeneration && stopping != null) {
        await stopping;
      }
    }

    if (!_isStartingSession(generation)) return;
    _setEngineState(EngineState.running);

    // Browser timers are throttled in background tabs. Desktop processes use
    // heartbeats to detect a failed UI; the in-process web engine does not.
    if (!_engineConnector.noHeartbeat && !kIsWeb) {
      _engineConnector.startHeartbeatTimer();
    }
    for (final callback in _startupCallbacks) {
      callback();
    }
  }

  Future<Response> _dispatchRequestWithReply(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration? timeout = const Duration(seconds: 5),
  }) {
    final completer = responseCompleter ?? Completer<Response>();
    final timer = timeout == null
        ? null
        : Timer(timeout, () {
            if (_replyFunctions.containsKey(request.id)) {
              completer.completeError(
                TimeoutException(
                  'Request ${request.id} of type ${request.runtimeType} timed out after ${timeout.inSeconds} seconds.',
                  timeout,
                ),
              );
              _replyFunctions.remove(request.id);
            }
          });

    _replyFunctions[request.id] = _PendingReply(
      onReply: (response) {
        completer.complete(response);
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      timeoutTimer: timer,
    );

    _engineConnector.sendMessage(request);

    return completer.future;
  }

  void _dispatchRequestNoReply(Request request) {
    _engineConnector.sendMessage(request);
  }

  void _queueStartupRequest(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration? timeout = const Duration(seconds: 5),
  }) {
    _startupQueue.add(
      _QueuedEngineRequest(
        request,
        responseCompleter: responseCompleter,
        timeout: timeout,
      ),
    );

    if (_autoFlushStartupQueue &&
        _canFlushStartupQueue &&
        !_isFlushingStartupQueue) {
      _flushStartupQueue();
    }
  }

  void _flushStartupQueue({int? maxRequests}) {
    if (_isFlushingStartupQueue || !_canFlushStartupQueue || !_socketReady) {
      return;
    }

    _isFlushingStartupQueue = true;

    try {
      var requestsFlushed = 0;

      while (_startupQueue.isNotEmpty && _engineState == EngineState.starting) {
        final queuedRequest = _startupQueue.removeFirst();

        if (queuedRequest.responseCompleter != null) {
          _dispatchRequestWithReply(
            queuedRequest.request,
            responseCompleter: queuedRequest.responseCompleter,
            timeout: queuedRequest.timeout,
          );
        } else {
          _dispatchRequestNoReply(queuedRequest.request);
        }

        requestsFlushed++;
        if (maxRequests != null && requestsFlushed >= maxRequests) {
          break;
        }
      }
    } finally {
      _isFlushingStartupQueue = false;
    }
  }

  Future<Response> _request(
    Request request, {
    StartupSendBehavior startupBehavior = StartupSendBehavior.requireRunning,
    bool bypassRenderRequestHold = false,
    Duration? timeout = const Duration(seconds: 5),
  }) {
    if (_engineState == EngineState.stopping &&
        startupBehavior != StartupSendBehavior.dropDuringStartup) {
      throw StateError('Engine is stopping.');
    }

    if (startupBehavior == StartupSendBehavior.queueDuringStartup &&
        engineState == EngineState.starting) {
      final completer = Completer<Response>();
      _queueStartupRequest(
        request,
        responseCompleter: completer,
        timeout: timeout,
      );
      return completer.future;
    }

    if (startupBehavior == StartupSendBehavior.dropDuringStartup &&
        engineState != EngineState.running) {
      return Future.error(
        StateError(
          'Request ${request.runtimeType} was dropped because the engine is not running.',
        ),
      );
    }

    if (startupBehavior == StartupSendBehavior.bypassStartupQueue) {
      if (!_socketReady && engineState != EngineState.running) {
        throw AssertionError(
          'Engine socket must be ready to send bypass requests.',
        );
      }
      return _dispatchRequestWithReply(request, timeout: timeout);
    }

    if (engineState != EngineState.running) {
      throw AssertionError('Engine must be running to send commands.');
    }

    if (!bypassRenderRequestHold && areRequestsHeldForRender) {
      final completer = Completer<Response>();
      _queueRenderHeldRequest(
        request,
        responseCompleter: completer,
        timeout: timeout,
      );
      return completer.future;
    }

    return _dispatchRequestWithReply(request, timeout: timeout);
  }

  /// Sends a request to the engine, but does not wait for a response.
  void _requestNoReply(
    Request request, {
    StartupSendBehavior startupBehavior = StartupSendBehavior.requireRunning,
    bool bypassRenderRequestHold = false,
  }) {
    if (_engineState == EngineState.stopping &&
        startupBehavior != StartupSendBehavior.dropDuringStartup) {
      throw StateError('Engine is stopping.');
    }

    if (startupBehavior == StartupSendBehavior.queueDuringStartup &&
        engineState == EngineState.starting) {
      _queueStartupRequest(request);
      return;
    }

    if (startupBehavior == StartupSendBehavior.dropDuringStartup &&
        engineState != EngineState.running) {
      return;
    }

    if (startupBehavior == StartupSendBehavior.bypassStartupQueue) {
      if (!_socketReady && engineState != EngineState.running) {
        throw AssertionError(
          'Engine socket must be ready to send bypass requests.',
        );
      }
      _dispatchRequestNoReply(request);
      return;
    }

    if (engineState != EngineState.running) {
      throw AssertionError('Engine must be running to send commands.');
    }

    if (!bypassRenderRequestHold && areRequestsHeldForRender) {
      _queueRenderHeldRequest(request);
      return;
    }

    _dispatchRequestNoReply(request);
  }
}
