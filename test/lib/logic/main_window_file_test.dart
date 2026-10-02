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

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../helpers/file_dialog_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFileSelector selector;
  late Directory directory;
  late ProjectModel project;
  late DialogController dialogs;
  late RecordingDialog recordingDialog;
  final controller = MainWindowController();

  setUp(() {
    final originalSelector = FileSelectorPlatform.instance;
    selector = FakeFileSelector();
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = originalSelector);

    directory = Directory.systemTemp.createTempSync('anthem_file_dialog_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    project = ProjectModel.create()..isDirty = true;
    AnthemStore.instance.projects[project.id] = project;
    ServiceRegistry.initializeProject(project);
    addTearDown(() {
      AnthemStore.instance.projects.remove(project.id);
      ServiceRegistry.removeProject(project.id);
      project.dispose();
    });
    recordingDialog = RecordingDialog();
    dialogs = DialogController()..initialize(recordingDialog);
  });

  test(
    'cancelled Save As preserves the project path and dirty state',
    () async {
      project.filePath = path.join(directory.path, 'previous.anthem');

      expect(
        await controller.saveProject(
          project.id,
          true,
          dialogController: dialogs,
        ),
        isFalse,
      );

      expect(project.filePath, path.join(directory.path, 'previous.anthem'));
      expect(project.isDirty, isTrue);
      expect(directory.listSync(), isEmpty);
      expect(recordingDialog.shownCount, 0);
    },
  );

  test(
    'Save As writes an Anthem file and ordinary Save reuses its path',
    () async {
      selector.saveLocation = FileSaveLocation(
        path.join(directory.path, 'song'),
      );
      expect(
        await controller.saveProject(
          project.id,
          true,
          dialogController: dialogs,
        ),
        isTrue,
      );

      final savedPath = path.join(directory.path, 'song.anthem');
      expect(project.filePath, savedPath);
      expect(project.isDirty, isFalse);
      expect((await readProjectFile(savedPath))['tracks'], isNotEmpty);

      final track = project.tracks[project.trackOrder.first]!;
      track.name = 'Updated track';
      project.isDirty = true;
      selector.saveLocation = null;
      expect(
        await controller.saveProject(
          project.id,
          false,
          dialogController: dialogs,
        ),
        isTrue,
      );

      final json = await readProjectFile(savedPath);
      expect(
        (json['tracks'] as Map)[track.id.toString()]['name'],
        'Updated track',
      );
      expect(selector.saveCount, 1);
      expect(project.isDirty, isFalse);
    },
  );

  test('Save As preserves an existing uppercase Anthem extension', () async {
    final savedPath = path.join(directory.path, 'song.ANTHEM');
    selector.saveLocation = FileSaveLocation(savedPath);

    expect(
      await controller.saveProject(project.id, true, dialogController: dialogs),
      isTrue,
    );
    expect(project.filePath, savedPath);
    expect(File(savedPath).existsSync(), isTrue);
    expect(File('$savedPath.anthem').existsSync(), isFalse);
  });

  test('a failed write preserves the previous path and dirty state', () async {
    final previousPath = path.join(directory.path, 'previous.anthem');
    project.filePath = previousPath;
    selector.saveLocation = FileSaveLocation(
      path.join(directory.path, 'missing-directory', 'song.anthem'),
    );

    await expectLater(
      controller.saveProject(project.id, true, dialogController: dialogs),
      throwsA(isA<FileSystemException>()),
    );
    expect(project.filePath, previousPath);
    expect(project.isDirty, isTrue);
  });

  test('cancelling log export does not write or show an error', () async {
    expect(await controller.exportLogs(dialogController: dialogs), isFalse);
    expect(directory.listSync(), isEmpty);
    expect(recordingDialog.shownCount, 0);
  });
}
