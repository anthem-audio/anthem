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

import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/model/project.dart';
import 'package:path/path.dart' as path;

/// Saves completed, non-cache files alongside the project document.
///
/// A new project directory is assembled in a sibling temporary directory and
/// published only after all writes succeed. Later saves publish the document
/// last, by renaming a completed temporary file over the previous document.
/// Additional data files from an interrupted save may remain unreferenced.
///
/// The open store keeps its root and read paths until the project closes.
Future<void> writeProjectDirectory(
  String documentPath,
  ProjectModel project,
  ProjectFileStore store, {
  required bool create,
}) async {
  final root = path.dirname(documentPath);
  if (create &&
      await FileSystemEntity.type(root, followLinks: false) !=
          FileSystemEntityType.notFound) {
    throw FileSystemException('Choose a new project folder name.', root);
  }

  final session = store.openSession();
  Directory? staging;
  try {
    staging = await Directory(create ? path.dirname(root) : root)
        .createTemp('.anthem-save-');
    // Acquire all reads before yielding, so deletion cannot interrupt a save.
    final reads = {
      for (final relativePath in store.projectFilePaths)
        relativePath: store.acquireRead(session, relativePath),
    };
    for (final entry in reads.entries) {
      final destination = File(path.join(root, entry.key));
      if (!create && await destination.exists()) {
        // Committed files are immutable. A previous save may already have
        // copied this file, or the open store may be rooted here itself.
        continue;
      }
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
    await writeProjectFile(document, project);
    if (create) {
      if (await FileSystemEntity.type(root, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw FileSystemException('The project folder already exists.', root);
      }
      await staging.rename(root);
    } else {
      await File(document).rename(documentPath);
    }
  } finally {
    await store.closeSession(session);
    if (staging != null && await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}
