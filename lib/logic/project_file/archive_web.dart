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

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:anthem/logic/storage/browser_file_system.dart';
import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;
import 'package:file_selector/file_selector.dart' show XFile;

import 'archive_extraction.dart';
import 'errors.dart';
import 'project_save.dart';
import 'web/archive_worker_client.dart';

Future<void> writeProjectArchive(
  String archivePath,
  PreparedProjectSave prepared,
) => throw const ProjectDirectoryRequiresDesktopException();

/// Extracts a selected file into browser working storage.
///
/// A JavaScript worker supplies ZIP entries and streams decompressed contents.
/// The shared Dart workflow validates the archive, writes to the UI-owned
/// filesystem, and removes partial files on failure. The caller adopts the
/// returned directory or removes it if document loading fails.
Future<({String rootDirectory, String documentPath})> extractProjectArchive(
  XFile archive,
) async {
  final int length;
  try {
    length = await archive.length();
  } catch (error, stack) {
    throw ProjectFileReadException(cause: error, causeStackTrace: stack);
  }
  return _extractArchive(archive.path, length);
}

Future<({String rootDirectory, String documentPath})> _extractArchive(
  String archiveUrl,
  int length,
) async {
  final source = await ArchiveWorkerClient.open(archiveUrl, length);
  final destination = _BrowserFiles();
  final document = await extractProjectArchiveContents(source, destination);
  return (
    rootDirectory: destination.root!,
    documentPath: BrowserFileSystem.paths.join(destination.root!, document),
  );
}

/// Convenience for callers that already have bytes. File-picker imports use
/// [extractProjectArchive] directly and do not materialize the selected ZIP.
Future<({String rootDirectory, String documentPath})>
extractProjectArchiveBytes(List<int> bytes) async {
  final url = web.URL.createObjectURL(
    web.Blob([Uint8List.fromList(bytes).toJS].toJS),
  );
  try {
    return await _extractArchive(url, bytes.length);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

class _BrowserFiles implements ProjectArchiveDestination {
  String? root;
  _BrowserOutput? _output;

  String _path(String relative) =>
      BrowserFileSystem.paths.joinAll([root!, ...relative.split('/')]);

  @override
  Future<void> create() async {
    root = files.temporaryProjectDirectoryPath();
    await files.createDirectory(root!);
  }

  @override
  Future<void> createDirectory(String relativePath) =>
      files.createDirectory(_path(relativePath));

  @override
  Future<OutputStream> createFile(String relativePath) async {
    final file = _path(relativePath);
    await files.createDirectory(BrowserFileSystem.paths.dirname(file));
    final fs = (await BrowserFileSystem.instance).fs;
    const exclusiveWrite = 1 | 64 | 128; // O_WRONLY | O_CREAT | O_EXCL
    final stream = fs.callMethod<JSObject>(
      'open'.toJS,
      file.toJS,
      exclusiveWrite.toJS,
    );
    return _output = _BrowserOutput(fs, stream);
  }

  @override
  Future<ArchiveFileIntegrity> finishFile() async {
    final output = _output!;
    await output.close();
    _output = null;
    return (length: output.length, crc32: output.crc32);
  }

  @override
  Future<void> discard() async {
    try {
      await _output?.close();
    } finally {
      _output = null;
      final directory = root;
      if (directory != null) await files.deleteDirectory(directory);
    }
  }
}

/// Append-only output for the worker's decompressed chunks. Checking integrity
/// while writing avoids rereading a whole MEMFS file into another byte array.
class _BrowserOutput extends OutputStream {
  final JSObject _fs;
  final JSObject _stream;
  int crc32 = 0;
  @override
  int length = 0;
  @override
  bool isOpen = true;

  _BrowserOutput(this._fs, this._stream)
    : super(byteOrder: ByteOrder.littleEndian);

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final count = length ?? data.length;
    final written = _fs
        .callMethod<JSNumber>(
          'write'.toJS,
          _stream,
          data.toJS,
          0.toJS,
          count.toJS,
        )
        .toDartInt;
    if (written != count) throw StateError('Incomplete archive write.');
    crc32 = getCrc32(
      count == data.length ? data : Uint8List.sublistView(data, 0, count),
      crc32,
    );
    this.length += count;
  }

  @override
  void writeByte(int value) => writeBytes([value]);

  @override
  void writeStream(InputStream stream) =>
      throw UnsupportedError('Worker output accepts byte chunks.');

  @override
  Uint8List subset(int start, [int? end]) =>
      throw UnsupportedError('Worker output is append-only.');

  @override
  void clear() => throw UnsupportedError('Worker output is append-only.');

  @override
  void flush() {}

  @override
  Future<void> close() async => closeSync();

  @override
  void closeSync() {
    if (!isOpen) return;
    isOpen = false;
    _fs.callMethod<JSAny?>('close'.toJS, _stream);
  }
}
