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

@TestOn('browser')
library;

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/file_dialog_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final original = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    ServiceRegistry.setSessionPreferences(SharedPreferencesAsync());
    addTearDown(() {
      ServiceRegistry.setSessionPreferences(null);
      SharedPreferencesAsyncPlatform.instance = original;
    });
  });

  test('browser document encoding uses the current software version', () async {
    final project = ProjectModel.create();
    addTearDown(project.dispose);
    final decoded = await decodeProjectFileBytes(
      await encodeProjectFile(project),
    );
    expect(
      decoded['savedInSoftwareVersion'],
      currentProjectFileSoftwareVersion,
    );
    expect(decoded, project.toJson());
  });

  test(
    'opening a folder document on web explains that desktop is required',
    () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final originalSelector = FileSelectorPlatform.instance;
      final selector = FakeFileSelector()
        ..selectedFile = XFile.fromData(
          await encodeProjectFile(project),
          name: 'Song.anthem',
        );
      FileSelectorPlatform.instance = selector;
      addTearDown(() => FileSelectorPlatform.instance = originalSelector);
      final recording = RecordingDialog();
      final dialogs = DialogController()..initialize(recording);
      expect(
        await MainWindowController().loadProject(dialogController: dialogs),
        isNull,
      );
      expect(recording.shownCount, 1);
      expect(
        projectFileLoadErrorMarkdown(
          const ProjectDirectoryRequiresDesktopException(),
        ),
        contains('desktop version'),
      );
    },
  );
}
