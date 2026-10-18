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
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'project_file_category.dart';

import 'file_store_io_stub.dart'
    if (dart.library.io) 'file_store_io.dart'
    as files;

/// Coordinates file access for one project's stored objects.
///
/// File IDs are paths relative to [rootDirectory], such as
/// `plugin states/Preset 01.bin`. They always use forward slashes and remain
/// valid when the project moves.
/// Committed files must not be edited in place; replacing a snapshot creates a
/// new file.
///
/// A store has one owner in the UI. All readers, writers, and users retaining
/// objects must obtain handles here, including engine access granted over IPC.
/// Filesystem changes made outside this API are not coordinated by the store.
class ProjectFileStore {
  static final _openRoots = <String>{};
  static const _uuid = Uuid();

  /// Absolute project root, containing category folders and `.pending` writes.
  final String rootDirectory;

  /// Categories known to this store, including regenerable caches.
  final List<ProjectFileCategory> categories;
  final Map<String, ProjectFileCategory> _categoriesByName;
  final String _rootKey;
  final Map<String, _StoredObject> _objects = {};
  final Set<String> _reservedNames = {};
  final Set<PendingFileWrite> _writes = {};
  int _operationCount = 0;
  Completer<void>? _idle;
  bool _closing = false;
  Future<void>? _closeFuture;

  ProjectFileStore._(this.rootDirectory, this._rootKey, this.categories)
    : _categoriesByName = {for (final c in categories) c.directoryName: c};

  /// Opens a project root, creating its category folders if needed.
  ///
  /// IDs are recovered by scanning [categories]; no ID-to-path manifest is
  /// needed. Other folders and project documents in the root are left alone.
  /// Opening never deletes unreferenced files or abandoned writes. Callers must
  /// establish which files are still needed before requesting deletion.
  static Future<ProjectFileStore> open(
    String rootDirectory, {
    required Iterable<ProjectFileCategory> categories,
  }) async {
    final categoryList = List<ProjectFileCategory>.unmodifiable(categories);
    final directoryNames = <String>{'.pending'};
    for (final category in categoryList) {
      if (!_isValidFileName(category.directoryName) ||
          !directoryNames.add(category.directoryName.toLowerCase())) {
        throw ArgumentError.value(
          category.directoryName,
          'categories',
          'Expected unique, portable folder names; .pending is reserved.',
        );
      }
    }
    final requestedRoot = p.normalize(p.absolute(rootDirectory));
    await files.createDirectory(requestedRoot);
    final root = await files.resolveDirectory(requestedRoot);
    final key = p.style == p.Style.windows ? root.toLowerCase() : root;
    if (!_openRoots.add(key)) {
      throw StateError('The file store is already open: $root');
    }
    final store = ProjectFileStore._(root, key, categoryList);
    try {
      // Reject aliases and links for managed folders. The project root itself
      // may be reached through a link; it has already been resolved above.
      final rootEntries = await files.listEntries(root);
      for (final name in [
        '.pending',
        ...categoryList.map((c) => c.directoryName),
      ]) {
        for (final entry in rootEntries) {
          if (entry.name.toLowerCase() == name.toLowerCase() &&
              (entry.name != name || !entry.isDirectory)) {
            throw FormatException('Invalid category directory: ${entry.name}');
          }
        }
        await files.createDirectory(p.join(root, name));
      }
      for (final category in categoryList) {
        final folder = category.directoryName;
        for (final entry in await files.listEntries(p.join(root, folder))) {
          final id = p.posix.join(folder, entry.name);
          if (!store._reservedNames.add(id.toLowerCase())) {
            throw FormatException('File names differ only by case: $id');
          }
          if (entry.isFile && _isValidFileName(entry.name)) {
            store._objects[id] = _StoredObject();
          }
        }
      }
      return store;
    } catch (_) {
      _openRoots.remove(key);
      rethrow;
    }
  }

  String get _pendingDirectory => p.join(rootDirectory, '.pending');

  String _filePath(String id) => p.joinAll([rootDirectory, ...id.split('/')]);

  /// A snapshot of the committed object IDs currently available for access.
  List<String> get objectIds {
    _requireOpen();
    return List.unmodifiable(
      _objects.keys.where((id) => !_objects[id]!.deleting),
    );
  }

  /// Committed files to include when saving or exporting the project.
  ///
  /// Regenerable caches and unfinished writes are excluded. This is a snapshot;
  /// callers must coordinate ongoing writes before saving a complete project.
  List<String> get projectFileIds => List.unmodifiable(
    objectIds.where((id) => !_categoriesByName[id.split('/').first]!.isCache),
  );

