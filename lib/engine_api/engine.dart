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
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';

part 'api/model_sync_api.dart';
part 'api/processing_graph_api.dart';
part 'api/render_api.dart';
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

enum _RenderSendBehavior { queueDuringRender, bypassRenderQueue }

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

class _PluginParameterGestureSession {
  final double oldValue;

  const _PluginParameterGestureSession({required this.oldValue});
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
  late RenderApi renderApi;
  late SequencerApi sequencerApi;
  late VisualizationApi visualizationApi;

  final Map<int, _PendingReply> _replyFunctions = {};
  final Map<(Id, int), _PluginParameterGestureSession>
  _pluginParameterGestureSessions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  final StreamController<EngineState> _engineStateStreamController =
      StreamController.broadcast();
  final StreamController<String?> _audioSessionInvalidatedStreamController =
      StreamController.broadcast();
  final StreamController<Response> _renderEventStreamController =
      StreamController.broadcast();
  late final Stream<EngineState> engineStateStream;
  late final Stream<String?> audioSessionInvalidatedStream;
  late final Stream<Response> renderEventStream;
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
  final ListQueue<_QueuedEngineRequest> _startupQueue = ListQueue();

  bool _isRenderingAudio = false;
  bool _isFlushingRenderQueue = false;
  int? _activeRenderId;

  // Timeouts are stored with queued render requests and only start when the
  // request is actually dispatched to the engine.
  final ListQueue<_QueuedEngineRequest> _renderQueue = ListQueue();

  /// Returns whether an offline render is active or starting.
  bool get isRenderingAudio => _isRenderingAudio;

  bool _isAudioReady = false;
  AudioProcessingConfigDto? _audioConfig;

  /// Returns whether the engine's audio thread has finished starting.
  bool get isAudioReady => _isAudioReady;

  /// The engine's current audio device configuration.
  ///
  /// Returns `null` whenever the current config is not valid, including while
  /// the engine is stopped, while startup is still in progress, or after the
  /// audio device has been torn down.
  AudioProcessingConfigDto? get audioConfig =>
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

  void _clearRenderQueue(Object error) {
    while (_renderQueue.isNotEmpty) {
      final queuedRequest = _renderQueue.removeFirst();
      queuedRequest.responseCompleter?.completeError(error);
    }

    _isRenderingAudio = false;
    _activeRenderId = null;
    _isFlushingRenderQueue = false;
  }

  void _beginRenderingAudio(int renderId) {
    if (_isRenderingAudio) {
      return;
    }

    _isRenderingAudio = true;
    _activeRenderId = renderId;
  }

  void _finishRenderingAudio({int? renderId}) {
    if (!_isRenderingAudio) {
      return;
    }

    final activeRenderId = _activeRenderId;
    if (renderId != null &&
        activeRenderId != null &&
        renderId != activeRenderId) {
      return;
    }

    _isRenderingAudio = false;
    _activeRenderId = null;
    _flushRenderQueue();
  }

  void _queueRenderRequest(
    Request request, {
    Completer<Response>? responseCompleter,
    Duration? timeout = const Duration(seconds: 5),
  }) {
    _renderQueue.add(
      _QueuedEngineRequest(
        request,
        responseCompleter: responseCompleter,
        timeout: timeout,
      ),
    );
  }

  void _flushRenderQueue() {
    if (_isFlushingRenderQueue ||
        _isRenderingAudio ||
        _engineState != EngineState.running) {
      return;
    }

    _isFlushingRenderQueue = true;

    try {
      while (_renderQueue.isNotEmpty &&
          _engineState == EngineState.running &&
          !_isRenderingAudio) {
        final queuedRequest = _renderQueue.removeFirst();

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
      _isFlushingRenderQueue = false;
    }
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
      _clearRenderQueue(
        StateError('Engine stopped while render requests were queued.'),
      );
      _failPendingReplies(
        StateError('Engine stopped while waiting for reply.'),
      );
      _pluginParameterGestureSessions.clear();

      if (_readyForMessagesCompleter.isCompleted) {
        _readyForMessagesCompleter = Completer<void>();
      }
    }

    if (!_engineStateStreamController.isClosed) {
      _engineStateStreamController.add(state);
    }
  }

