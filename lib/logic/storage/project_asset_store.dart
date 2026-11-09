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

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'project_asset_category.dart';
import 'file_fingerprint.dart';

import 'asset_file_io.dart' as files;

/// Coordinates access to one project's stored assets.
///
/// File paths are relative to [rootDirectory], such as `plugin
/// states/Preset 01.bin`. They always use forward slashes and remain valid when
/// the project moves.
///
/// Committed files are immutable; changed contents must be written to a new
/// file.
///
/// Each file scope owns its read, write, and retention tokens. Closing a scope
/// releases its access without deleting committed files. The caller must finish
/// file I/O before releasing access or closing its scope. Filesystem changes
/// outside this API are not coordinated by the store.
class ProjectAssetStore {
  static final _openRoots = <String>{};
  static const _uuid = Uuid();

  /// Absolute project root, containing category folders and `.pending` writes.
  final String rootDirectory;

  /// Categories known to this store, including regenerable caches.
  final List<ProjectAssetCategory> categories;
  final Map<String, ProjectAssetCategory> _categoriesByName;
  final String _rootKey;
  final Map<String, _StoredObject> _objects = {};
  final Set<String> _reservedNames = {};
  final Set<AssetScope> _scopes = {};
  bool _closing = false;
  Future<void>? _closeFuture;

  ProjectAssetStore._(this.rootDirectory, this._rootKey, this.categories)
    : _categoriesByName = {for (final c in categories) c.directoryName: c};

  /// Opens a project root, creating its category folders if needed.
  ///
  /// Existing file paths are recovered by scanning [categories]. Other folders
  /// and project documents in the root are left alone. Opening the store does
  /// not delete files or abandoned writes.
  static Future<ProjectAssetStore> open(
    String rootDirectory, {
    required Iterable<ProjectAssetCategory> categories,
  }) async {
    final categoryList = List<ProjectAssetCategory>.unmodifiable(categories);
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
    final requestedRoot = files.absolutePath(rootDirectory);
    await files.createDirectory(requestedRoot);
    final root = await files.resolveDirectory(requestedRoot);
    final key = p.style == p.Style.windows ? root.toLowerCase() : root;
    if (!_openRoots.add(key)) {
      throw StateError('The asset store is already open: $root');
    }
    final store = ProjectAssetStore._(root, key, categoryList);
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
          final relativePath = p.posix.join(folder, entry.name);
          if (!store._reservedNames.add(relativePath.toLowerCase())) {
            throw FormatException(
              'File names differ only by case: $relativePath',
            );
          }
          if (entry.isFile && _isValidFileName(entry.name)) {
            store._objects[relativePath] = _StoredObject(relativePath);
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

  String _absolutePath(String relativePath) =>
      p.joinAll([rootDirectory, ...relativePath.split('/')]);

  /// A snapshot of committed relative file paths currently available for access.
  List<String> get relativePaths {
    _requireOpen();
    return List.unmodifiable(
      _objects.keys.where((relativePath) => !_objects[relativePath]!.deleting),
    );
  }

  /// An inventory of committed paths, excluding caches and unfinished writes.
  /// Includes files regardless of which scope retains them.
  List<String> get projectAssetPaths => List.unmodifiable(
    relativePaths.where(
      (relativePath) =>
          !_categoriesByName[relativePath.split('/').first]!.isCache,
    ),
  );

  /// Opens an independently owned scope, optionally restoring reference IDs.
  /// Closing a scope releases its access without deleting committed files.
  ///
  /// When [allowCacheFiles] is false, this scope cannot retain cache files.
  /// Reading and writing cache files is still allowed.
  AssetScope openScope({
    Map<String, String> references = const {},
    bool allowCacheFiles = true,
  }) {
    _requireOpen();
    final scope = AssetScope._(this, allowCacheFiles);
    final objects = <_StoredObject>[];
    for (final entry in references.entries) {
      if (entry.key.isEmpty ||
          _scopes.any((s) => s._retentions.containsKey(entry.key))) {
        throw StateError('Duplicate or empty retention ID: ${entry.key}');
      }
      final object = _objectForAccess(entry.value);
      scope._checkRetentionCategory(entry.value);
      objects.add(object);
    }
    // Publish ownership only after every reference has been resolved.
    scope._retentions.addAll(references);
    for (final object in objects) {
      object.retainers++;
    }
    _scopes.add(scope);
    return scope;
  }

  /// Resolves a claim in any scope. Reading requires a separate read grant.
  String resolveRetention(String retentionId) {
    _requireOpen();
    for (final scope in _scopes) {
      final relativePath = scope._retentions[retentionId];
      if (relativePath != null) return relativePath;
    }
    throw StateError('Unknown file retention: $retentionId');
  }

  _StoredObject _objectForAccess(String relativePath) {
    _requireOpen();
    if (!_isValidRelativePath(relativePath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Expected a category/filename path.',
      );
    }
    final object = _objects[relativePath];
    if (object == null) {
      throw StateError('Unknown stored object: $relativePath');
    }
    if (object.deleting) {
      throw StateError('Stored object is being deleted: $relativePath');
    }
    return object;
  }

  void _requireOpen() {
    if (_closing) throw StateError('The asset store is closing or closed.');
  }

  /// Closes the store, deleting cache categories and preserving other files.
  ///
  /// Rejects new access immediately. Throws [StateError] if any scopes remain
  /// open; close them with [AssetScope.close] before retrying.
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
    if (_scopes.isNotEmpty) {
      throw StateError('Close asset store scopes before closing the store.');
    }
    for (final category in categories.where((c) => c.isCache)) {
      await files.deleteDirectory(
        p.join(rootDirectory, category.directoryName),
      );
    }
    _openRoots.remove(_rootKey);
  }
}

/// Owns file grants and retention claims for a caller-chosen lifetime.
/// File I/O must finish before grants are released or this scope is closed.
class AssetScope {
  final ProjectAssetStore _store;
  final bool allowCacheFiles;
  final _writes = <String, _PendingFileWrite>{};
  final _reads = <String, _StoredObject>{};
  final _retentions = <String, String>{};
  final _operations = <Future<void>>{};
  bool _closing = false;
  Future<void>? _closeFuture;

