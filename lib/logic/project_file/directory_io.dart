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

import 'dart:io';

import 'package:anthem/logic/project_file/io.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:path/path.dart' as path;

/// Saves completed, non-cache files alongside the project document.
///
/// A new project directory is assembled in a sibling temporary directory and
/// published only after all writes succeed. Later saves publish the document
/// last, by renaming a completed temporary file over the previous document.
/// Additional data files from an interrupted save may remain unreferenced.
///
/// The open store keeps its root and read paths until the project closes.
/// Files come from the current project scope. Existing copies in another
/// folder are replaced; files in the open store's root stay in place.
///
/// Reports whether the project changed after its save snapshot was prepared.
Future<({bool changedDuringSave})> writeProjectDirectory(
  String documentPath,
  ProjectModel project,
  ProjectStorage storage, {
  required bool create,
}) async {
  final store = await storage.assetStore;
  final references = await storage.references;
  final snapshot = references.snapshot();
  final root = path.dirname(documentPath);
  Directory? staging;
  var changedDuringSave = false;
  void onModelChange(ModelChangeEvent _) => changedDuringSave = true;
  try {
    // Updating the saved file claims is preparation for this save. Start
    // tracking subsequent edits only after those claims are in the model.
    project.fileRetentions = snapshot.serializedRetentions;
    project.addRawFieldChangedListener(onModelChange);
    final projectJson = project.toJson();
    if (create &&
        await FileSystemEntity.type(root, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw FileSystemException('Choose a new project folder name.', root);
    }
    final savingInPlace =
        !create && await FileSystemEntity.identical(store.rootDirectory, root);
    staging = await Directory(create ? path.dirname(root) : root)
        .createTemp('.anthem-save-');
    for (final entry in snapshot.reads.entries) {
      if (savingInPlace) {
        if (await FileSystemEntity.type(
              entry.value.absolutePath,
              followLinks: false,
            ) !=
            FileSystemEntityType.file) {
          throw FileSystemException(
            'Missing project data file.',
            entry.value.absolutePath,
          );
        }
        continue;
      }
      final destination = File(path.join(root, entry.key));
      final staged = File(path.join(staging.path, entry.key));
      await staged.parent.create(recursive: true);
      await File(entry.value.absolutePath).copy(staged.path);
      if (!create) {
        final category = destination.parent;
        final type = await FileSystemEntity.type(
          category.path,
          followLinks: false,
        );
        if (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory) {
          throw FileSystemException(
            'Invalid project category folder.',
            category.path,
          );
        }
        await category.create();
        await staged.rename(destination.path);
      }
    }

    final document = path.join(staging.path, path.basename(documentPath));
    await writeProjectFileToPath(document, projectJson);
    if (create) {
      if (await FileSystemEntity.type(root, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FileSystemException('The project folder already exists.', root);
      }
      await staging.rename(root);
    } else {
      await File(document).rename(documentPath);
    }
    await snapshot.markSaved(documentPath);
  } finally {
    try {
      await snapshot.close();
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    } finally {
      project.removeRawFieldChangedListener(onModelChange);
    }
  }
  return (changedDuringSave: changedDuringSave);
}
