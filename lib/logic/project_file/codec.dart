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

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/format.dart';
import 'package:anthem/logic/project_file/gzip.dart';
import 'package:anthem/logic/project_file/io.dart';
import 'package:anthem/model/project.dart';

/// Encodes a project as an Anthem project file.
///
/// The file container is a small Anthem-specific header followed by a gzip
/// frame containing the UTF-8 JSON project model.
Future<Uint8List> encodeProjectFile(ProjectModel project) async {
  final output = BytesBuilder(copy: false)..add(projectFileHeader);
  final json = Uint8List.fromList(JsonUtf8Encoder().convert(project.toJson()));
  final compressedJson = await compressGzip(json);

  output.add(compressedJson);
  return output.takeBytes();
}

/// Decodes the stored JSON without migrating it.
///
/// The loading workflow reads the saved software version before applying
/// migrations and constructing the project model.
Future<Map<String, dynamic>> decodeProjectFileBytes(List<int> bytes) async {
  try {
    final decompressedJson = await decompressGzip(getProjectFilePayload(bytes));
    return decodeProjectJson(decompressedJson);
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      InvalidProjectFileException(cause: error, causeStackTrace: stackTrace),
      stackTrace,
    );
  }
}

/// Writes a project to an Anthem project file.
Future<void> writeProjectFile(String path, ProjectModel project) async {
  await writeProjectFileToPath(path, project.toJson());
}

/// Reads the stored JSON without migrating it.
///
/// The loading workflow reads the saved software version before applying
/// migrations and constructing the project model.
Future<Map<String, dynamic>> readProjectFile(String path) async {
  try {
    return await readProjectFileFromPath(path);
  } on ProjectFileReadException {
    rethrow;
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      InvalidProjectFileException(cause: error, causeStackTrace: stackTrace),
      stackTrace,
    );
  }
}
