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

import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:path/path.dart' as path;

import 'file_store_io_stub.dart'
    if (dart.library.io) 'file_store_io.dart'
    as files;

/// Manages files for a project.
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

  final List<ProjectFileCategory> categories;

  /// Whether this owner may discard the root when the project closes.
  ///
  /// Explicit roots belong to the user and are preserved. Temporary roots are
  /// allocated by [ProjectStorage.temporary] for unsaved projects.
  final bool isTemporary;

  Future<ProjectFileStore>? _fileStore;
  bool _initializationStarted = false;
  bool _closing = false;
  Future<void>? _closeFuture;
  Future<void>? _discardFuture;

  ProjectStorage({
    required String rootDirectory,
    Iterable<ProjectFileCategory> categories = ProjectFileCategory.defaults,
  }) : this._(rootDirectory, categories, false);

  /// Chooses a fresh temporary root without creating any files or directories.
  factory ProjectStorage.temporary({
    Iterable<ProjectFileCategory> categories = ProjectFileCategory.defaults,
  }) =>
      ProjectStorage._(files.temporaryProjectDirectoryPath(), categories, true);

  ProjectStorage._(
    String root,
    Iterable<ProjectFileCategory> categories,
    this.isTemporary,
  ) : rootDirectory = path.normalize(path.absolute(root)),
      categories = List.unmodifiable(categories);

  /// Files shared by the UI and engine for the lifetime of the project.
  ///
  /// Engine restarts leave the store intact. Each category controls whether its
  /// files must accompany a save or can be discarded and regenerated.
  Future<ProjectFileStore> get fileStore {
    if (_closing) throw StateError('Project storage is closing or closed.');
    _initializationStarted = true;
    return _fileStore ??=
        ProjectFileStore.open(rootDirectory, categories: categories).catchError(
          (Object error, StackTrace stackTrace) {
            _fileStore = null;
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
  }

  /// Closes storage after all engine and UI file access has ended.
  ///
  /// Waits for initialization, then deletes cache categories. Required project
  /// data is preserved, including data in a temporary root that may be needed
  /// for recovery. All clients must finish file I/O and close their store
  /// sessions first. Outstanding sessions prevent cleanup; close them and retry.
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
    final storeFuture = _fileStore;
    if (storeFuture == null) return;
    // Initialization failures are reported to the caller that opened the store.
    // Cleanup remains possible when initialization did not produce a store.
    final store = await storeFuture.then<ProjectFileStore?>(
      (value) => value,
      onError: (Object _, StackTrace _) => null,
    );
    if (store != null) await store.close();
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
    if (_initializationStarted) await files.deleteDirectory(rootDirectory);
  }
}
