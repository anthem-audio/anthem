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

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectFileVersion _version(String value) {
  return ProjectFileVersion.parse(value);
}

void main() {
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
