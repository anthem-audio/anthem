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

import 'package:anthem/logic/project_file/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectFileVersion', () {
    test('parses all version components', () {
      final version = ProjectFileVersion.parse('12.34.56-prealpha.7');

      expect(version.major, 12);
      expect(version.minor, 34);
      expect(version.bugfix, 56);
      expect(version.extra, 'prealpha.7');
      expect(version.toString(), '12.34.56-prealpha.7');
    });

    test('parses a version without extra information', () {
      final version = ProjectFileVersion.parse('1.2.3');

      expect(version.extra, isNull);
      expect(version.toString(), '1.2.3');
    });

    test('rejects malformed versions', () {
      for (final version in [
        '',
        '1',
        '1.2',
        '1.2.3.4',
        '1.2.3-',
        'v1.2.3',
        '1.-2.3',
      ]) {
        expect(
          () => ProjectFileVersion.parse(version),
          throwsA(isA<FormatException>()),
          reason: version,
        );
      }
    });

    test('compares numeric components in order', () {
      expect(
        ProjectFileVersion.parse('2.0.0'),
        greaterThan(ProjectFileVersion.parse('1.99.99')),
      );
      expect(
        ProjectFileVersion.parse('1.2.0'),
        greaterThan(ProjectFileVersion.parse('1.1.99')),
      );
      expect(
        ProjectFileVersion.parse('1.2.4'),
        greaterThan(ProjectFileVersion.parse('1.2.3')),
      );
    });

    test('compares numbers within extra information numerically', () {
      expect(
        ProjectFileVersion.parse('1.2.3-prealpha.10'),
        greaterThan(ProjectFileVersion.parse('1.2.3-prealpha.2')),
      );
      expect(
        ProjectFileVersion.parse('1.2.3-preview20a'),
        greaterThan(ProjectFileVersion.parse('1.2.3-preview3a')),
      );
    });

    test('falls back to string comparison for extra tags', () {
      expect(
        ProjectFileVersion.parse('1.2.3-beta.1'),
        greaterThan(ProjectFileVersion.parse('1.2.3-alpha.10')),
      );
      expect(
        ProjectFileVersion.parse('1.2.3-preview'),
        greaterThan(ProjectFileVersion.parse('1.2.3-alpha')),
      );
    });

    test('sorts a version without extra information after one with it', () {
      expect(
        ProjectFileVersion.parse('1.2.3'),
        greaterThan(ProjectFileVersion.parse('1.2.3-prealpha.99')),
      );
    });

    test('provides a string sorting helper', () {
      final versions = [
        '1.0.0-prealpha.10',
        '1.0.0-prealpha.2',
        '0.9.9',
        '1.0.0-prealpha.1',
      ]..sort(compareProjectFileVersionStrings);

      expect(versions, [
        '0.9.9',
        '1.0.0-prealpha.1',
        '1.0.0-prealpha.2',
        '1.0.0-prealpha.10',
      ]);
    });
  });
}
