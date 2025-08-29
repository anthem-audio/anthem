/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter/foundation.dart';

export 'package:anthem/engine_api/messages/messages.dart'
    show InvalidationRange, FieldAccess, FieldUpdateKind;

part 'api/model_sync_api.dart';
part 'api/processing_graph_api.dart';
part 'api/sequencer_api.dart';
part 'api/visualization_api.dart';

enum EngineState { stopped, starting, running }

var _engineIdGenerator = 0;

int getEngineID() => _engineIdGenerator++;

/// Engine class, used for communicating with the Anthem engine process.
///
/// This class manages the low-level IPC connection between the UI and engine
/// processes and presents a higher-level async API to the rest of the UI.
class Engine {
  int id;
  late EngineConnector _engineConnector;

  /// The project that this engine is attached to
  ProjectModel project;

  late ModelSyncApi modelSyncApi;
  late ProcessingGraphApi processingGraphApi;
  late SequencerApi sequencerApi;
  late VisualizationApi visualizationApi;

  Map<int, ({void Function(Response response) onReply, Timer timeoutTimer})>
  replyFunctions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  final StreamController<EngineState> _engineStateStreamController =
      StreamController.broadcast();
  late final Stream<EngineState> engineStateStream;

  EngineState _engineState = EngineState.stopped;
  EngineState get engineState => _engineState;
  bool get isRunning => _engineState == EngineState.running;

  bool _isAudioReady = false;

  /// Completer that completes when the audio thread is ready.
  final Completer<void> audioReadyCompleter = Completer<void>();

  /// Indicates that the audio thread is active.
  ///
  /// This will be false when the engine is first started, and the engine will
  /// set this via an event once it has initialized the audio thread.
  set isAudioReady(bool value) {
    _isAudioReady = value;
    if (value && !audioReadyCompleter.isCompleted) {
      audioReadyCompleter.complete();
    }
  }

  bool get isAudioReady => _isAudioReady;

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
      : Future(() async {
          await _engineStateStreamController.stream.firstWhere(
            (state) => state == EngineState.running,
          );
        });

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

  void _setEngineState(EngineState state) {
    _engineState = state;
    _engineStateStreamController.add(state);
  }

  Engine(this.id, this.project, {this.enginePathOverride}) {
    engineStateStream = _engineStateStreamController.stream;

    modelSyncApi = ModelSyncApi(this);
    processingGraphApi = ProcessingGraphApi(this);
    sequencerApi = SequencerApi(this);
    visualizationApi = VisualizationApi(this);
  }

  void _scheduleNodeStateUpdate(String nodeId) {
    project.processingGraph.nodes[nodeId]?.scheduleDebouncedStateUpdate();
  }

  void _onReply(Response response) {
    switch (response) {
      case VisualizationUpdateEvent e:
        project.visualizationProvider.processVisualizationUpdate(e);
        return;
      case AudioReadyEvent _:
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

    if (response is VisualizationUpdateEvent) {
      project.visualizationProvider.processVisualizationUpdate(response);
      return;
    } else if (response is AudioReadyEvent) {
      isAudioReady = true;
    }

    if (replyFunctions[response.id] != null) {
      replyFunctions[response.id]!.onReply(response);
      replyFunctions[response.id]!.timeoutTimer.cancel();
      replyFunctions.remove(response.id);
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
    await _exit();
    _engineStateStreamController.close();
  }

  /// Stops the engine process, if it is running.
  Future<void> stop() async {
    if (_engineState != EngineState.stopped) {
      await _exit();
    }
  }

  /// Starts the engine process, and attaches to it.
  Future<void> start() async {
    if (kIsWeb) {
      return;
    }

    if (_engineState != EngineState.stopped) {
      return;
    }

    _setEngineState(EngineState.starting);

    _engineConnector = EngineConnector(
      id,
      kDebugMode: kDebugMode,
      onReply: _onReply,
      onExit: _onExit,
      enginePathOverride: enginePathOverride,
    );

    final success = await _engineConnector.onInit;

    _setEngineState(success ? EngineState.running : EngineState.stopped);

    if (_engineState == EngineState.running) {
      for (final callback in _startupCallbacks) {
        callback();
      }
    }
  }

  /// Sends a request to the engine, and asynchronously returns the response.
  Future<Response> _request(Request request) {
    if (engineState != EngineState.running) {
      throw AssertionError('Engine must be running to send commands.');
    }

    final completer = Completer<Response>();

    void onReply(Response response) {
      completer.complete(response);
    }

    final timeout = Duration(seconds: 5);
    final timer = Timer(timeout, () {
      if (replyFunctions[request.id] != null) {
        completer.completeError(
          TimeoutException(
            'Request ${request.id} of type ${request.runtimeType} timed out after ${timeout.inSeconds} seconds.',
            timeout,
          ),
        );
        replyFunctions.remove(request.id);
      }
    });

    replyFunctions[request.id] = (onReply: onReply, timeoutTimer: timer);

    final encoder = JsonUtf8Encoder();

    _engineConnector.send(encoder.convert(request.toJson()) as Uint8List);

    return completer.future;
  }

  /// Sends a request to the engine, but does not wait for a response.
  void _requestNoReply(Request request) {
    if (engineState != EngineState.running) {
      throw AssertionError('Engine must be running to send commands.');
    }

    final encoder = JsonUtf8Encoder();

    _engineConnector.send(encoder.convert(request.toJson()) as Uint8List);
  }
}
