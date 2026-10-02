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

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import '../../helpers/file_dialog_test_helpers.dart';

ProjectFileVersion _version(String value) {
  return ProjectFileVersion.parse(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cancelling project selection does not show a load error', () async {
    final originalSelector = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = FakeFileSelector();
    addTearDown(() => FileSelectorPlatform.instance = originalSelector);
    final recordingDialog = RecordingDialog();
    final dialogs = DialogController()..initialize(recordingDialog);

    expect(
      await MainWindowController().loadProject(dialogController: dialogs),
      isNull,
    );
    expect(recordingDialog.shownCount, 0);
  });

  test(
    'an unreadable selected project shows an error without opening a project',
    () async {
      final originalSelector = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = FakeFileSelector()
        ..selectedFile = XFile.fromData(
          Uint8List.fromList([12, 34]),
          name: 'invalid.anthem',
        );
      addTearDown(() => FileSelectorPlatform.instance = originalSelector);
      final recordingDialog = RecordingDialog();
      final dialogs = DialogController()..initialize(recordingDialog);
      final projectCount = AnthemStore.instance.projects.length;

      expect(
        await MainWindowController().loadProject(dialogController: dialogs),
        isNull,
      );
      expect(recordingDialog.shownCount, 1);
      expect(AnthemStore.instance.projects, hasLength(projectCount));
    },
  );

  group('projectFileLoadErrorMarkdown', () {
    test('explains that a project was saved by a newer Anthem version', () {
      final message = projectFileLoadErrorMarkdown(
        ProjectSavedInNewerVersionException(
          savedVersion: _version('0.0.0-prealpha.3'),
          currentVersion: _version('0.0.0-prealpha.2'),
        ),
      );

      expect(message, contains('saved in a newer version of Anthem'));
      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.3')));
      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.2')));
      expect(message, contains('Update Anthem'));
    });

    test('reports the supported range for an old project', () {
      final message = projectFileLoadErrorMarkdown(
        ProjectVersionTooOldException(
          savedVersion: _version('0.0.0-prealpha.0'),
          oldestSupportedVersion: _version('0.0.0-prealpha.1'),
        ),
      );

      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.0')));
      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.1')));
      expect(message, contains('oldest project version supported'));
    });

    test('reports migration boundaries without exposing the cause', () {
      final message = projectFileLoadErrorMarkdown(
        ProjectFileMigrationException(
          fromVersion: _version('0.0.0-prealpha.1'),
          targetVersion: _version('0.0.0-prealpha.2'),
          cause: StateError('private implementation detail'),
        ),
      );

      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.1')));
      expect(message, contains(escapeDialogMarkdown('0.0.0-prealpha.2')));
      expect(message, contains('original project file was not changed'));
      expect(message, isNot(contains('private implementation detail')));
    });

    test('explains the known multiple-arrangement migration failure', () {
      final message = projectFileLoadErrorMarkdown(
        ProjectFileMigrationException(
          fromVersion: _version('0.0.0-prealpha.1'),
          targetVersion: _version('0.0.0-prealpha.2'),
          cause: const MultipleArrangementsProjectFileException(
            arrangementCount: 3,
          ),
        ),
      );

      expect(message, contains('contains 3 arrangements'));
      expect(message, contains('only open projects containing one'));
      expect(message, contains('original project file was not changed'));
      expect(message, isNot(contains('report this problem')));
    });

    test('does not expose causes for invalid or unexpected errors', () {
      for (final error in <Object>[
        InvalidProjectFileException(
          cause: const FormatException('private parser detail'),
        ),
        StateError('private implementation detail'),
      ]) {
        final message = projectFileLoadErrorMarkdown(error);

        expect(message, isNot(contains('private')));
        expect(message, contains('original'));
      }
    });
  });
}
