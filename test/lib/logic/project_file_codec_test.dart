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

import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('project file codec', () {
    test('encodes and decodes a project', () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);

      final projectJson = project.toJson();
      final bytes = await encodeProjectFile(project);
      final decodedJson = await decodeProjectFileBytes(bytes);

      expect(bytes.first, isNot(equals('{'.codeUnitAt(0))));
      expect(
        decodedJson['savedInSoftwareVersion'],
        currentProjectFileSoftwareVersion,
      );
      expect(decodedJson, equals(projectJson));
    });

    test('writes and reads a project file', () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);

      final tempDir = await Directory.systemTemp.createTemp(
        'anthem_project_file_codec_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final path = '${tempDir.path}${Platform.pathSeparator}project.anthem';

      await writeProjectFile(path, project);

      final fileBytes = await File(path).readAsBytes();
      expect(fileBytes.first, isNot(equals('{'.codeUnitAt(0))));
      expect(await readProjectFile(path), equals(project.toJson()));
    });

    test('rejects files without an Anthem project file header', () async {
      final bytes = utf8.encode('{"id":"not-compressed"}');

      await expectLater(
        decodeProjectFileBytes(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
