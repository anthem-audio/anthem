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

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

Future<void> createDirectory(String directory) async {
  await Directory(directory).create(recursive: true);
}

Future<String> resolveDirectory(String directory) =>
    Directory(directory).resolveSymbolicLinks();

String temporaryProjectDirectoryPath() =>
    path.join(Directory.systemTemp.path, 'anthem_project_${const Uuid().v4()}');

Future<List<({String name, bool isFile, bool isDirectory})>> listEntries(
  String directory,
) async {
  return [
    await for (final entry in Directory(directory).list(followLinks: false))
      (
        name: path.basename(entry.path),
        isFile: entry is File,
        isDirectory: entry is Directory,
      ),
  ];
}

Future<void> createFile(String file) async {
  await File(file).create(exclusive: true);
}

Future<bool> entryExists(String file) async {
  return await FileSystemEntity.type(file, followLinks: false) !=
      FileSystemEntityType.notFound;
}

Future<void> renameFile(String source, String destination) async {
  await File(source).rename(destination);
}

Future<void> deleteFile(String file) async {
  await File(file).delete();
}

Future<void> deleteDirectory(String directory) async {
  if (await Directory(directory).exists()) {
    await Directory(directory).delete(recursive: true);
  }
}
