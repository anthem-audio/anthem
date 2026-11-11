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

import 'package:uuid/uuid.dart';

import 'browser_file_system.dart';
import 'file_fingerprint.dart';

String absolutePath(String file) => BrowserFileSystem.absolutePath(file);

String temporaryProjectDirectoryPath() =>
    '${BrowserFileSystem.root}/projects/anthem_project_${const Uuid().v4()}';

Future<void> createDirectory(String directory) async {
  final files = await BrowserFileSystem.instance;
  files.fs.callMethod<JSAny?>('mkdirTree'.toJS, absolutePath(directory).toJS);
}

Future<String> resolveDirectory(String directory) async {
  final files = await BrowserFileSystem.instance;
  final options = JSObject()..setProperty('follow'.toJS, true.toJS);
  return files.fs
      .callMethod<JSObject>(
        'lookupPath'.toJS,
        absolutePath(directory).toJS,
        options,
      )
      .getProperty<JSString>('path'.toJS)
      .toDart;
}

Future<List<({String name, bool isFile, bool isDirectory})>> listEntries(
  String directory,
) async {
  final files = await BrowserFileSystem.instance;
  final names = files.fs
      .callMethod<JSArray<JSString>>(
        'readdir'.toJS,
        absolutePath(directory).toJS,
      )
      .toDart;
  return [
    for (final name in names.map((name) => name.toDart))
      if (name != '.' && name != '..')
        _entry(files.fs, absolutePath(directory), name),
  ];
}

({String name, bool isFile, bool isDirectory}) _entry(
  JSObject fs,
  String directory,
  String name,
) {
  final info = fs.callMethod<JSObject>(
    'lstat'.toJS,
    BrowserFileSystem.paths.join(directory, name).toJS,
  );
  final mode = info.getProperty<JSNumber>('mode'.toJS);
  return (
    name: name,
    isFile: fs.callMethod<JSBoolean>('isFile'.toJS, mode).toDart,
    isDirectory: fs.callMethod<JSBoolean>('isDir'.toJS, mode).toDart,
  );
}

Future<void> createFile(String file) async {
  final fs = (await BrowserFileSystem.instance).fs;
  // Emscripten's string modes do not support exclusive creation.
  const flags = 1 | 64 | 128; // O_WRONLY | O_CREAT | O_EXCL
  final stream = fs.callMethod<JSObject>(
    'open'.toJS,
    absolutePath(file).toJS,
    flags.toJS,
  );
  fs.callMethod<JSAny?>('close'.toJS, stream);
}

Future<bool> entryExists(String file) async {
  final absolute = absolutePath(file);
  final existing = BrowserFileSystem.existingInstance;
  if (existing == null) return false;
  final fs = (await existing).fs;
  return fs
      .callMethod<JSObject>('analyzePath'.toJS, absolute.toJS)
      .getProperty<JSBoolean>('exists'.toJS)
      .toDart;
}

Future<void> renameFile(String source, String destination) async {
  final fs = (await BrowserFileSystem.instance).fs;
  fs.callMethod<JSAny?>(
    'rename'.toJS,
    absolutePath(source).toJS,
    absolutePath(destination).toJS,
  );
}

Future<void> deleteFile(String file) async {
  final fs = (await BrowserFileSystem.instance).fs;
  fs.callMethod<JSAny?>('unlink'.toJS, absolutePath(file).toJS);
}

Future<void> deleteDirectory(String directory) async {
  if (!await entryExists(directory)) return;
  for (final entry in await listEntries(directory)) {
    final file = BrowserFileSystem.paths.join(directory, entry.name);
    if (entry.isDirectory) {
      await deleteDirectory(file);
    } else {
      await deleteFile(file);
    }
  }
  final fs = (await BrowserFileSystem.instance).fs;
  fs.callMethod<JSAny?>('rmdir'.toJS, absolutePath(directory).toJS);
}

Future<int> fileLength(String file) async {
  final fs = (await BrowserFileSystem.instance).fs;
  return fs
      .callMethod<JSObject>('stat'.toJS, absolutePath(file).toJS)
      .getProperty<JSNumber>('size'.toJS)
      .toDartInt;
}

Future<Uint8List> readFile(String file) async =>
    (await BrowserFileSystem.instance).readFile(file);

Future<void> writeFile(String file, List<int> bytes) async =>
    (await BrowserFileSystem.instance).writeFile(file, bytes);

Future<FileFingerprint> readFingerprint(String file) async =>
    FileFingerprint.fromBytes(await readFile(file));
