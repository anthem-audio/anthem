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

part of 'messages.dart';

/// Reserves a file in a category and returns private write access.
class BeginFileWriteRequest extends Request {
  late String category;
  String? baseName;
  String? extension;

  BeginFileWriteRequest.uninitialized();

  BeginFileWriteRequest({
    required int id,
    required this.category,
    this.baseName,
    this.extension,
  }) {
    super.id = id;
  }
}

/// Grants write access until commit, abort, or engine-session cleanup.
class BeginFileWriteResponse extends Response {
  late String token;
  late String absolutePath;

  BeginFileWriteResponse.uninitialized();

  BeginFileWriteResponse({
    required int id,
    required this.token,
    required this.absolutePath,
  }) {
    super.id = id;
  }
}

/// Publishes a write after the engine has flushed and closed its file.
class CommitFileWriteRequest extends Request {
  late String token;

  CommitFileWriteRequest.uninitialized();

  CommitFileWriteRequest({required int id, required this.token}) {
    super.id = id;
  }
}

/// Returns the committed file's path relative to the project root.
class CommitFileWriteResponse extends Response {
  late String relativePath;

  CommitFileWriteResponse.uninitialized();

  CommitFileWriteResponse({required int id, required this.relativePath}) {
    super.id = id;
  }
}

/// Discards an unfinished write after the engine has closed its file.
class AbortFileWriteRequest extends Request {
  late String token;

  AbortFileWriteRequest.uninitialized();

  AbortFileWriteRequest({required int id, required this.token}) {
    super.id = id;
  }
}

/// Acquires read access that prevents deletion of a committed file.
class AcquireFileReadRequest extends Request {
  late String relativePath;

  AcquireFileReadRequest.uninitialized();

  AcquireFileReadRequest({required int id, required this.relativePath}) {
    super.id = id;
  }
}

/// Grants read access until release or engine-session cleanup.
class AcquireFileReadResponse extends Response {
  late String token;
  late String absolutePath;

  AcquireFileReadResponse.uninitialized();

  AcquireFileReadResponse({
    required int id,
    required this.token,
    required this.absolutePath,
  }) {
    super.id = id;
  }
}

/// Releases read access after the engine has closed its file.
class ReleaseFileReadRequest extends Request {
  late String token;

  ReleaseFileReadRequest.uninitialized();

  ReleaseFileReadRequest({required int id, required this.token}) {
    super.id = id;
  }
}

/// Deletes a file that has no readers or retained project references.
class DeleteStoredFileRequest extends Request {
  late String relativePath;

  DeleteStoredFileRequest.uninitialized();

  DeleteStoredFileRequest({required int id, required this.relativePath}) {
    super.id = id;
  }
}

/// Retains a file independently of active read access.
class RetainStoredFileRequest extends Request {
  late String relativePath;

  RetainStoredFileRequest.uninitialized();

  RetainStoredFileRequest({required int id, required this.relativePath}) {
    super.id = id;
  }
}

/// Grants retention until release or storage-session cleanup.
class RetainStoredFileResponse extends Response {
  late String token;

  RetainStoredFileResponse.uninitialized();

  RetainStoredFileResponse({required int id, required this.token}) {
    super.id = id;
  }
}

/// Releases one retained reference to a file.
class ReleaseStoredFileRetentionRequest extends Request {
  late String token;

  ReleaseStoredFileRetentionRequest.uninitialized();

  ReleaseStoredFileRetentionRequest({required int id, required this.token}) {
    super.id = id;
  }
}

/// Acknowledges a successful abort, read or retention release, or deletion.
class FileStorageSuccessResponse extends Response {
  FileStorageSuccessResponse.uninitialized();

  FileStorageSuccessResponse({required int id}) {
    super.id = id;
  }
}
