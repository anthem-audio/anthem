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

import 'package:archive/archive.dart';

import 'archive_format.dart';
import 'errors.dart';

typedef ArchiveFileIntegrity = ({int length, int crc32});

/// Provides ZIP metadata and file contents without imposing project policy.
/// Native sources use the Dart ZIP decoder; browser sources use a JS worker.
/// Entry indices refer to the complete list returned by [readEntries], including
/// directories. [writeFile] finishes writing before its future completes.
abstract interface class ProjectArchiveSource {
  Future<List<ProjectArchiveEntry>> readEntries();
  Future<void> writeFile(int entryIndex, OutputStream output);
  Future<void> close();
}

/// Platform I/O used by [extractProjectArchiveContents].
///
/// Paths are relative to a fresh extraction directory and have already passed
/// the project archive's path checks. Files are written one at a time:
/// [createFile] opens an output, and [finishFile] closes it and reports the
/// extracted bytes' length and CRC. [discard] must close any unfinished file
/// and remove the directory, including after a partially failed creation.
abstract interface class ProjectArchiveDestination {
  Future<void> create();
  Future<void> createDirectory(String relativePath);
  Future<OutputStream> createFile(String relativePath);
  Future<ArchiveFileIntegrity> finishFile();
  Future<void> discard();
}

/// Extracts and verifies a project archive, returning its document's name.
///
/// Path rules, integrity checks, extraction order, and failure cleanup are
/// shared across platforms. The adapters supply ZIP entries and filesystem I/O;
/// this workflow owns the source until it closes.
Future<String> extractProjectArchiveContents(
  ProjectArchiveSource source,
  ProjectArchiveDestination destination,
) async {
  try {
    try {
      final entries = await source.readEntries();
      final documentName = validateProjectArchive(entries);
      await destination.create();
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        if (entry.isDirectory) {
          await destination.createDirectory(entry.name);
          continue;
        }
        final output = await destination.createFile(entry.name);
        await source.writeFile(index, output);
        final integrity = await destination.finishFile();
        if (integrity.length != entry.length ||
            integrity.crc32 != entry.crc32) {
          throw const FormatException('Damaged file in project archive.');
        }
      }
      return documentName;
    } finally {
      await source.close();
    }
  } catch (error, stack) {
    await destination.discard();
    if (error is ProjectFileReadException) rethrow;
    Error.throwWithStackTrace(
      InvalidProjectFileException(cause: error, causeStackTrace: stack),
      stack,
    );
  }
}