  AssetScope._(this._store, this.allowCacheFiles);

  bool get isClosed => _closing;

  Map<String, String> get references {
    _requireOpen();
    return Map.unmodifiable(_retentions);
  }

  String resolveRetention(String id) {
    _requireOpen();
    return _store.resolveRetention(id);
  }

  AssetRetention retainAll(Iterable<String> paths) {
    _requireOpen();
    final tokens = <String>[];
    try {
      for (final file in paths.toSet()) {
        tokens.add(retain(file));
      }
      return AssetRetention._(this, tokens);
    } catch (_) {
      for (final token in tokens) {
        releaseRetention(token);
      }
      rethrow;
    }
  }

  /// Captures this scope's references and independently pins their files.
  /// The result survives changes to, or closure of, the source scope.
  AssetSnapshot snapshot() {
    final captured = references;
    final access = _store.openScope();
    try {
      final reads = {
        for (final file in captured.values.toSet())
          file: access.acquireRead(file),
      };
      return AssetSnapshot._(access, captured, Map.unmodifiable(reads));
    } catch (_) {
      // Acquiring reads is synchronous, so there is no external I/O to finish.
      access.close();
      rethrow;
    }
  }

  void _requireOpen() {
    _store._requireOpen();
    if (_closing) {
      throw StateError('The asset scope is closing.');
    }
  }

  /// Reserves an object name and creates a private file for the writer.
  ///
  /// With [baseName], names are numbered, for example `Bass 01.wav`. Without it,
  /// a UUID is used. [extension] is optional and may begin with a dot. [category]
  /// is the directory name of a registered category. Names are reserved before
  /// file creation, including against other pending writes.
  Future<StoredFileAccess> beginWrite(
    String category, {
    String? baseName,
    String? extension,
  }) {
    _requireOpen();
    if (!_store._categoriesByName.containsKey(category)) {
      throw ArgumentError('Unknown file category: $category');
    }
    final suffix = _extensionSuffix(extension);
    final stem = baseName == null ? null : _sanitizeBaseName(baseName);
    var number = 1;
    late String relativePath;
    do {
      final name = stem == null
          ? '${ProjectAssetStore._uuid.v4()}$suffix'
          : '$stem ${(number++).toString().padLeft(2, '0')}$suffix';
      relativePath = p.posix.join(category, name);
    } while (!_store._reservedNames.add(relativePath.toLowerCase()));

    final token = ProjectAssetStore._uuid.v4();
    final write = _PendingFileWrite(
      relativePath,
      p.join(_store._pendingDirectory, '${ProjectAssetStore._uuid.v4()}.tmp'),
    );
    return _runOperation(() async {
      try {
        await files.createFile(write.absolutePath);
        _writes[token] = write;
        return StoredFileAccess(token: token, absolutePath: write.absolutePath);
      } catch (_) {
        _store._reservedNames.remove(relativePath.toLowerCase());
        rethrow;
      }
    });
  }

