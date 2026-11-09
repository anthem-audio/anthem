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
import 'package:anthem/logic/storage/project_asset_store.dart';

/// Dispatches requests from a project's engine to UI services.
///
/// `Engine` owns this dispatcher. Each engine session owns a file scope, which
/// is closed after that engine has stopped accessing files.
class ProjectEngineRequestHandler {
  final ProjectModel project;
  Future<AssetScope>? _fileStorageScope;

  ProjectEngineRequestHandler(this.project);

  /// Returns a response for an engine request.
  ///
  /// Responses retain the request ID. [sessionEnded] completes when the
  /// engine session that sent [request] begins stopping. Asynchronous operations
  /// can use it to cancel work. File handles remain valid until [closeFileScope]
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

  Future<AssetScope> _getFileStorageScope() {
    return _fileStorageScope ??= _openFileStorageScope().catchError((
      Object error,
      StackTrace stack,
    ) {
      _fileStorageScope = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<AssetScope> _openFileStorageScope() =>
      ServiceRegistry.forProject(project.id).projectStorage.openScope();

  /// Returns null for requests that do not operate on file storage.
  Future<Response?> _handleFileStorageRequest(Request request) async {
    switch (request) {
      case ResolveFileRetentionRequest():
        final scope = await _getFileStorageScope();
        return ResolveFileRetentionResponse(
          id: request.id,
          relativePath: scope.resolveRetention(request.retentionId),
        );
      case BeginFileWriteRequest():
        final scope = await _getFileStorageScope();
        final access = await scope.beginWrite(
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
        final scope = await _getFileStorageScope();
        final relativePath = await scope.commitWrite(
          request.token,
          fingerprint: request.fingerprint,
        );
        return CommitFileWriteResponse(
          id: request.id,
          relativePath: relativePath,
        );
      case AbortFileWriteRequest():
        final scope = await _getFileStorageScope();
        await scope.abortWrite(request.token);
        return FileStorageSuccessResponse(id: request.id);
      case AcquireFileReadRequest():
        final scope = await _getFileStorageScope();
        final access = scope.acquireRead(request.relativePath);
        try {
          final fingerprint = request.includeFingerprint
              ? await scope.getFingerprint(access.token)
              : null;
          return AcquireFileReadResponse(
            id: request.id,
            token: access.token,
            absolutePath: access.absolutePath,
            fingerprint: fingerprint,
          );
        } catch (_) {
          scope.releaseRead(access.token);
          rethrow;
        }
      case ReleaseFileReadRequest():
        final scope = await _getFileStorageScope();
        scope.releaseRead(request.token);
        return FileStorageSuccessResponse(id: request.id);
      case DeleteStoredFileRequest():
        final scope = await _getFileStorageScope();
        await scope.delete(request.relativePath);
        return FileStorageSuccessResponse(id: request.id);
      case RetainStoredFileRequest():
        final scope = await _getFileStorageScope();
        return RetainStoredFileResponse(
          id: request.id,
          token: scope.retain(request.relativePath),
        );
      case ReleaseStoredFileRetentionRequest():
        final scope = await _getFileStorageScope();
        scope.releaseRetention(request.token);
        return FileStorageSuccessResponse(id: request.id);
      default:
        return null;
    }
  }

  /// Adopts a file retention explicitly handed to the UI in an engine response.
  /// The engine must no longer use or release the supplied token. Its session
  /// scope protects the file until adoption or session cleanup. Adoption creates
  /// a caller-owned retention and releases that temporary session claim.
  /// The caller must dispose the returned retention when finished.
  Future<({String relativePath, AssetRetention retention})>
  adoptReturnedFileRetention(String token) async {
    final scope = await _getFileStorageScope();
    final relativePath = scope.resolveRetention(token);
    final retention = ServiceRegistry.forProject(project.id).projectStorage
        .retainAssets([relativePath]);
    try {
      scope.releaseRetention(token);
      return (relativePath: relativePath, retention: retention);
    } catch (_) {
      retention.dispose();
      rethrow;
    }
  }

  /// Closes the engine's file scope after its process has stopped.
  Future<void> closeFileScope() async {
    final opening = _fileStorageScope;
    if (opening == null) return;
    // Failed initialization was reported to the request that opened the store.
    final scope = await opening.then<AssetScope?>(
      (value) => value,
      onError: (Object _, StackTrace _) => null,
    );
    if (scope != null) await scope.close();
    _fileStorageScope = null;
  }
}
