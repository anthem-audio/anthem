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

Never _unsupported() => throw UnsupportedError(
  'Project file storage requires a desktop filesystem.',
);

Future<void> createDirectory(String directory) async => _unsupported();
Future<String> resolveDirectory(String directory) async => _unsupported();
String temporaryProjectDirectoryPath() => _unsupported();
Future<List<({String name, bool isFile, bool isDirectory})>> listEntries(
  String directory,
) async => _unsupported();
Future<void> createFile(String file) async => _unsupported();
Future<bool> entryExists(String file) async => _unsupported();
Future<void> renameFile(String source, String destination) async =>
    _unsupported();
Future<void> deleteFile(String file) async => _unsupported();
Future<void> deleteDirectory(String directory) async => _unsupported();
