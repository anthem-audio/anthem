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
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _projectWithArrangements(
  Map<String, dynamic> arrangements, {
  Object? arrangementOrder = const <int>[],
}) {
  return <String, dynamic>{
    'savedInSoftwareVersion': '0.0.0-prealpha.1',
    'sequence': <String, dynamic>{
      'arrangements': arrangements,
      'arrangementOrder': arrangementOrder,
      'unrelatedSequenceField': 'preserved',
    },
    'unrelatedProjectField': 'preserved',
  };
}

void main() {
  group('prealpha.2 project-file migration', () {
    test('promotes the only arrangement and preserves its JSON', () {
      final arrangement = <String, dynamic>{
        'id': 42,
        'name': 'Arrangement 1',
        'clips': <String, dynamic>{
          '7': <String, dynamic>{'id': 7, 'unknownClipField': true},
        },
        'unknownArrangementField': <String, dynamic>{'nested': 'value'},
      };
      final projectJson = _projectWithArrangements(
        <String, dynamic>{'42': arrangement},
        // The map, rather than this obsolete display order, is authoritative.
        arrangementOrder: <int>[999, 42],
      );

      final result = migrateProjectJson(projectJson);
      final sequence = result['sequence'] as Map<String, dynamic>;

      expect(result, same(projectJson));
      expect(result['savedInSoftwareVersion'], '0.0.0-prealpha.2');
      expect(sequence['arrangement'], same(arrangement));
      expect(sequence, isNot(contains('arrangements')));
      expect(sequence, isNot(contains('arrangementOrder')));
      expect(sequence['unrelatedSequenceField'], 'preserved');
      expect(result['unrelatedProjectField'], 'preserved');
    });

    test('rejects multiple arrangements before mutating the project', () {
      final projectJson = _projectWithArrangements(
        <String, dynamic>{
          '1': <String, dynamic>{'id': 1},
          '2': <String, dynamic>{'id': 2},
        },
        arrangementOrder: <int>[1],
      );

      expect(
        () => migrateProjectJson(projectJson),
        throwsA(
          isA<ProjectFileMigrationException>()
              .having(
                (error) => error.fromVersion.toString(),
                'fromVersion',
                '0.0.0-prealpha.1',
              )
              .having(
                (error) => error.targetVersion.toString(),
                'targetVersion',
                '0.0.0-prealpha.2',
              )
              .having(
                (error) => error.cause,
                'cause',
                isA<MultipleArrangementsProjectFileException>().having(
                  (error) => error.arrangementCount,
                  'arrangementCount',
                  2,
                ),
              ),
        ),
      );

      final sequence = projectJson['sequence'] as Map<String, dynamic>;
      expect(projectJson['savedInSoftwareVersion'], '0.0.0-prealpha.1');
      expect(sequence, contains('arrangements'));
      expect(sequence, contains('arrangementOrder'));
      expect(sequence, isNot(contains('arrangement')));
    });

    test('rejects a project with no arrangement without mutating it', () {
      final projectJson = _projectWithArrangements(<String, dynamic>{});

      expect(
        () => migrateProjectJson(projectJson),
        throwsA(
          isA<ProjectFileMigrationException>().having(
            (error) => error.cause,
            'cause',
            isA<FormatException>(),
          ),
        ),
      );

      final sequence = projectJson['sequence'] as Map<String, dynamic>;
      expect(projectJson['savedInSoftwareVersion'], '0.0.0-prealpha.1');
      expect(sequence, contains('arrangements'));
      expect(sequence, isNot(contains('arrangement')));
    });

    test('rejects malformed old-schema structures', () {
      final malformedProjects = <Map<String, dynamic>>[
        <String, dynamic>{'savedInSoftwareVersion': '0.0.0-prealpha.1'},
        <String, dynamic>{
          'savedInSoftwareVersion': '0.0.0-prealpha.1',
          'sequence': 'not an object',
        },
        <String, dynamic>{
          'savedInSoftwareVersion': '0.0.0-prealpha.1',
          'sequence': <String, dynamic>{},
        },
        <String, dynamic>{
          'savedInSoftwareVersion': '0.0.0-prealpha.1',
          'sequence': <String, dynamic>{'arrangements': <dynamic>[]},
        },
        _projectWithArrangements(<String, dynamic>{'1': 'not an object'}),
      ];

      for (final projectJson in malformedProjects) {
        expect(
          () => migrateProjectJson(projectJson),
          throwsA(
            isA<ProjectFileMigrationException>().having(
              (error) => error.cause,
              'cause',
              isA<FormatException>(),
            ),
          ),
        );
      }
    });
  });
}
