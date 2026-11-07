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

import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/logic/storage/project_asset_references.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:path/path.dart' as path;

import 'asset_store_io_stub.dart'
    if (dart.library.io) 'asset_store_io.dart'
    as files;

/// Manages a project's stored assets.
///
/// A loaded project uses its saved folder as the root. A new project uses a
/// temporary root. Saving copies required files to the chosen folder; the open
/// store keeps its root until project closure so existing read paths stay valid.
///
/// These files will be used to store audio clips from the project, and
/// plugin states. The reason for storing plugin states as separate files is
/// that they may be very large; storing such large state blobs in the project
/// file means we also must hold them in memory in both the UI and the engine,
/// and sync them over IPC when they change. Some plugins store audio clips in
/// their plugin state, so there is no reason to put these directly in the
/// in-memory project model.
class ProjectStorage {
  /// Root chosen by the project owner. It is created on first file access.
  final String rootDirectory;

  final List<ProjectAssetCategory> categories;

  /// Whether this owner may discard the root when the project closes.
  ///
  /// Explicit roots belong to the user and are preserved. Temporary roots are
  /// allocated or adopted by [ProjectStorage.temporary] for unsaved projects.
  final bool isTemporary;

  Future<ProjectAssetStore>? _initializationFuture;
  ProjectAssetStore? _openedStore;
  final ProjectModel _project;
  ProjectAssetReferences? _references;
  bool _closing = false;
  Future<void>? _closeFuture;
  Future<void>? _discardFuture;

  ProjectStorage({
    required String rootDirectory,
    required ProjectModel project,
    Iterable<ProjectAssetCategory> categories = ProjectAssetCategory.defaults,
  }) : this._(rootDirectory, categories, false, project);

  /// Owns a temporary root, deleting it when [discard] is called.
  ///
  /// If [rootDirectory] is omitted, chooses a fresh path without creating it.
  /// Otherwise, takes ownership of the supplied directory and its contents.
  factory ProjectStorage.temporary({
    required ProjectModel project,
    String? rootDirectory,
    Iterable<ProjectAssetCategory> categories = ProjectAssetCategory.defaults,
  }) => ProjectStorage._(
    rootDirectory ?? files.temporaryProjectDirectoryPath(),
    categories,
    true,
    project,
  );

  ProjectStorage._(
    String root,
    Iterable<ProjectAssetCategory> categories,
    this.isTemporary,
    this._project,
  ) : rootDirectory = path.normalize(path.absolute(root)),
      categories = List.unmodifiable(categories);

  /// Assets shared by the UI and engine for the lifetime of the project.
  ///
  /// Engine restarts leave the store intact. Each category controls whether its
  /// files must accompany a save or can be discarded and regenerated.
  Future<ProjectAssetStore> get assetStore {
    if (_closing) throw StateError('Project storage is closing or closed.');
    return _initializationFuture ??= _initialize();
  }

  Future<ProjectAssetStore> _initialize() async {
    try {
      final store = _openedStore ??= await ProjectAssetStore.open(
        rootDirectory,
        categories: categories,
      );
      _references ??= ProjectAssetReferences(_project.fileRetentions, store);
      return store;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  /// Manages asset claims for the open project, independent snapshot handles,
  /// undo history, and saved documents.
  ///
  /// Its `snapshot()` method captures only current-project references, excluding
  /// files held solely by history, independent handles, or saved documents.
  Future<ProjectAssetReferences> get references async {
    await assetStore;
    return _references!;
  }

  ProjectAssetReferences get _openedReferences {
    final references = _references;
    if (_closing || references == null) {
      throw StateError(
        'Open project storage before accessing file retentions.',
      );
    }
    return references;
  }

  /// Retains an asset for the current project and returns its retention ID.
  String retainAssetForProject(String relativePath) =>
      _openedReferences.retainAssetForProject(relativePath);

  /// Releases a project-owned claim without deleting its asset.
  void releaseAssetFromProject(String retentionId) =>
      _openedReferences.releaseAssetFromProject(retentionId);

  /// Resolves a live retention to its project-relative file path.
  String resolveRetention(String retentionId) =>
      _openedReferences.store.resolveRetention(retentionId);

  /// Retains assets in an already opened store until the claim is disposed.
  ///
  /// Files must have been created or loaded through this storage first.
  ProjectAssetRetention retainAssets(Iterable<String> paths) {
    return _openedReferences.retainAssets(paths);
  }

  /// Closes storage after all engine and UI file access has ended.
  ///
  /// Waits for initialization, then deletes cache categories. Required project
  /// data is preserved, including data in a temporary root that may be needed
  /// for recovery. All clients must finish file I/O and close their store
  /// scopes first. Outstanding scopes prevent cleanup; close them and retry.
  /// Closing an unused owner does not access the filesystem.
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
    final initializationFuture = _initializationFuture;
    if (initializationFuture == null && _openedStore == null) return;
    // Initialization failures are reported to the caller that opened the store.
    // Cleanup remains possible when initialization did not produce a store.
    final store = initializationFuture == null
        ? _openedStore
        : await initializationFuture.then<ProjectAssetStore?>(
            (value) => value,
            onError: (Object _, StackTrace _) => _openedStore,
          );
    if (store != null) {
      await _references?.close();
      await store.close();
    }
  }

  /// Closes an unsaved project's storage and deletes its temporary root.
  ///
  /// Call after the project has been saved elsewhere or explicitly discarded.
  /// This can follow [close] if temporary data was initially kept for recovery.
  /// Throws [StateError] for an explicit root, which must be preserved on close.
  Future<void> discard() {
    if (!isTemporary) {
      throw StateError('Cannot discard an explicit project root.');
    }
    return _discardFuture ??= _discard().catchError((
      Object error,
      StackTrace stack,
    ) {
      _discardFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _discard() async {
    await close();
    await files.deleteDirectory(rootDirectory);
  }
}
