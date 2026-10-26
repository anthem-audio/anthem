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

import 'package:path/path.dart' as path;

import 'project_asset_store.dart';

/// Manages project ownership, saved-document claims, and save snapshots.
///
/// Saves export the current project scope's claims. Commands and saved
/// documents hold independent runtime claims.
class ProjectAssetReferences {
  final ProjectAssetStore store;
  final String _currentScope;
  final String _claimScope;
  final _savedDocuments = <String, String>{};
  bool _closed = false;

  ProjectAssetReferences(String serializedRetentions, this.store)
    : _currentScope = store.openScope(
        serializedRetentions: serializedRetentions,
      ),
      _claimScope = store.openScope();

  /// Adds a claim owned by the current project and returns its retention ID.
  String retainAssetForProject(String relativePath) {
    final directory = relativePath.split('/').first;
    if (store.categories.any(
      (c) => c.directoryName == directory && c.isCache,
    )) {
      throw StateError('Cache files cannot be owned by the project.');
    }
    return store.retain(_currentScope, relativePath);
  }

  /// Releases a current-project claim without deleting its file.
  void releaseAssetFromProject(String retentionId) =>
      store.releaseRetention(_currentScope, retentionId);

  /// Retains specific assets until the returned claim is disposed.
  ProjectAssetRetention retainAssets(Iterable<String> paths) {
    final tokens = <String>[];
    try {
      for (final file in paths.toSet()) {
        tokens.add(store.retain(_claimScope, file));
      }
    } catch (_) {
      for (final token in tokens) {
        store.releaseRetention(_claimScope, token);
      }
      rethrow;
    }
    return ProjectAssetRetention._(this, tokens);
  }

  /// Captures the files referenced by the current project, holding read access.
  ProjectAssetSnapshot snapshot() {
    final retentions = store.serializeRetentions(_currentScope);
    final scope = store.openScope();
    final reads = <String, StoredFileAccess>{};
    for (final file in store.retainedAssetPaths(_currentScope)) {
      reads[file] = store.acquireRead(scope, file);
    }
    return ProjectAssetSnapshot._(
      this,
      scope,
      Map.unmodifiable(reads),
      retentions,
    );
  }

  /// Retains the current file references for a document already on disk.
  Future<void> registerSavedDocument(String documentPath) =>
      _recordSaved(documentPath, store.retainedAssetPaths(_currentScope));

  Future<void> _recordSaved(String documentPath, Iterable<String> paths) async {
    final scope = store.openScope();
    try {
      for (final file in paths) {
        store.retain(scope, file);
      }
    } catch (_) {
      await store.closeScope(scope);
      rethrow;
    }
    final absolute = path.normalize(path.absolute(documentPath));
    final key = path.style == path.Style.windows
        ? absolute.toLowerCase()
        : absolute;
    final previous = _savedDocuments[key];
    _savedDocuments[key] = scope;
    if (previous != null) await store.closeScope(previous);
  }

  /// Releases this project's ownership after its clients have stopped using files.
  Future<void> close() async {
    _closed = true;
    await Future.wait([
      store.closeScope(_currentScope),
      store.closeScope(_claimScope),
      ..._savedDocuments.values.map(store.closeScope),
    ]);
    _savedDocuments.clear();
  }
}

/// File reads held for one save, independently of subsequent project edits.
class ProjectAssetSnapshot {
  final ProjectAssetReferences _owner;
  final String _scope;
  final Map<String, StoredFileAccess> reads;

  /// Serialized ownership claims captured with [reads].
  final String serializedRetentions;
  bool _recorded = false;

  ProjectAssetSnapshot._(
    this._owner,
    this._scope,
    this.reads,
    this.serializedRetentions,
  );

  /// Records these references after the project document was published.
  Future<void> markSaved(String documentPath) async {
    if (_recorded) throw StateError('This snapshot was already saved.');
    await _owner._recordSaved(documentPath, reads.keys);
    _recorded = true;
  }

  Future<void> close() => _owner.store.closeScope(_scope);
}

/// An explicit claim that keeps assets available until [dispose] is called.
class ProjectAssetRetention {
  final ProjectAssetReferences _owner;
  final List<String> _tokens;

  ProjectAssetRetention._(this._owner, this._tokens);

  /// Releases this claim without deleting the files. May be called repeatedly.
  void dispose() {
    if (!_owner._closed) {
      for (final token in _tokens) {
        _owner.store.releaseRetention(_owner._claimScope, token);
      }
    }
    _tokens.clear();
  }
}
