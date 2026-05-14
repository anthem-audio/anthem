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
import 'dart:convert';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';

part 'api/model_sync_api.dart';
part 'api/processing_graph_api.dart';
part 'api/sequencer_api.dart';
part 'api/visualization_api.dart';

enum EngineState { stopped, starting, running }

var _engineIdGenerator = 0;

typedef EngineConnectorFactory =
    EngineConnectorBase Function(
      int id, {
      required bool kDebugMode,
      void Function(Response)? onReply,
      void Function()? onExit,
      bool noHeartbeat,
      String? enginePathOverride,
    });

EngineConnectorBase _defaultEngineConnectorFactory(
  int id, {
  required bool kDebugMode,
  void Function(Response)? onReply,
  void Function()? onExit,
  bool noHeartbeat = false,
  String? enginePathOverride,
}) => EngineConnector(
  id,
  kDebugMode: kDebugMode,
  onReply: onReply,
  onExit: onExit,
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

  /// Ignore the request while the engine is starting or stopped.
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

class _QueuedStartupRequest {
  final Request request;
  final Completer<Response>? responseCompleter;
  final Duration timeout;

  _QueuedStartupRequest(
    this.request, {
    this.responseCompleter,
    required this.timeout,
  });
}

class _PendingReply {
  final void Function(Response response) onReply;
  final void Function(Object error) onError;
  final Timer timeoutTimer;

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
  late EngineConnectorBase _engineConnector;

  /// The project that this engine is attached to
  ProjectModel project;

  late ModelSyncApi modelSyncApi;
  late ProcessingGraphApi processingGraphApi;
  late SequencerApi sequencerApi;
  late VisualizationApi visualizationApi;

  final Map<int, _PendingReply> _replyFunctions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  final StreamController<EngineState> _engineStateStreamController =
      StreamController.broadcast();
  late final Stream<EngineState> engineStateStream;
  Completer<void> _readyForMessagesCompleter = Completer<void>();

  EngineState _engineState = EngineState.stopped;

  /// The engine's current lifecycle state.
  EngineState get engineState => _engineState;

  /// Returns whether the engine has completed startup and is ready for normal
  /// request traffic.
  bool get isRunning => _engineState == EngineState.running;
  bool _socketReady = false;
  bool _canFlushStartupQueue = false;
  bool _autoFlushStartupQueue = false;
  bool _isFlushingStartupQueue = false;
  final ListQueue<_QueuedStartupRequest> _startupQueue = ListQueue();

  bool _isAudioReady = false;
  EngineAudioConfig? _audioConfig;

  /// Completer that completes when the audio thread is ready.
  Completer<void> _audioReadyCompleter = Completer<void>();

  /// Completes when the engine's audio thread is ready for audio-dependent
  /// work.
  Future<void> get audioReadyFuture => _audioReadyCompleter.future;

  /// Indicates that the audio thread is active.
  ///
  /// This will be false when the engine is first started, and the engine will
  /// set this via an event once it has initialized the audio thread.
  set isAudioReady(bool value) {
    final wasAudioReady = _isAudioReady;

    _isAudioReady = value;
    if (value && !_audioReadyCompleter.isCompleted) {
      _audioReadyCompleter.complete();
    }

    if (value && !wasAudioReady) {
      for (final callback in _audioReadyCallbacks) {
        callback();
      }
    }
  }

  /// Returns whether the engine's audio thread has finished starting.
  bool get isAudioReady => _isAudioReady;

  /// The engine's current audio device configuration.
  ///
  /// Returns `null` whenever the current config is not valid, including while
  /// the engine is stopped, while startup is still in progress, or after the
  /// audio device has been torn down.
  EngineAudioConfig? get audioConfig =>
      _engineState == EngineState.running ? _audioConfig : null;

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
  final List<void Function()> _audioReadyCallbacks = [];

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

  /// Adds a callback to be called when the engine's audio thread is ready.
  void onAudioReady(
    void Function() callback, {
    required bool runNowIfAudioReady,
  }) {
    if (_isAudioReady && runNowIfAudioReady) {
      callback();
    }
    _audioReadyCallbacks.add(callback);
  }

  final String? enginePathOverride;
  final EngineConnectorFactory _engineConnectorFactory;

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
      pendingReply.timeoutTimer.cancel();
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

  void _setEngineState(EngineState state) {
    _engineState = state;

    if (state == EngineState.running &&
        !_readyForMessagesCompleter.isCompleted) {
      _readyForMessagesCompleter.complete();
    }

    if (state == EngineState.stopped) {
      _socketReady = false;
      _isAudioReady = false;
      _audioConfig = null;
      _clearStartupQueue(
        StateError('Engine stopped before startup completed.'),
      );
      _failPendingReplies(
        StateError('Engine stopped while waiting for reply.'),
      );

      if (_readyForMessagesCompleter.isCompleted) {
        _readyForMessagesCompleter = Completer<void>();
      }

      if (_audioReadyCompleter.isCompleted) {
        _audioReadyCompleter = Completer<void>();
      }
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
           engineConnectorFactory ?? _defaultEngineConnectorFactory {
    engineStateStream = _engineStateStreamController.stream;

    modelSyncApi = ModelSyncApi(this);
    processingGraphApi = ProcessingGraphApi(this);
    sequencerApi = SequencerApi(this);
    visualizationApi = VisualizationApi(this);
  }

  void _scheduleNodeStateUpdate(Id nodeId) {
    project.processingGraph.nodes[nodeId]?.scheduleDebouncedStateUpdate();
  }

  void _onReply(Response response) {
    switch (response) {
      case VisualizationUpdateEvent e:
        project.visualizationProvider.processVisualizationUpdate(e);
        return;
      case AudioReadyEvent e:
        _audioConfig = e.audioConfig;
        isAudioReady = true;
        return;
      case PluginChangedEvent e:
        _scheduleNodeStateUpdate(e.nodeId);
        return;
      case PluginParameterChangedEvent e:
        _scheduleNodeStateUpdate(e.nodeId);
        return;
      case PluginLoadedEvent e:
        final node = project.processingGraph.nodes[e.nodeId];
        if (node == null) {
          return;
        }

        final completer = node.pluginLoadedCompleter;

        // This shouldn't happen, but we can't risk throwing here so safety first
        if (completer.isCompleted) return;

        completer.complete();
        return;
      default:
        break;
    }

    final pendingReply = _replyFunctions.remove(response.id);
    if (pendingReply != null) {
      pendingReply.onReply(response);
      pendingReply.timeoutTimer.cancel();
    }
  }

  void _onExit() {
    _setEngineState(EngineState.stopped);
  }

  Future<void> _exit() async {
    final request = Exit(id: _getRequestId());
    await _request(request);

    _engineConnector.dispose();

    _setEngineState(EngineState.stopped);
  }

  Future<void> dispose() async {
    await stop();

    _engineStateStreamController.close();
  }

  /// Stops the engine process, if it is running.
  Future<void> stop() async {
    if (_engineState == EngineState.running) {
      await _exit();
      return;
    }

    if (_engineState == EngineState.starting) {
      _engineConnector.dispose();
      _setEngineState(EngineState.stopped);
    }
  }

  /// Starts the engine process, and attaches to it.
  Future<void> start({bool initializeAudio = true}) async {
    if (_engineState != EngineState.stopped) {
      return;
    }

    _audioConfig = null;
    _isAudioReady = false;
    if (_audioReadyCompleter.isCompleted) {
      _audioReadyCompleter = Completer<void>();
    }

    _setEngineState(EngineState.starting);

    _engineConnector = _engineConnectorFactory(
      id,
      kDebugMode: kDebugMode,
      onReply: _onReply,
      onExit: _onExit,
      enginePathOverride: enginePathOverride,
    );

    final modelInitFuture = project.initializeEngine();
    _consumeFutureError(modelInitFuture);

    final success = await _engineConnector.onInit;

    if (_engineState != EngineState.starting) {
      return;
    }

    if (!success) {
      _setEngineState(EngineState.stopped);
      return;
    }

    _socketReady = true;

    try {
      final response =
          await _request(
                EngineReadyCheckRequest(id: _getRequestId()),
                startupBehavior: StartupSendBehavior.bypassStartupQueue,
              )
              as EngineReadyCheckResponse;
      if (!response.success) {
        throw StateError(
          'Engine startup handshake failed: ${response.error ?? 'Unknown error.'}',
        );
      }

      _canFlushStartupQueue = true;
      if (_startupQueue.isEmpty ||
          _startupQueue.first.request is! ModelInitRequest) {
        throw StateError(
          'Startup queue must begin with ModelInitRequest before startup messages flush.',
        );
      }
      _flushStartupQueue(maxRequests: 1);

      final didInitializeProject = await modelInitFuture;
      if (!didInitializeProject.success) {
        throw StateError(
          'Engine model init failed: ${didInitializeProject.error ?? 'Unknown error.'}',
        );
      }

      if (initializeAudio) {
        final audioStartReply =
            await _request(
                  StartAudioRequest(id: _getRequestId()),
                  startupBehavior: StartupSendBehavior.bypassStartupQueue,
                )
                as StartAudioResponse;
        if (!audioStartReply.success) {
          throw StateError(
            'Engine audio startup failed: ${audioStartReply.error ?? 'Unknown error.'}',
          );
        }
        if (audioStartReply.audioConfig == null) {
          throw StateError(
            'Engine audio startup failed: audio config was not provided.',
          );
        }

        _audioConfig = audioStartReply.audioConfig;
      }

      _autoFlushStartupQueue = true;
      _flushStartupQueue();
    } catch (e, st) {
      if (_engineState != EngineState.starting) {
        return;
      }

      debugPrint('Engine[$id]: startup handshake failed: $e');
      debugPrint('$st');
      _engineConnector.dispose();
      _setEngineState(EngineState.stopped);
      return;
    }

    if (_engineState != EngineState.starting) {
      return;
    }

    _setEngineState(EngineState.running);

    // We don't do this on web, and on web the engine won't listen for it.
    //
    // On desktop, we use the heartbeat mechanism to make sure that, if
    // something goes very wrong, the engine will eventually time out and exit
    // itself in the worst case.
    //
    // This isn't necessary on web, but on web our timer is also throttled when
    // the browser tab is not active, so it trips a heartbeat timeout under
    // regular use. Since it doesn't work (without modification) and we don't
    // need it anyway, we disable it on web.
    if (!_engineConnector.noHeartbeat && !kIsWeb) {
      _engineConnector.startHeartbeatTimer();
    }

    for (final callback in _startupCallbacks) {
      callback();
    }
  }

  void _sendRequest(Request request) {
    final encoder = JsonUtf8Encoder();
    _engineConnector.send(encoder.convert(request.toJson()) as Uint8List);
  }

  Future<Response> _dispatchRequestWithReply(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration timeout = const Duration(seconds: 5),
  }) {
    final completer = responseCompleter ?? Completer<Response>();
    final timer = Timer(timeout, () {
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

    _sendRequest(request);

    return completer.future;
  }

  void _dispatchRequestNoReply(Request request) {
    _sendRequest(request);
  }

  void _queueStartupRequest(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration timeout = const Duration(seconds: 5),
  }) {
    _startupQueue.add(
      _QueuedStartupRequest(
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
    Duration timeout = const Duration(seconds: 5),
  }) {
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

    return _dispatchRequestWithReply(request, timeout: timeout);
  }

  /// Sends a request to the engine, but does not wait for a response.
  void _requestNoReply(
    Request request, {
    StartupSendBehavior startupBehavior = StartupSendBehavior.requireRunning,
  }) {
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

    _dispatchRequestNoReply(request);
  }
}
