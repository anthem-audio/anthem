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

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
import 'package:anthem/logic/project_file/migrations/migration.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:flutter_test/flutter_test.dart';

const _savedVersionKey = 'savedInSoftwareVersion';

ProjectFileVersion _version(String value) {
  return ProjectFileVersion.parse(value);
}

void main() {
  group('migrateProjectJson', () {
    test('short-circuits a project saved in the current version', () {
      var migrationWasCalled = false;
      final projectJson = <String, dynamic>{
        _savedVersionKey: currentProjectFileSoftwareVersion,
      };

      final result = migrateProjectJson(
        projectJson,
        migrations: [
          ProjectFileMigration(
            // This would fail registry validation if the registry were read.
            targetVersion: _version('0.0.0-prealpha.3'),
            migrate: (_) => migrationWasCalled = true,
          ),
        ],
      );

      expect(result, same(projectJson));
      expect(migrationWasCalled, isFalse);
    });

    test('retags a compatible old project when no migration is needed', () {
      final projectJson = <String, dynamic>{
        _savedVersionKey: '0.0.0-prealpha.1',
      };

      final result = migrateProjectJson(projectJson, migrations: const []);

      expect(result, same(projectJson));
      expect(result[_savedVersionKey], currentProjectFileSoftwareVersion);
    });

    test('applies every later migration in registry order', () {
      final versionsSeenByMigrations = <String>[];
      final projectJson = <String, dynamic>{
        _savedVersionKey: '0.0.0-prealpha.1',
        'migrationSteps': <int>[],
      };
      final migrations = [
        ProjectFileMigration(
          targetVersion: _version('0.0.0-prealpha.2'),
          migrate: (json) {
            versionsSeenByMigrations.add(json[_savedVersionKey] as String);
            (json['migrationSteps'] as List<int>).add(2);
          },
        ),
        ProjectFileMigration(
          targetVersion: _version('0.0.0-prealpha.3'),
          migrate: (json) {
            versionsSeenByMigrations.add(json[_savedVersionKey] as String);
            (json['migrationSteps'] as List<int>).add(3);
          },
        ),
        ProjectFileMigration(
          targetVersion: _version('0.0.0-prealpha.4'),
          migrate: (json) {
            versionsSeenByMigrations.add(json[_savedVersionKey] as String);
            (json['migrationSteps'] as List<int>).add(4);
          },
        ),
      ];

      migrateProjectJson(
        projectJson,
        migrations: migrations,
        currentVersion: _version('0.0.0-prealpha.4'),
      );

      expect(versionsSeenByMigrations, [
        '0.0.0-prealpha.1',
        '0.0.0-prealpha.2',
        '0.0.0-prealpha.3',
      ]);
      expect(projectJson['migrationSteps'], [2, 3, 4]);
      expect(projectJson[_savedVersionKey], '0.0.0-prealpha.4');
    });

    test('skips a migration matching the saved version', () {
      final appliedVersions = <String>[];
      final migrations = [
        for (final value in [
          '0.0.0-prealpha.2',
          '0.0.0-prealpha.3',
          '0.0.0-prealpha.4',
        ])
          ProjectFileMigration(
            targetVersion: _version(value),
            migrate: (_) => appliedVersions.add(value),
          ),
      ];

      migrateProjectJson(
        <String, dynamic>{_savedVersionKey: '0.0.0-prealpha.2'},
        migrations: migrations,
        currentVersion: _version('0.0.0-prealpha.4'),
      );

      expect(appliedVersions, ['0.0.0-prealpha.3', '0.0.0-prealpha.4']);
    });

    test('uses numeric extra ordering to select migrations', () {
      final appliedVersions = <String>[];
      final migrations = [
        for (final value in ['0.0.0-prealpha.2', '0.0.0-prealpha.10'])
          ProjectFileMigration(
            targetVersion: _version(value),
            migrate: (_) => appliedVersions.add(value),
          ),
      ];

      migrateProjectJson(
        <String, dynamic>{_savedVersionKey: '0.0.0-prealpha.2'},
        migrations: migrations,
        currentVersion: _version('0.0.0-prealpha.10'),
      );

      expect(appliedVersions, ['0.0.0-prealpha.10']);
    });

    test('rejects missing, non-string, and malformed versions', () {
      for (final projectJson in <Map<String, dynamic>>[
        {},
        {_savedVersionKey: 1},
        {_savedVersionKey: 'not-a-version'},
      ]) {
        expect(
          () => migrateProjectJson(projectJson),
          throwsA(isA<InvalidProjectFileException>()),
        );
      }
    });

    test('rejects versions outside the supported range', () {
      expect(
        () => migrateProjectJson(<String, dynamic>{
          _savedVersionKey: '0.0.0-prealpha.0',
        }),
        throwsA(
          isA<ProjectVersionTooOldException>()
              .having(
                (error) => error.savedVersion.toString(),
                'savedVersion',
                '0.0.0-prealpha.0',
              )
              .having(
                (error) => error.oldestSupportedVersion.toString(),
                'oldestSupportedVersion',
                '0.0.0-prealpha.1',
              ),
        ),
      );
      expect(
        () => migrateProjectJson(<String, dynamic>{
          _savedVersionKey: '0.0.0-prealpha.3',
        }),
        throwsA(
          isA<ProjectSavedInNewerVersionException>()
              .having(
                (error) => error.savedVersion.toString(),
                'savedVersion',
                '0.0.0-prealpha.3',
              )
              .having(
                (error) => error.currentVersion.toString(),
                'currentVersion',
                currentProjectFileSoftwareVersion,
              ),
        ),
      );
    });

    test('wraps migration errors with source and target versions', () {
      final cause = StateError('migration failed');
      final projectJson = <String, dynamic>{
        _savedVersionKey: '0.0.0-prealpha.1',
      };

      expect(
        () => migrateProjectJson(
          projectJson,
          migrations: [
            ProjectFileMigration(
              targetVersion: _version('0.0.0-prealpha.2'),
              migrate: (_) {},
            ),
            ProjectFileMigration(
              targetVersion: _version('0.0.0-prealpha.3'),
              migrate: (_) => throw cause,
            ),
          ],
          currentVersion: _version('0.0.0-prealpha.3'),
        ),
        throwsA(
          isA<ProjectFileMigrationException>()
              .having(
                (error) => error.fromVersion.toString(),
                'fromVersion',
                '0.0.0-prealpha.2',
              )
              .having(
                (error) => error.targetVersion.toString(),
                'targetVersion',
                '0.0.0-prealpha.3',
              )
              .having((error) => error.cause, 'cause', same(cause)),
        ),
      );
      expect(projectJson[_savedVersionKey], '0.0.0-prealpha.2');
    });

    test('rejects unordered and duplicate migrations', () {
      void noOp(Map<String, dynamic> _) {}

      for (final migrations in [
        [
          ProjectFileMigration(
            targetVersion: _version('0.0.0-prealpha.3'),
            migrate: noOp,
          ),
          ProjectFileMigration(
            targetVersion: _version('0.0.0-prealpha.2'),
            migrate: noOp,
          ),
        ],
        [
          ProjectFileMigration(
            targetVersion: _version('0.0.0-prealpha.2'),
            migrate: noOp,
          ),
          ProjectFileMigration(
            targetVersion: _version('0.0.0-prealpha.2'),
            migrate: noOp,
          ),
        ],
      ]) {
        expect(
          () => migrateProjectJson(
            <String, dynamic>{_savedVersionKey: '0.0.0-prealpha.1'},
            migrations: migrations,
            currentVersion: _version('0.0.0-prealpha.3'),
          ),
          throwsStateError,
        );
      }
    });

    test('rejects migrations newer than the current version', () {
      expect(
        () => migrateProjectJson(
          <String, dynamic>{_savedVersionKey: '0.0.0-prealpha.1'},
          migrations: [
            ProjectFileMigration(
              targetVersion: _version('0.0.0-prealpha.3'),
              migrate: (_) {},
            ),
          ],
        ),
        throwsStateError,
      );
    });
  });
}