  /// Publishes a finished write and returns its relative path.
  ///
  /// Flush and close the file first. Success consumes [token]; a failed commit
  /// leaves it available for retry or abort. Tokens belong to this scope.
  ///
  /// [fingerprint] may be supplied by the writer to avoid hashing the file on
  /// its first metadata request. It must describe the bytes actually written.
  Future<String> commitWrite(String token, {FileFingerprint? fingerprint}) {
    _requireOpen();
    final write = _writeForAccess(token);
    write.busy = true;
    return _runOperation(() async {
      try {
        final destination = _store._absolutePath(write.relativePath);
        if (await files.entryExists(destination)) {
          throw StateError('A file already exists at $destination');
        }
        await files.renameFile(write.absolutePath, destination);
        _store._objects[write.relativePath] = _StoredObject(
          write.relativePath,
          fingerprint,
        );
        _writes.remove(token);
        return write.relativePath;
      } finally {
        write.busy = false;
      }
    });
  }

  /// Removes an unfinished file and consumes its write token.
  ///
  /// Close the file first. A failed abort leaves the token available for retry.
  Future<void> abortWrite(String token) {
    _requireOpen();
    final write = _writeForAccess(token);
    return _runOperation(() => _abortWrite(token, write));
  }

  _PendingFileWrite _writeForAccess(String token) {
    final write = _writes[token];
    if (write == null) throw StateError('Unknown file write token.');
    if (write.busy) throw StateError('The write is already in progress.');
    return write;
  }

  Future<void> _abortWrite(String token, _PendingFileWrite write) async {
    write.busy = true;
    try {
      if (await files.entryExists(write.absolutePath)) {
        await files.deleteFile(write.absolutePath);
      }
      _writes.remove(token);
      _store._reservedNames.remove(write.relativePath.toLowerCase());
    } finally {
      write.busy = false;
    }
  }

  /// Prevents deletion until [releaseRead] or [close] releases access.
  StoredFileAccess acquireRead(String relativePath) {
    _requireOpen();
    final object = _store._objectForAccess(relativePath);
    final token = ProjectAssetStore._uuid.v4();
    object.readers++;
    _reads[token] = object;
    return StoredFileAccess(
      token: token,
      absolutePath: _store._absolutePath(relativePath),
    );
  }

  /// Returns the contents fingerprint for an active read token.
  ///
  /// Fingerprints are calculated on first access and cached while the store is
  /// open. A writer may provide the fingerprint when committing.
  /// Committed files must not be edited in place outside the store.
  Future<FileFingerprint> getFingerprint(String readToken) {
    _requireOpen();
    final object = _reads[readToken];
    if (object == null) throw StateError('Unknown file read token.');
    object.readers++;
    return _runOperation(() async {
      try {
        final absolutePath = _store._absolutePath(object.relativePath);
        // Check that a cached fingerprint still refers to an existing file.
        final byteLength = await files.fileLength(absolutePath);
        final cached = object.fingerprint;
        if (cached != null && cached.byteLength == byteLength) return cached;
        return object.fingerprint = await files.readFingerprint(absolutePath);
      } finally {
        object.readers--;
      }
    });
  }

  /// Consumes a read token after the caller has closed the file.
  void releaseRead(String token) {
    _requireOpen();
    final object = _reads.remove(token);
    if (object == null) throw StateError('Unknown file read token.');
    object.readers--;
  }

  /// Keeps an object available independently of whether it is being read.
  ///
  /// Returns a retention ID owned by this scope. Independent claims on the same
  /// file have different IDs. Releasing a claim does not delete its file.
  String retain(String relativePath) {
    _requireOpen();
    final object = _store._objectForAccess(relativePath);
    _checkRetentionCategory(relativePath);
    final token = ProjectAssetStore._uuid.v4();
    object.retainers++;
    _retentions[token] = relativePath;
    return token;
  }

  void _checkRetentionCategory(String relativePath) {
    if (!allowCacheFiles &&
        _store._categoriesByName[relativePath.split('/').first]!.isCache) {
      throw StateError('This scope cannot retain cache files.');
    }
  }

  /// Consumes a retention token; other references and readers remain valid.
  void releaseRetention(String token) {
    _requireOpen();
    final relativePath = _retentions.remove(token);
    if (relativePath == null) throw StateError('Unknown file retention token.');
    _store._objects[relativePath]!.retainers--;
  }

