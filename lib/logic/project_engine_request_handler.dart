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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_file_store.dart';

/// Dispatches requests from a project's engine to UI services.
///
/// `Engine` owns this dispatcher. File access is tracked separately for each
/// engine session and released after that engine has stopped accessing files.
class ProjectEngineRequestHandler {
  final ProjectModel project;
  Future<({ProjectFileStore store, String sessionId})>? _fileStorageSession;

  ProjectEngineRequestHandler(this.project);

  /// Returns a response for an engine request.
  ///
  /// Responses retain the request ID. [sessionEnded] completes when the
  /// engine session that sent [request] begins stopping. Asynchronous operations
  /// can use it to cancel work. File handles remain valid until [closeSession]
  /// runs after process cleanup.
  Future<Response> handleRequest(
    Request request, {
    required Future<void> sessionEnded,
  }) async {
    // Each module handles the request or returns null if it does not recognize it.
    final response = await _handleFileStorageRequest(request);
    return response ??
        RequestErrorResponse(
          id: request.id,
          code: RequestErrorCode.unsupported,
          message: 'Unsupported engine request: ${request.runtimeType}.',
        );
  }

  Future<({ProjectFileStore store, String sessionId})>
  _getFileStorageSession() {
    return _fileStorageSession ??= _openFileStorageSession().catchError((
      Object error,
      StackTrace stack,
    ) {
      _fileStorageSession = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<({ProjectFileStore store, String sessionId})>
  _openFileStorageSession() async {
    final store = await ServiceRegistry.forProject(project.id)
        .projectStorage
        .fileStore;
    return (store: store, sessionId: store.openSession());
  }

  /// Returns null for requests that do not operate on file storage.
  Future<Response?> _handleFileStorageRequest(Request request) async {
    switch (request) {
      case BeginFileWriteRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        final access = await store.beginWrite(
          sessionId,
          request.category,
          baseName: request.baseName,
          extension: request.extension,
        );
        return BeginFileWriteResponse(
          id: request.id,
          token: access.token,
          absolutePath: access.absolutePath,
        );
      case CommitFileWriteRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        final relativePath = await store.commitWrite(sessionId, request.token);
        return CommitFileWriteResponse(
          id: request.id,
          relativePath: relativePath,
        );
      case AbortFileWriteRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        await store.abortWrite(sessionId, request.token);
        return FileStorageSuccessResponse(id: request.id);
      case AcquireFileReadRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        final access = store.acquireRead(sessionId, request.relativePath);
        return AcquireFileReadResponse(
          id: request.id,
          token: access.token,
          absolutePath: access.absolutePath,
        );
      case ReleaseFileReadRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        store.releaseRead(sessionId, request.token);
        return FileStorageSuccessResponse(id: request.id);
      case DeleteStoredFileRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        await store.delete(sessionId, request.relativePath);
        return FileStorageSuccessResponse(id: request.id);
      case RetainStoredFileRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        return RetainStoredFileResponse(
          id: request.id,
          token: store.retain(sessionId, request.relativePath),
        );
      case ReleaseStoredFileRetentionRequest():
        final (:store, :sessionId) = await _getFileStorageSession();
        store.releaseRetention(sessionId, request.token);
        return FileStorageSuccessResponse(id: request.id);
      default:
        return null;
    }
  }

  /// Closes the engine's storage session after its process has stopped.
  Future<void> closeSession() async {
    final opening = _fileStorageSession;
    if (opening == null) return;
    // Failed initialization was reported to the request that opened the store.
    final session = await opening
        .then<({ProjectFileStore store, String sessionId})?>(
          (value) => value,
          onError: (Object _, StackTrace _) => null,
        );
    if (session != null) await session.store.closeSession(session.sessionId);
    _fileStorageSession = null;
  }
}
