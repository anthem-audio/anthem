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

import 'project_asset_category.dart';
import 'project_asset_store.dart';
import 'asset_store_io_stub.dart'
    if (dart.library.io) 'asset_store_io.dart'
    as files;

/// Provides file storage for an open project.
///
/// A project can reference files, such as processor snapshots, in addition to
/// the data serialized in its document. This class owns the working directory
/// containing those files and opens its [ProjectAssetStore] on first use.
/// Constructing an instance does not create or scan the directory.
///
/// [projectFiles] holds the retention claims that belong to the current
/// document. Saving uses these claims to determine which files to include.
/// [retainAssets] keeps files needed independently of the document, such as
/// undo history or processor snapshots held by UI code. Clients that manage
/// their own file access, including engine sessions, obtain a scope through
/// [openScope] and are responsible for closing it.
///
/// For a new project, await [assetStore] before accessing the initially empty
/// [projectFiles] scope. When opening an existing project, the loader calls
/// [restoreProjectFiles] with the saved reference mapping before using that
/// scope. Opening [assetStore] discovers files without restoring document
/// references.
///
/// [rootDirectory] stays fixed for the lifetime of this object. Saving to
/// another directory copies the required files, so the engine can continue
/// using its existing working paths after Save As.
///
/// [close] releases project-owned scopes and closes the store, preserving
/// project data files and clearing caches. Callers must finish file I/O and
/// close any independently owned scopes or snapshots before closing storage.
/// For directories created or adopted through [ProjectStorage.temporary],
/// [discard] also removes the working directory. Directories supplied to the
/// regular constructor are preserved.
class ProjectStorage {
  final String rootDirectory;
  final List<ProjectAssetCategory> categories;
  final bool isTemporary;
  Future<ProjectAssetStore>? _opening;
  ProjectAssetStore? _store;
  AssetScope? _projectFiles;
  AssetScope? _runtimeFiles;
  bool _closing = false;
  Future<void>? _closeFuture;
  Future<void>? _discardFuture;

  ProjectStorage({
    required String rootDirectory,
    Iterable<ProjectAssetCategory> categories = ProjectAssetCategory.defaults,
  }) : this._(rootDirectory, categories, false);

  /// Allocates or adopts a temporary root, removed only by [discard].
  factory ProjectStorage.temporary({
    String? rootDirectory,
    Iterable<ProjectAssetCategory> categories = ProjectAssetCategory.defaults,
  }) => ProjectStorage._(
    rootDirectory ?? files.temporaryProjectDirectoryPath(),
    categories,
    true,
  );

  ProjectStorage._(
    String root,
    Iterable<ProjectAssetCategory> categories,
    this.isTemporary,
  ) : rootDirectory = path.normalize(path.absolute(root)),
      categories = List.unmodifiable(categories);

  /// Opens the file registry without restoring any document references.
  Future<ProjectAssetStore> get assetStore {
    if (_closing) throw StateError('Project storage is closing or closed.');
    return _opening ??=
        ProjectAssetStore.open(rootDirectory, categories: categories)
            .then((store) => _store = store)
            .catchError((Object error, StackTrace stack) {
              _opening = null;
              Error.throwWithStackTrace(error, stack);
            });
  }

  ProjectAssetStore get _openedStore {
    if (_closing || _store == null) {
      throw StateError('Open project storage before accessing its scopes.');
    }
    return _store!;
  }

  /// The claims included in saved project documents.
  /// New projects start empty. Loaded documents restore this scope before use.
  AssetScope get projectFiles =>
      _projectFiles ??= _openedStore.openScope(allowCacheFiles: false);

  /// Restores document claims before any project-file references are created.
  /// Failed restoration leaves the open store available for retry or cleanup.
  Future<void> restoreProjectFiles(Map<String, String> references) async {
    final store = await assetStore;
    if (_projectFiles != null) {
      throw StateError('Project references have already been initialized.');
    }
    _projectFiles = store.openScope(
      references: references,
      allowCacheFiles: false,
    );
  }

  /// Creates a scope whose caller owns its cleanup, such as an engine session.
  Future<AssetScope> openScope() async => (await assetStore).openScope();

  String resolveRetention(String id) => _openedStore.resolveRetention(id);

  /// Keeps files alive independently of membership in the current document.
  /// Handles are disposed individually or invalidated when storage closes.
  AssetRetention retainAssets(Iterable<String> paths) {
    final scope = _runtimeFiles ??= _openedStore.openScope();
    return scope.retainAll(paths);
  }

  /// Releases project-owned scopes and closes the store, preserving data files.
  /// Callers must finish I/O and close external scopes and snapshots first.
  /// If any remain open, closing fails and can be retried after their cleanup.
  /// An unused owner never accesses the filesystem.
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
    final opening = _opening;
    if (opening != null) {
      await opening.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    }
    await _projectFiles?.close();
    await _runtimeFiles?.close();
    await _store?.close();
  }

  /// Closes storage and removes a temporary root after save or explicit discard.
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