  /// Deletes an unreferenced object, rejecting new access during deletion.
  ///
  /// Throws [StateError] if any scope has a read or retention token for the
  /// object.
  Future<void> delete(String relativePath) {
    _requireOpen();
    final object = _store._objectForAccess(relativePath);
    if (object.readers != 0 || object.retainers != 0) {
      throw StateError('Stored object is still in use: $relativePath');
    }
    object.deleting = true;
    return _runOperation(() async {
      try {
        await files.deleteFile(_store._absolutePath(relativePath));
        _store._objects.remove(relativePath);
        _store._reservedNames.remove(relativePath.toLowerCase());
      } finally {
        object.deleting = false;
      }
    });
  }

  /// Closes a scope and releases its file access.
  ///
  /// The caller must first finish file I/O and close any open files. New
  /// operations are rejected while operations already in progress finish.
  /// Remaining writes are aborted, and read and retention tokens are released.
  /// Committed files and other scopes are unaffected.
  ///
  /// If cleanup fails, the scope can be closed again to retry it. Closing an
  /// already closed scope has no effect.
  Future<void> close() {
    if (!_store._scopes.contains(this)) return Future.value();
    _closing = true;
    return _closeFuture ??= _closeScope().catchError((
      Object error,
      StackTrace stack,
    ) {
      _closeFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _closeScope() async {
    await Future.wait(_operations);
    for (final object in _reads.values) {
      object.readers--;
    }
    _reads.clear();
    for (final relativePath in _retentions.values) {
      _store._objects[relativePath]!.retainers--;
    }
    _retentions.clear();
    await Future.wait(
      _writes.entries.toList().map(
        (entry) => _abortWrite(entry.key, entry.value),
      ),
    );
    _store._scopes.remove(this);
  }

  Future<T> _runOperation<T>(Future<T> Function() operation) {
    final future = Future<T>.sync(operation);
    // Cleanup waits for completion, while the caller receives the result or error.
    final finished = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _operations.add(finished);
    return future.whenComplete(() => _operations.remove(finished));
  }
}

/// An independently disposable group of claims in an owning scope.
class AssetRetention {
  final AssetScope _scope;
  final List<String> _tokens;
  AssetRetention._(this._scope, this._tokens);

  bool get isDisposed => _scope.isClosed || _tokens.isEmpty;
  List<String> get retentionIds => List.unmodifiable(_tokens);

  AssetRetention retain() {
    if (isDisposed) throw StateError('The retention has been disposed.');
    return _scope.retainAll(_tokens.map((token) => _scope._retentions[token]!));
  }

  void dispose() {
    if (!_scope.isClosed) {
      for (final token in _tokens) {
        _scope.releaseRetention(token);
      }
    }
    _tokens.clear();
  }
}

/// Frozen reference IDs and file reads, owned independently of the source scope.
class AssetSnapshot {
  final AssetScope _scope;
  final Map<String, String> references;
  final Map<String, StoredFileAccess> reads;
  AssetSnapshot._(this._scope, this.references, this.reads);
  Future<void> close() => _scope.close();
}

/// A scope-owned token and the absolute path it grants access to.
///
/// Pass [token] to the store to commit or abort a write, or to release a read.
/// The token is consumed when that operation succeeds.
class StoredFileAccess {
  final String token;
  final String absolutePath;

  const StoredFileAccess({required this.token, required this.absolutePath});
}

class _PendingFileWrite {
  final String relativePath;
  final String absolutePath;
  bool busy = false;

  _PendingFileWrite(this.relativePath, this.absolutePath);
}

class _StoredObject {
  final String relativePath;
  FileFingerprint? fingerprint;
  int readers = 0;
  int retainers = 0;
  bool deleting = false;

  _StoredObject(this.relativePath, [this.fingerprint]);
}

final _invalidNameCharacters = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
final _trailingDotsAndSpaces = RegExp(r'[. ]+$');
final _reservedDeviceName = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])$',
  caseSensitive: false,
);

bool _isValidRelativePath(String relativePath) {
  final parts = relativePath.split('/');
  return parts.length == 2 && parts.every(_isValidFileName);
}

bool _isValidFileName(String fileName) =>
    fileName.isNotEmpty &&
    fileName != '.' &&
    fileName != '..' &&
    !_invalidNameCharacters.hasMatch(fileName) &&
    !_trailingDotsAndSpaces.hasMatch(fileName) &&
    !_reservedDeviceName.hasMatch(fileName.split('.').first) &&
    utf8.encode(fileName).length <= 240;

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
