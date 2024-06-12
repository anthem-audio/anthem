/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/generated/messages_generated.dart';
import 'package:anthem/generated/processors_generated.dart';
import 'package:anthem/generated/project_generated.dart';
import 'package:anthem/generated/processing_graph_generated.dart';
import 'package:anthem/model/project.dart';

part 'api/project_api.dart';
part 'api/processing_graph_api.dart';

enum EngineState {
  stopped,
  starting,
  running,
}

var _engineIdGenerator = 0;

int getEngineID() => _engineIdGenerator++;

/// Engine class, used for communicating with Tracktion Engine.
///
/// This class manages the IPC connection between the UI and engine processes
/// and provides a higher-level async API to the rest of the UI.
class Engine {
  int id;
  late EngineConnector _engineConnector;

  ProjectModel project;

  late ProjectApi projectApi;
  late ProcessingGraphApi processingGraphApi;

  Map<int, void Function(Response response)> replyFunctions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  final StreamController<EngineState> _engineStateStreamController =
      StreamController.broadcast();
  late final Stream<EngineState> engineStateStream;

  EngineState _engineState = EngineState.stopped;

  Engine(this.id, this.project) {
    engineStateStream = _engineStateStreamController.stream;

    projectApi = ProjectApi(this);
    processingGraphApi = ProcessingGraphApi(this);
  }

  void _onReply(Response response) {
    if (replyFunctions[response.id] != null) {
      replyFunctions[response.id]!(response);
      replyFunctions.remove(response.id);
    }
  }

  void _onCrash() {
    _setEngineState(EngineState.stopped);
  }

  Future<void> _exit() async {
    final id = _getRequestId();

    final request = RequestObjectBuilder(
      id: id,
      commandType: CommandTypeId.Exit,
      command: ExitObjectBuilder(),
    );

    final completer = Completer<void>();

    _request(id, request, onResponse: (response) {
      completer.complete();
    });

    await completer.future;

    // This force-kills the engine... Maybe we should give it some time to
    // shut down? Not sure how to tell when the process stops.
    _engineConnector.dispose();

    _setEngineState(EngineState.stopped);
  }

  Future<void> dispose() async {
    await _exit();
    _engineStateStreamController.close();
  }

  Future<void> stop() async {
    if (_engineState != EngineState.stopped) {
      await _exit();
    }
  }

  Future<void> start() async {
    if (_engineState != EngineState.stopped) {
      return;
    }

    _setEngineState(EngineState.starting);

    _engineConnector =
        EngineConnector(id, onReply: _onReply, onCrash: _onCrash);

    final success = await _engineConnector.onInit;

    _setEngineState(success ? EngineState.running : EngineState.stopped);
  }

  /// Sends a request to the engine.
  ///
  /// If a [onResponse] function is provided, the function will be called with the
  /// engine's response.
  void _request(int id, RequestObjectBuilder request,
      {void Function(Response response)? onResponse}) {
    if (onResponse != null) {
      replyFunctions[id] = onResponse;
    }
    _engineConnector.send(request);
  }

  void _setEngineState(EngineState state) {
    _engineState = state;
    _engineStateStreamController.add(state);
  }
}
