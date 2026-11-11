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

import 'package:anthem/logic/commands/capture_live_processor_states.dart';
import 'package:anthem/logic/disposable_service.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:path/path.dart' as path;

/// Stores the project JSON and file access needed for a save or export.
///
/// [prepare] waits for pending commands and, if the engine is running, captures
/// the state of initialized processors. It then serializes the project and
/// takes a snapshot of [ProjectStorage.projectFiles], including that snapshot's
/// file reference manifest in [projectJson].
///
/// Writing the output involves asynchronous file I/O, during which the user
/// may continue editing. Those edits do not change the captured JSON or file
/// references, and [assets] keeps the referenced files available for reading
/// until [close] is called. [changedDuringSave] tracks subsequent model changes
/// so the caller can preserve the project's unsaved status when the written
/// output does not include the latest edits.
///
/// The caller passes this object to a directory or ZIP writer and must call
/// [close] after writing finishes, including when writing fails.
class PreparedProjectSave {
  final ProjectStorage storage;
  final Map<String, dynamic> projectJson;
  final AssetSnapshot assets;
  final ProjectModel _project;
  bool changedDuringSave = false;
  bool _closed = false;

  PreparedProjectSave._(
    this.storage,
    this.projectJson,
    this.assets,
    this._project,
  ) {
    _project.addRawFieldChangedListener(_onChange);
  }

  void _onChange(ModelChangeEvent _) => changedDuringSave = true;

  static Future<PreparedProjectSave> prepare(
    ProjectModel project,
    ProjectStorage storage,
  ) async {
    await project.waitForPendingCommands();
    await captureLiveProcessorStates(
      project,
      project.processingGraph.nodes.values.toList(),
    );
    await storage.assetStore;
    final assets = storage.projectFiles.snapshot();
    try {
      final json = project.toJson()
        ..['fileRetentions'] = jsonEncode(assets.references);
      return PreparedProjectSave._(storage, json, assets, project);
    } catch (_) {
      await assets.close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _project.removeRawFieldChangedListener(_onChange);
    await assets.close();
  }
}

/// Protects documents that share the working store's physical files.
/// Copies written to another root or ZIP need no claims on the source store.
class SavedProjectFiles implements DisposableService {
  final ProjectStorage storage;
  final Map<String, AssetRetention> _documents = {};
  SavedProjectFiles(this.storage);

  /// Call only after a document using the working store was read or published.
  /// Acquires replacement claims before releasing that document's previous ones.
  void record(String documentPath, Iterable<String> paths) {
    final replacement = storage.retainAssets(paths);
    final absolute = path.normalize(path.absolute(documentPath));
    final key = path.style == path.Style.windows
        ? absolute.toLowerCase()
        : absolute;
    final previous = _documents[key];
    _documents[key] = replacement;
    previous?.dispose();
  }

  @override
  void dispose() {
    for (final retained in _documents.values) {
      retained.dispose();
    }
    _documents.clear();
  }
}
