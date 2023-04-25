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
import 'dart:typed_data';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/generated/messages_generated.dart';
import 'package:anthem/generated/project_generated.dart';

part 'api/project.dart';

/// Engine class, used for communicating with Tracktion Engine.
///
/// This class manages the IPC connection between the UI and engine processes
/// and provides a higher-level async API to the rest of the UI.
class Engine {
  String id;
  late EngineConnector _engineConnector;
  late Project project;

  Map<int, void Function(Response response)> replyFunctions = {};

  int Function() get _getRequestId => _engineConnector.getRequestId;

  Engine(this.id) {
    _engineConnector = EngineConnector(id, _onReply);
    project = Project(this);
  }

  void _onReply(Uint8List reply) {
    final response = Response(reply);

    if (replyFunctions[response.id] != null) {
      replyFunctions[response.id]!(response);
      replyFunctions.remove(response.id);
    }
  }

  void dispose() {
    _engineConnector.dispose();
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
    _engineConnector.send(request.toBytes());
  }
}