  /// Reserves an object name and creates a private file for the writer.
  ///
  /// With [baseName], names are numbered, for example `Bass 01.wav`. Without it,
  /// a UUID is used. [extension] is optional and may begin with a dot. Names are
  /// reserved before file creation, including against other pending writes.
  Future<PendingFileWrite> beginWrite(
    ProjectFileCategory category, {
    String? baseName,
    String? extension,
  }) {
    _requireOpen();
    final registered = _categoriesByName[category.directoryName];
    if (registered == null || registered.isCache != category.isCache) {
      throw ArgumentError.value(
        category,
        'category',
        'Category is not registered.',
      );
    }
    final suffix = _extensionSuffix(extension);
    final stem = baseName == null ? null : _sanitizeBaseName(baseName);
    var number = 1;
    late String id;
    do {
      final name = stem == null
          ? '${_uuid.v4()}$suffix'
          : '$stem ${(number++).toString().padLeft(2, '0')}$suffix';
      id = p.posix.join(category.directoryName, name);
    } while (!_reservedNames.add(id.toLowerCase()));

    final write = PendingFileWrite._(
      this,
      id,
      p.join(_pendingDirectory, '${_uuid.v4()}.tmp'),
    );
    return _runOperation(() async {
      try {
        await files.createFile(write.path);
        _writes.add(write);
        return write;
      } catch (_) {
        _reservedNames.remove(id.toLowerCase());
        rethrow;
      }
    });
  }

  /// Prevents deletion until the caller closes its file and releases the handle.
  StoredFileRead acquireRead(String objectId) {
    final object = _objectForAccess(objectId);
    object.readers++;
    return StoredFileRead._(
      objectId,
      _filePath(objectId),
      () => object.readers--,
    );
  }

  /// Keeps an object available independently of whether it is being read.
  ///
  /// Project state, undo history, and recovery can each retain the same object.
  /// Releasing a retention handle does not automatically delete the file.
  StoredFileRetention retain(String objectId) {
    final object = _objectForAccess(objectId);
    object.retainers++;
    return StoredFileRetention._(objectId, () => object.retainers--);
  }

  /// Deletes an unreferenced object, rejecting new access during deletion.
  ///
  /// Throws [StateError] if readers or retention handles still exist. The
  /// caller must know the object is no longer needed before requesting deletion.
  Future<void> delete(String objectId) {
    final object = _objectForAccess(objectId);
    if (object.readers != 0 || object.retainers != 0) {
      throw StateError('Stored object is still in use: $objectId');
    }
    object.deleting = true;
    return _runOperation(() async {
      try {
        await files.deleteFile(_filePath(objectId));
        _objects.remove(objectId);
        _reservedNames.remove(objectId.toLowerCase());
      } finally {
        object.deleting = false;
      }
    });
  }