  void _setAudioReady(AudioProcessingConfigDto audioConfig) {
    _audioConfig = audioConfig;
    _isAudioReady = true;
  }

  void _markAudioStopped() {
    _audioConfig = null;
    _isAudioReady = false;
  }

  void _markAudioSessionInvalidated(String? reason) {
    _audioConfig = null;
    _isAudioReady = false;

    if (!_audioSessionInvalidatedStreamController.isClosed) {
      _audioSessionInvalidatedStreamController.add(reason);
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
    audioSessionInvalidatedStream =
        _audioSessionInvalidatedStreamController.stream;
    renderEventStream = _renderEventStreamController.stream;

    modelSyncApi = ModelSyncApi(this);
    processingGraphApi = ProcessingGraphApi(this);
    renderApi = RenderApi(this);
    sequencerApi = SequencerApi(this);
    visualizationApi = VisualizationApi(this);
  }

  void _scheduleNodeStateUpdate(Id nodeId) {
    project.processingGraph.nodes[nodeId]?.scheduleDebouncedStateUpdate();
  }

  NodePortModel? _findPluginParameterPort(NodeModel node, int controlPortId) {
    for (final port in node.controlInputPorts) {
      if (port.id == controlPortId && port.config.parameterConfig != null) {
        return port;
      }
    }

    return null;
  }

  void _applyPluginParameterValue(
    NodeModel node,
    int controlPortId,
    double rawValue,
    String? displayText, {
    required bool markTouched,
  }) {
    final value = rawValue.clamp(0.0, 1.0).toDouble();
    final port = _findPluginParameterPort(node, controlPortId);

    if (port == null) {
      return;
    }

    if (markTouched) {
      node.touchControlInputParameter(port);
    }

    if (port.parameterValue != value) {
      port.parameterValue = value;
    }

    if (port.parameterDisplayText != displayText) {
      port.parameterDisplayText = displayText;
    }
  }

  void _handlePluginParameterChanged(PluginParameterChangedEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    _applyPluginParameterValue(
      node,
      event.controlPortId,
      event.value,
      event.displayText,
      markTouched: true,
    );

    _scheduleNodeStateUpdate(event.nodeId);
  }

  void _handlePluginParameterGesture(PluginParameterGestureEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    final port = _findPluginParameterPort(node, event.controlPortId);
    if (port == null) {
      return;
    }

    final key = (event.nodeId, event.controlPortId);

    if (event.isStarting) {
      node.touchControlInputParameter(port);
      _pluginParameterGestureSessions[key] = _PluginParameterGestureSession(
        oldValue: SetParameterValueCommand.effectiveParameterValue(port),
      );
      return;
    }

    final session = _pluginParameterGestureSessions.remove(key);
    if (session == null) {
      return;
    }

    final newValue = SetParameterValueCommand.effectiveParameterValue(port);
    if (session.oldValue == newValue) {
      return;
    }

    project.push(
      SetParameterValueCommand(
        nodeId: event.nodeId,
        controlPortId: event.controlPortId,
        oldValue: session.oldValue,
        newValue: newValue,
      ),
    );
  }

  void _handlePluginParameterSnapshot(PluginParameterSnapshotEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    for (final parameterValue in event.parameterValues) {
      _applyPluginParameterValue(
        node,
        parameterValue.controlPortId,
        parameterValue.value,
        parameterValue.displayText,
        markTouched: false,
      );
    }
  }

  void _onReply(Response response) {
    switch (response) {
      case VisualizationUpdateEvent e:
        project.visualizationProvider.processVisualizationUpdate(e);
        return;
      case AudioReadyEvent e:
        _setAudioReady(e.audioConfig);
        return;
      case AudioSessionInvalidatedEvent e:
        _markAudioSessionInvalidated(e.reason);
        return;
      case RenderStartedEvent e:
        _beginRenderingAudio(e.renderId);
        if (!_renderEventStreamController.isClosed) {
          _renderEventStreamController.add(e);
        }
        return;
      case RenderProgressEvent e:
        if (!_renderEventStreamController.isClosed) {
          _renderEventStreamController.add(e);
        }
        return;
      case RenderCompletedEvent e:
        if (!_renderEventStreamController.isClosed) {
          _renderEventStreamController.add(e);
        }
        _finishRenderingAudio(renderId: e.renderId);
        return;
      case RenderFailedEvent e:
        if (!_renderEventStreamController.isClosed) {
          _renderEventStreamController.add(e);
        }
        _finishRenderingAudio(renderId: e.renderId);
        return;
      case PluginChangedEvent e:
        _scheduleNodeStateUpdate(e.nodeId);
        return;
      case PluginParameterChangedEvent e:
        _handlePluginParameterChanged(e);
        return;
      case PluginParameterGestureEvent e:
        _handlePluginParameterGesture(e);
        return;
      case PluginParameterSnapshotEvent e:
        _handlePluginParameterSnapshot(e);
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
      pendingReply.timeoutTimer?.cancel();
    }
  }

  void _onExit() {
    _setEngineState(EngineState.stopped);
  }

  Future<void> _exit() async {
    final request = Exit(id: _getRequestId());
    await _request(
      request,
      renderBehavior: _RenderSendBehavior.bypassRenderQueue,
    );

    _engineConnector.dispose();

    _setEngineState(EngineState.stopped);
  }

  Future<void> dispose() async {
    await stop();

    _engineStateStreamController.close();
    _audioSessionInvalidatedStreamController.close();
    _renderEventStreamController.close();
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

  Future<AudioProcessingConfigDto> _startAudio({
    required StartupSendBehavior startupBehavior,
  }) async {
    final audioStartReply =
        await _request(
              StartAudioRequest(id: _getRequestId()),
              startupBehavior: startupBehavior,
              // Audio device initialization can block behind OS permission
              // prompts, such as the first-run microphone access prompt on
              // macOS.
              timeout: null,
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

    final audioConfig = audioStartReply.audioConfig!;
    _setAudioReady(audioConfig);
    return audioConfig;
  }

  /// Starts the audio thread without restarting the engine process.
  Future<AudioProcessingConfigDto> startAudio() async {
    if (_engineState != EngineState.running) {
      throw StateError('Engine must be running to start audio.');
    }

    if (_audioConfig != null) {
      return _audioConfig!;
    }

    return _startAudio(startupBehavior: StartupSendBehavior.requireRunning);
  }

  /// Stops the audio thread without stopping the engine process.
  Future<void> stopAudio() async {
    if (_engineState != EngineState.running) {
      return;
    }

    final stopAudioReply =
        await _request(StopAudioRequest(id: _getRequestId()))
            as StopAudioResponse;

    if (!stopAudioReply.success) {
      throw StateError(
        'Engine audio shutdown failed: ${stopAudioReply.error ?? 'Unknown error.'}',
      );
    }

    _markAudioStopped();
  }

  /// Starts the engine process, and attaches to it.
  Future<void> start({bool initializeAudio = true}) async {
    if (_engineState != EngineState.stopped) {
      return;
    }

    _audioConfig = null;
    _isAudioReady = false;

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
        await _startAudio(
          startupBehavior: StartupSendBehavior.bypassStartupQueue,
        );
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

    _sendRequest(request);

    return completer.future;
  }

  void _dispatchRequestNoReply(Request request) {
    _sendRequest(request);
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
    _RenderSendBehavior renderBehavior = _RenderSendBehavior.queueDuringRender,
    Duration? timeout = const Duration(seconds: 5),
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

    if (renderBehavior == _RenderSendBehavior.queueDuringRender &&
        _isRenderingAudio) {
      final completer = Completer<Response>();
      _queueRenderRequest(
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
    _RenderSendBehavior renderBehavior = _RenderSendBehavior.queueDuringRender,
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

    if (renderBehavior == _RenderSendBehavior.queueDuringRender &&
        _isRenderingAudio) {
      _queueRenderRequest(request);
      return;
    }

    _dispatchRequestNoReply(request);
  }
}
