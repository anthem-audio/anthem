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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/project.dart';

/// Dispatches requests from a project's engine to UI services.
///
/// `Engine` creates and owns this dispatcher for its project. No service
/// operations are implemented yet, so every request receives a
/// [RequestErrorCode.unsupported] response. Add request cases here as project
/// services become available.
class ProjectEngineRequestHandler {
  final ProjectModel project;

  ProjectEngineRequestHandler(this.project);

  /// Returns a response for an engine request.
  ///
  /// Responses retain the request ID. [sessionEnded] completes when the
  /// engine session that sent [request] begins stopping. Asynchronous operations
  /// can use it to stop work or release resources.
  FutureOr<Response> handleRequest(
    Request request, {
    required Future<void> sessionEnded,
  }) {
    return switch (request) {
      _ => RequestErrorResponse(
        id: request.id,
        code: RequestErrorCode.unsupported,
        message: 'Unsupported engine request: ${request.runtimeType}.',
      ),
    };
  }
}
