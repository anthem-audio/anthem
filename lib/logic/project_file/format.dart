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

import 'dart:convert';
import 'dart:typed_data';

const projectFileHeader = <int>[
  0x41, // A
  0x4e, // N
  0x54, // T
  0x48, // H
  0x45, // E
  0x4d, // M
  0x5f, // _
  0x50, // P
  0x52, // R
  0x4a, // J
  0x00,
  0x01, // Project file container version.
  0x01, // Gzip-compressed JSON payload.
];

Uint8List getProjectFilePayload(List<int> bytes) {
  validateProjectFileHeader(bytes);

  return bytes is Uint8List
      ? Uint8List.sublistView(bytes, projectFileHeader.length)
      : Uint8List.fromList(bytes.sublist(projectFileHeader.length));
}

Map<String, dynamic> decodeProjectJson(List<int> bytes) {
  return expectProjectJsonObject(jsonDecode(utf8.decode(bytes)));
}

Map<String, dynamic> expectProjectJsonObject(Object? decoded) {
  if (decoded case final Map<String, dynamic> json) {
    return json;
  }

  throw FormatException(
    'Expected Anthem project file to contain a JSON object, got '
    '${decoded.runtimeType}.',
  );
}

void validateProjectFileHeader(List<int> bytes) {
  if (bytes.length < projectFileHeader.length) {
    throw const FormatException('Invalid Anthem project file header.');
  }

  for (var i = 0; i < projectFileHeader.length; i++) {
    if (bytes[i] != projectFileHeader[i]) {
      throw const FormatException('Invalid Anthem project file header.');
    }
  }
}
