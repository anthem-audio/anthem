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

import 'dart:typed_data';

import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:archive/archive.dart';

import 'codec.dart';
import 'project_save.dart';

/// Encodes a captured document and its referenced assets for download.
/// The caller keeps [prepared] open until encoding finishes. Only files in its
/// asset snapshot are included; history-only files and caches are excluded.
/// Native path exports use the streaming writer instead of buffering a ZIP.
Future<Uint8List> encodeProjectArchive(PreparedProjectSave prepared) async {
  final output = OutputMemoryStream();
  final encoder = ZipEncoder()..startEncode(output);
  encoder.add(
    ArchiveFile.bytes(
      'project.anthem',
      await encodeProjectJson(prepared.projectJson),
    ),
  );
  for (final entry in prepared.assets.reads.entries) {
    encoder.add(
      ArchiveFile.bytes(
        entry.key,
        await files.readFile(entry.value.absolutePath),
      ),
    );
  }
  encoder.endEncode();
  return output.getBytes();
}
