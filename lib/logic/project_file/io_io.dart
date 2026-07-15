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
import 'dart:io';

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/format.dart';
import 'package:anthem/model/project.dart';

Future<void> writeProjectFileToPath(String path, ProjectModel project) async {
  final output = File(path).openWrite()..add(projectFileHeader);

  try {
    final gzipSink = gzip.encoder.startChunkedConversion(output);
    final jsonSink = JsonUtf8Encoder().startChunkedConversion(gzipSink);

    jsonSink.add(project.toJson());
    jsonSink.close();

    await output.done;
  } catch (_) {
    await output.close();
    rethrow;
  }
}

Future<Map<String, dynamic>> readProjectFileFromPath(String path) async {
  try {
    final file = File(path);
    final header = await file
        .openRead(0, projectFileHeader.length)
        .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));

    validateProjectFileHeader(header);

    final decoded = await file
        .openRead(projectFileHeader.length)
        .transform(gzip.decoder)
        .transform(utf8.decoder)
        .transform(json.decoder)
        .single;

    return expectProjectJsonObject(decoded);
  } on FileSystemException catch (error, stackTrace) {
    Error.throwWithStackTrace(
      ProjectFileReadException(cause: error, causeStackTrace: stackTrace),
      stackTrace,
    );
  }
}