  _StoredObject _objectForAccess(String objectId) {
    _requireOpen();
    if (!_isValidObjectId(objectId)) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Expected a category/filename path.',
      );
    }
    final object = _objects[objectId];
    if (object == null) throw StateError('Unknown stored object: $objectId');
    if (object.deleting) {
      throw StateError('Stored object is being deleted: $objectId');
    }
    return object;
  }

  void _requireOpen() {
    if (_closing) throw StateError('The file store is closing or closed.');
  }

  Future<T> _runOperation<T>(Future<T> Function() operation) {
    if (_operationCount++ == 0) _idle = Completer<void>();
    return Future<T>.sync(operation).whenComplete(() {
      if (--_operationCount == 0) _idle!.complete();
    });
  }

  /// Stops new access and waits for file operations already in progress.
  ///
  /// Writers must first close their files and commit or abort; readers and
  /// retainers must release their handles. If handles remain, closing fails and
  /// can be retried after releasing them. Existing writes can still be aborted.
  /// Closing deletes cache categories and preserves required project files.
  Future<void> close() {
    _closing = true;
    return _closeFuture ??= _close().catchError((
      Object error,
      StackTrace stack,
    ) {
      _closeFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _close() async {
    while (_operationCount != 0) {
      await _idle!.future;
    }
    if (_writes.isNotEmpty ||
        _objects.values.any((o) => o.readers != 0 || o.retainers != 0)) {
      throw StateError('Release file store handles before closing.');
    }
    for (final category in categories.where((c) => c.isCache)) {
      await files.deleteDirectory(
        p.join(rootDirectory, category.directoryName),
      );
    }
    _openRoots.remove(_rootKey);
  }
}

class _StoredObject {
  int readers = 0;
  int retainers = 0;
  bool deleting = false;
}

enum _WriteState { pending, committing, aborting, committed, aborted }

/// A private file reserved for a single write transaction.
///
/// Flush and close file handles before [commit] or [abort], including handles in the
/// engine. The store does not own those OS handles and cannot close them itself.
class PendingFileWrite {
  final ProjectFileStore _store;
  final String _objectId;
  final String path;
  _WriteState _state = _WriteState.pending;

  PendingFileWrite._(this._store, this._objectId, this.path);

  /// Publishes the completed file and returns its stable object ID.
  ///
  /// A failed commit leaves the write available for retry or abort. Calling
  /// commit again after success returns the same ID without changing the file.
  Future<String> commit() {
    if (_state == _WriteState.committed) return Future.value(_objectId);
    _store._requireOpen();
    if (_state != _WriteState.pending) {
      throw StateError('The write is not available for commit.');
    }
    _state = _WriteState.committing;
    return _store._runOperation(() async {
      try {
        final destination = _store._filePath(_objectId);
        if (await files.entryExists(destination)) {
          throw StateError('A file already exists at $destination');
        }
        await files.renameFile(path, destination);
        _store._objects[_objectId] = _StoredObject();
        _store._writes.remove(this);
        _state = _WriteState.committed;
        return _objectId;
      } catch (_) {
        _state = _WriteState.pending;
        rethrow;
      }
    });
  }

  /// Removes an unfinished file. Repeated calls after a successful abort do nothing.
  Future<void> abort() {
    if (_state == _WriteState.aborted) return Future.value();
    if (_state != _WriteState.pending) {
      throw StateError('The write is not available for abort.');
    }
    _state = _WriteState.aborting;
    return _store._runOperation(() async {
      try {
        if (await files.entryExists(path)) await files.deleteFile(path);
        _store._writes.remove(this);
        _store._reservedNames.remove(_objectId.toLowerCase());
        _state = _WriteState.aborted;
      } catch (_) {
        _state = _WriteState.pending;
        rethrow;
      }
    });
  }
}

/// Read access to a committed object. Close the file before calling [release].
class StoredFileRead {
  final String objectId;
  final String path;
  void Function()? _release;

  StoredFileRead._(this.objectId, this.path, this._release);

  /// Releases read access. Repeated calls do nothing.
  void release() {
    _release?.call();
    _release = null;
  }
}

/// Retention of an object by project state, undo history, or recovery data.
class StoredFileRetention {
  final String objectId;
  void Function()? _release;

  StoredFileRetention._(this.objectId, this._release);

  /// Releases this reference. Other references and readers remain valid.
  void release() {
    _release?.call();
    _release = null;
  }
}

final _invalidNameCharacters = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
final _trailingDotsAndSpaces = RegExp(r'[. ]+$');
final _reservedDeviceName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$',
  caseSensitive: false,
);

bool _isValidObjectId(String id) {
  final parts = id.split('/');
  return parts.length == 2 && parts.every(_isValidFileName);
}

bool _isValidFileName(String id) =>
    id.isNotEmpty &&
    id != '.' &&
    id != '..' &&
    !_invalidNameCharacters.hasMatch(id) &&
    !_trailingDotsAndSpaces.hasMatch(id) &&
    !_reservedDeviceName.hasMatch(id.split('.').first) &&
    utf8.encode(id).length <= 240;

String _sanitizeBaseName(String value) {
  final sanitized = value
      .trim()
      .replaceAll(_invalidNameCharacters, '_')
      .replaceAll(_trailingDotsAndSpaces, '');
  final result = StringBuffer();
  var bytes = 0;
  for (final rune in sanitized.runes) {
    final character = String.fromCharCode(rune);
    bytes += utf8.encode(character).length;
    if (bytes > 160) break;
    result.write(character);
  }
  var name = result.toString().replaceAll(_trailingDotsAndSpaces, '');
  if (name.isEmpty) name = 'Object';
  if (_reservedDeviceName.hasMatch(name.split('.').first)) name = '_$name';
  return name;
}

String _extensionSuffix(String? extension) {
  if (extension == null || extension.isEmpty) return '';
  final value = extension.startsWith('.') ? extension.substring(1) : extension;
  if (value.length > 32 ||
      !RegExp(r'^[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*$').hasMatch(value)) {
    throw ArgumentError.value(
      extension,
      'extension',
      'Expected a file extension.',
    );
  }
  return '.${value.toLowerCase()}';
}
