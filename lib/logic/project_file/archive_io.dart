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
import 'dart:isolate';

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/io.dart';

import 'project_save.dart';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// Exports one project document and its referenced assets at the ZIP root.
///
/// Preparation captures live processor state. Its read claims hold the
/// captured files through compression, independently of subsequent edits. Cache
/// files and assets retained only by history or other snapshots are excluded.
/// Export does not change the project's save location or dirty status.
Future<void> writeProjectArchive(
  String archivePath,
  PreparedProjectSave prepared,
) async {
  final assets = {
    for (final entry in prepared.assets.reads.entries)
      entry.key: entry.value.absolutePath,
  };
  final projectJson = prepared.projectJson;
  await Isolate.run(() => _writeArchive(archivePath, projectJson, assets));
}

Future<void> _writeArchive(
  String archivePath,
  Map<String, dynamic> projectJson,
  Map<String, String> assets,
) async {
  final staging = await Directory(path.dirname(archivePath))
      .createTemp('.anthem-export-');
  try {
    final document = File(path.join(staging.path, 'project.anthem'));
    await writeProjectFileToPath(document.path, projectJson);
    final completed = path.join(staging.path, 'project.zip');
    final output = OutputFileStream(completed);
    try {
      final encoder = ZipEncoder()..startEncode(output);
      for (final entry in {
        'project.anthem': document.path,
        ...assets,
      }.entries) {
        final input = InputFileStream(entry.value);
        try {
          encoder.add(ArchiveFile.stream(entry.key, input));
        } finally {
          await input.close();
        }
      }
      encoder.endEncode();
    } finally {
      await output.close();
    }
    // Publish only a complete archive; failure preserves any existing export.
    await File(completed).rename(archivePath);
  } finally {
    await staging.delete(recursive: true);
  }
}

/// Extracts a ZIP into a fresh temporary project root.
///
/// Requires one root-level .anthem document. Paths must be portable and unique;
/// links and paths outside the root are rejected. On success the caller owns the
/// directory and must adopt it into temporary project storage or delete it if
/// loading fails. Extraction failures remove the directory automatically.
Future<({String rootDirectory, String documentPath})> extractProjectArchive(
  String archivePath,
) => Isolate.run(() => _extractArchive(archivePath));

Future<({String rootDirectory, String documentPath})> _extractArchive(
  String archivePath,
) async {
  final InputFileStream input;
  try {
    input = InputFileStream(archivePath);
  } on FileSystemException catch (error, stack) {
    throw ProjectFileReadException(cause: error, causeStackTrace: stack);
  }
  Directory? directory;
  try {
    final paths = <String>{};
    final spellings = <String, String>{};
    final archive = ZipDecoder().decodeStream(
      input,
      callback: (entry) {
        final name = entry.isDirectory && entry.name.endsWith('/')
            ? entry.name.substring(0, entry.name.length - 1)
            : entry.name;
        final parts = name.split('/');
        if (entry.isSymbolicLink ||
            entry.mode & 0xf000 == 0xa000 ||
            parts.any((part) => !_isPortableName(part)) ||
            !paths.add(name.toLowerCase())) {
          throw const FormatException('Invalid or duplicate archive path.');
        }
        // Check implicit parent folders too, so casing is unambiguous on all OSes.
        for (var i = 1; i <= parts.length; i++) {
          final prefix = parts.take(i).join('/');
          final previous = spellings.putIfAbsent(
            prefix.toLowerCase(),
            () => prefix,
          );
          if (previous != prefix) {
            throw const FormatException('Archive paths differ only by case.');
          }
        }
      },
    );
    final documents = archive.files.where(
      (entry) =>
          entry.isFile &&
          !entry.name.contains('/') &&
          entry.name.toLowerCase().endsWith('.anthem'),
    );
    if (documents.length != 1) {
      throw const FormatException(
        'Expected one project document at the ZIP root.',
      );
    }
    directory = await Directory.systemTemp.createTemp('anthem_project_import_');
    for (final entry in archive) {
      final destination = path.joinAll([
        directory.path,
        ...entry.name.split('/'),
      ]);
      if (entry.isDirectory) {
        await Directory(destination).create(recursive: true);
        continue;
      }
      final file = File(destination);
      await file.parent.create(recursive: true);
      await file.create(exclusive: true);
      final output = OutputFileStream(destination);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      // The decoder's verify option does not check CRCs in archive 4.x.
      var crc = 0;
      var length = 0;
      await for (final chunk in file.openRead()) {
        crc = getCrc32(chunk, crc);
        length += chunk.length;
      }
      if (length != entry.size || crc != entry.crc32) {
        throw const FormatException('Damaged file in project archive.');
      }
    }
    return (
      rootDirectory: directory.path,
      documentPath: path.join(directory.path, documents.single.name),
    );
  } catch (error, stack) {
    if (directory != null) await directory.delete(recursive: true);
    throw InvalidProjectFileException(cause: error, causeStackTrace: stack);
  } finally {
    await input.close();
  }
}

bool _isPortableName(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    !name.endsWith('.') &&
    !name.endsWith(' ') &&
    !RegExp(r'[\\/:*?"<>|\x00-\x1f]').hasMatch(name) &&
    !RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(name);
