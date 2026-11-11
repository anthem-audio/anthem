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

import 'package:file_selector/file_selector.dart' show XFile;

import 'project_save.dart';
import 'archive_extraction.dart';
import 'archive_format.dart';

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
  XFile archive,
) {
  final archivePath = archive.path;
  return Isolate.run(() => _extractArchive(archivePath));
}

Future<({String rootDirectory, String documentPath})> _extractArchive(
  String archivePath,
) async {
  final InputFileStream input;
  try {
    input = InputFileStream(archivePath);
  } on FileSystemException catch (error, stack) {
    throw ProjectFileReadException(cause: error, causeStackTrace: stack);
  }
  return _extractStream(input);
}

/// Extracts an archive that is already in memory, using the same workflow as
/// path imports. Selected files should use [extractProjectArchive] instead.
Future<({String rootDirectory, String documentPath})>
extractProjectArchiveBytes(List<int> bytes) =>
    Isolate.run(() => _extractStream(InputMemoryStream(bytes)));

Future<({String rootDirectory, String documentPath})> _extractStream(
  InputStream input,
) async {
  final destination = _FileDestination();
  final document = await extractProjectArchiveContents(
    _FileSource(input),
    destination,
  );
  return (
    rootDirectory: destination.directory!.path,
    documentPath: path.join(destination.directory!.path, document),
  );
}

class _FileSource implements ProjectArchiveSource {
  final InputStream _input;
  final _entries = <ArchiveFile>[];

  _FileSource(this._input);

  @override
  Future<List<ProjectArchiveEntry>> readEntries() async {
    // Collect in the callback: ZipDecoder merges duplicate filenames in its
    // returned Archive, but project validation must see every original entry.
    ZipDecoder().decodeStream(_input, callback: _entries.add);
    return [
      for (final entry in _entries)
        (
          name: entry.name,
          isDirectory: entry.isDirectory,
          isSymbolicLink: entry.isSymbolicLink || entry.mode & 0xf000 == 0xa000,
          length: entry.size,
          crc32: entry.crc32!,
        ),
    ];
  }

  @override
  Future<void> writeFile(int entryIndex, OutputStream output) async {
    final entry = _entries[entryIndex];
    try {
      entry.writeContent(output);
    } finally {
      entry.clear();
    }
  }

  @override
  Future<void> close() => _input.close();
}

class _FileDestination implements ProjectArchiveDestination {
  Directory? directory;
  File? _file;
  OutputFileStream? _output;

  String _path(String relative) =>
      path.joinAll([directory!.path, ...relative.split('/')]);

  @override
  Future<void> create() async {
    directory = await Directory.systemTemp.createTemp('anthem_project_import_');
  }

  @override
  Future<void> createDirectory(String relativePath) async {
    await Directory(_path(relativePath)).create(recursive: true);
  }

  @override
  Future<OutputStream> createFile(String relativePath) async {
    final file = _file = File(_path(relativePath));
    await file.parent.create(recursive: true);
    await file.create(exclusive: true);
    return _output = OutputFileStream(file.path);
  }

  @override
  Future<ArchiveFileIntegrity> finishFile() async {
    await _output!.close();
    _output = null;
    var crc32 = 0;
    var length = 0;
    await for (final chunk in _file!.openRead()) {
      crc32 = getCrc32(chunk, crc32);
      length += chunk.length;
    }
    return (length: length, crc32: crc32);
  }

  @override
  Future<void> discard() async {
    try {
      await _output?.close();
    } finally {
      _output = null;
      await directory?.delete(recursive: true);
    }
  }
}
