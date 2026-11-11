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

/// Entry metadata supplied by each platform's ZIP decoder. Its position in
/// the source's entry list identifies the contents to extract.
typedef ProjectArchiveEntry = ({
  String name,
  bool isDirectory,
  bool isSymbolicLink,
  int length,
  int crc32,
});

/// Checks the project ZIP layout before creating any files, and returns the
/// root document's name. Length and CRC checks follow extraction of each file.
String validateProjectArchive(List<ProjectArchiveEntry> entries) {
  final paths = <String>{};
  final spellings = <String, String>{};
  for (final entry in entries) {
    final name = entry.isDirectory && entry.name.endsWith('/')
        ? entry.name.substring(0, entry.name.length - 1)
        : entry.name;
    final parts = name.split('/');
    if (entry.isSymbolicLink ||
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
  }
  final documents = entries.where(
    (entry) =>
        !entry.isDirectory &&
        !entry.name.contains('/') &&
        entry.name.toLowerCase().endsWith('.anthem'),
  );
  if (documents.length != 1) {
    throw const FormatException(
      'Expected one project document at the ZIP root.',
    );
  }
  return documents.single.name;
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
