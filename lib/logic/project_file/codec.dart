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
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
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

/// Decodes an Anthem project file from bytes.
Future<Map<String, dynamic>> decodeProjectFileBytes(List<int> bytes) async {
  final Map<String, dynamic> projectJson;

  try {
    final decompressedJson = await decompressGzip(getProjectFilePayload(bytes));
    projectJson = decodeProjectJson(decompressedJson);
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      InvalidProjectFileException(cause: error, causeStackTrace: stackTrace),
      stackTrace,
    );
  }

  return migrateProjectJson(projectJson);
}

/// Writes a project to an Anthem project file.
Future<void> writeProjectFile(String path, ProjectModel project) async {
  await writeProjectFileToPath(path, project);
}

/// Reads an Anthem project file.
Future<Map<String, dynamic>> readProjectFile(String path) async {
  final Map<String, dynamic> projectJson;

  try {
    projectJson = await readProjectFileFromPath(path);
  } on ProjectFileReadException {
    rethrow;
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      InvalidProjectFileException(cause: error, causeStackTrace: stackTrace),
      stackTrace,
    );
  }

  return migrateProjectJson(projectJson);
}
