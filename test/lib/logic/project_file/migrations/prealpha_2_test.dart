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

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

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
    'processingGraph': <String, dynamic>{'nodes': <String, dynamic>{}},
    'unrelatedProjectField': 'preserved',
  };
}

Map<String, dynamic> _oldNode({
  String? processor = 'VST3ProcessorModel',
  bool isThirdPartyPlugin = true,
}) => {
  'id': 1,
  'isThirdPartyPlugin': isThirdPartyPlugin,
  'processor': processor == null
      ? null
      : {
          processor: {'nodeId': 1},
        },
  'processorState': '',
  'audioInputPorts': <dynamic>[],
  'audioOutputPorts': <dynamic>[],
  'eventInputPorts': <dynamic>[],
  'eventOutputPorts': <dynamic>[],
  'controlInputPorts': <dynamic>[],
  'controlOutputPorts': <dynamic>[],
};

Map<String, dynamic> _oldParameterPort({
  int id = 7,
  num defaultValue = 0.2,
  Map<String, dynamic> metadata = const {},
}) => {
  'id': id,
  'nodeId': 1,
  'connections': [17],
  'parameterValue': 0.1,
  'config': {
    'dataType': 'control',
    'parameterConfig': {
      'id': id,
      'defaultValue': defaultValue,
      'displayMode': 'percent',
      ...metadata,
    },
  },
};

Map<String, dynamic> _projectWithNode(Map<String, dynamic> node) {
  final project = _projectWithArrangements({
    '42': <String, dynamic>{'id': 42},
  });
  project['processingGraph']['nodes']['1'] = node;
  return project;
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anthem_migration_');
  });
  tearDown(() => directory.delete(recursive: true));

  group('prealpha.2 project-file migration', () {
    test('extracts JUCE state bytes before model deserialization', () async {
      // Produced by juce::MemoryBlock::toBase64Encoding for bytes 1, 2, 3.
      final node = _oldNode()..['processorState'] = '3.AHv.';
      final json = _projectWithNode(node);
      await migrateProjectJson(json, projectDirectory: directory.path);
      expect(
        jsonDecode(json['fileRetentions'])[node['processorStateRetentionId']],
        'plugin states/1.bin',
      );
      expect(
        await File(path.join(directory.path, 'plugin states', '1.bin'))
            .readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await Directory(path.join(directory.path, '.pending')).exists(),
        isFalse,
      );
      expect(node, isNot(contains('processorState')));
    });

    test('decodes binary state across six-bit and byte boundaries', () async {
      final node = _oldNode()..['processorState'] = '8..7Of.82+..H';
      await migrateProjectJson(
        _projectWithNode(node),
        projectDirectory: directory.path,
      );
      expect(
        await File(path.join(directory.path, 'plugin states', '1.bin'))
            .readAsBytes(),
        [0, 255, 128, 64, 127, 255, 0, 128],
      );
    });

    test('extracts each node state to a separate file', () async {
      final first = _oldNode()..['processorState'] = '3.AHv.';
      final second = _oldNode()
        ..['id'] = 2
        ..['processorState'] = '8..7Of.82+..H';
      final json = _projectWithNode(first);
      json['processingGraph']['nodes']['2'] = second;
      await migrateProjectJson(json, projectDirectory: directory.path);
      expect(
        jsonDecode(json['fileRetentions'])[first['processorStateRetentionId']],
        'plugin states/1.bin',
      );
      expect(
        jsonDecode(json['fileRetentions'])[second['processorStateRetentionId']],
        'plugin states/2.bin',
      );
      expect(
        await File(path.join(directory.path, 'plugin states', '2.bin'))
            .readAsBytes(),
        [0, 255, 128, 64, 127, 255, 0, 128],
      );
    });

    test('does not overwrite an existing destination file', () async {
      final existing = File(
        path.join(directory.path, 'plugin states', '1.bin'),
      );
      await existing.parent.create();
      await existing.writeAsString('keep');
      await expectLater(
        migrateProjectJson(
          _projectWithNode(_oldNode()..['processorState'] = '3.AHv.'),
          projectDirectory: directory.path,
        ),
        throwsA(
          isA<ProjectFileMigrationException>().having(
            (error) => error.cause,
            'cause',
            isA<FileSystemException>(),
          ),
        ),
      );
      expect(await existing.readAsString(), 'keep');
    });

    test('embedded state requires a destination directory', () async {
      await expectLater(
        migrateProjectJson(
          _projectWithNode(_oldNode()..['processorState'] = '3.AHv.'),
        ),
        throwsA(
          isA<ProjectFileMigrationException>().having(
            (error) => error.cause,
            'cause',
            isA<ProjectDirectoryRequiresDesktopException>(),
          ),
        ),
      );
    });

    test(
      'rejects malformed state without allocating its declared size',
      () async {
        for (final state in [
          'not encoded',
          '9999999999999999999.A',
          '1.?',
          '2.A',
        ]) {
          final node = _oldNode()..['processorState'] = state;
          await expectLater(
            migrateProjectJson(
              _projectWithNode(node),
              projectDirectory: directory.path,
            ),
            throwsA(
              isA<ProjectFileMigrationException>().having(
                (error) => error.cause,
                'cause',
                isA<FormatException>(),
              ),
            ),
          );
          expect(await directory.list().toList(), isEmpty);
        }
      },
    );

    test(
      'reports file extraction failure and leaves the version unchanged',
      () async {
        final node = _oldNode()..['processorState'] = '3.AHv.';
        final json = _projectWithNode(node);
        final blocker = await File(path.join(directory.path, 'plugin states'))
            .writeAsString('keep');
        await expectLater(
          migrateProjectJson(json, projectDirectory: directory.path),
          throwsA(
            isA<ProjectFileMigrationException>().having(
              (exception) => exception.cause,
              'cause',
              isA<FileSystemException>(),
            ),
          ),
        );
        expect(json['savedInSoftwareVersion'], '0.0.0-prealpha.1');
        expect(await blocker.readAsString(), 'keep');
      },
    );

    test('promotes the only arrangement and preserves its JSON', () async {
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

      final result = await migrateProjectJson(projectJson);
      final sequence = result['sequence'] as Map<String, dynamic>;

      expect(result, same(projectJson));
      expect(result['savedInSoftwareVersion'], '0.0.0-prealpha.2');
      expect(sequence['arrangement'], same(arrangement));
      expect(sequence, isNot(contains('arrangements')));
      expect(sequence, isNot(contains('arrangementOrder')));
      expect(sequence['unrelatedSequenceField'], 'preserved');
      expect(result['unrelatedProjectField'], 'preserved');
    });

    test('rejects multiple arrangements before mutating the project', () async {
      final projectJson = _projectWithArrangements(
        <String, dynamic>{
          '1': <String, dynamic>{'id': 1},
          '2': <String, dynamic>{'id': 2},
        },
        arrangementOrder: <int>[1],
      );

      await expectLater(
        migrateProjectJson(projectJson),
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

    test('rejects a project with no arrangement without mutating it', () async {
      final projectJson = _projectWithArrangements(<String, dynamic>{});

      await expectLater(
        migrateProjectJson(projectJson),
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

    test('rejects malformed old-schema structures', () async {
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
        await expectLater(
          migrateProjectJson(projectJson),
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

    test(
      'preserves routing and automation while splitting parameter metadata',
      () async {
        final port = _oldParameterPort(
          metadata: {'normalizedVisualBaseline': 0.25, 'unitLabel': '%'},
        );
        final node = _oldNode()..['controlInputPorts'] = [port];
        final project = _projectWithNode(node);
        final connections = {
          '17': {'id': 17, 'sourceNodeId': 1, 'sourcePortId': 7},
        };
        final patterns = {
          '4': {
            'automationTarget': {'nodeId': 1, 'portId': 7},
          },
        };
        project['processingGraph']['connections'] = connections;
        project['sequence']['patterns'] = patterns;

        await migrateProjectJson(project);

        final parameter = port['config']['parameterConfig'] as Map;
        expect(parameter, {
          'id': 7,
          'factoryDefaultValue': 0.2,
          'displayMode': 'percent',
          'unitLabel': '%',
        });
        expect(port['parameterValue'], 0.1);
        expect(port['parameterResetValue'], 0.2);
        expect(port['presentation'], {'normalizedVisualBaseline': 0.25});
        expect(port['connections'], [17]);
        expect(node, isNot(contains('processorState')));
        expect(node['processorStateRetentionId'], isNull);
        expect(project['processingGraph']['connections'], same(connections));
        expect(project['sequence']['patterns'], same(patterns));
      },
    );

    test('native gain keeps the old reset target while its factory default awaits discovery', () async {
      const tenDbBelowUnity = 0.65625;
      final port = _oldParameterPort(id: 2, defaultValue: tenDbBelowUnity)
        ..['parameterValue'] = 0.321;
      final node = _oldNode(
        processor: 'UtilityProcessorModel',
        isThirdPartyPlugin: false,
      )..['controlInputPorts'] = [port];
      await migrateProjectJson(_projectWithNode(node));

      expect(port['parameterValue'], 0.321);
      expect(port['parameterResetValue'], tenDbBelowUnity);
      expect(
        port['config']['parameterConfig'],
        isNot(contains('factoryDefaultValue')),
      );
      expect(
        port['config']['parameterConfig'],
        isNot(contains('defaultValue')),
      );
    });

    for (final (processor, panId) in [
      ('UtilityProcessorModel', 3),
      ('BalanceProcessorModel', 2),
    ]) {
      test('$processor migrates absent and explicit pan baselines', () async {
        for (final baseline in [null, 0.0, 0.25, 0.5, 1.0]) {
          final port = _oldParameterPort(
            id: panId,
            defaultValue: 0.5,
            metadata: {'normalizedVisualBaseline': ?baseline},
          );
          final node = _oldNode(processor: processor, isThirdPartyPlugin: false)
            ..['controlInputPorts'] = [port];
          await migrateProjectJson(_projectWithNode(node));
          expect(port['presentation'], {
            'normalizedVisualBaseline': baseline ?? 0.5,
          });
          expect(port['parameterResetValue'], 0.5);
          expect(
            port['config']['parameterConfig'],
            isNot(contains('normalizedVisualBaseline')),
          );
        }
      });
    }

    test('adds presentation metadata to every port group without changing channels or connections', () async {
      final node = _oldNode();
      final ports = <Map<String, dynamic>>[];
      for (final (group, type) in [
        ('audioInputPorts', 'audio'),
        ('audioOutputPorts', 'audio'),
        ('eventInputPorts', 'event'),
        ('eventOutputPorts', 'event'),
        ('controlInputPorts', 'control'),
        ('controlOutputPorts', 'control'),
      ]) {
        final port = <String, dynamic>{
          'id': ports.length,
          'nodeId': 1,
          'connections': [17],
          'config': {'dataType': type, if (type == 'audio') 'channelCount': 4},
        };
        node[group] = [port];
        ports.add(port);
      }
      await migrateProjectJson(_projectWithNode(node));
      for (final port in ports) {
        expect(port['presentation'], {'normalizedVisualBaseline': 0.0});
        expect(port['connections'], [17]);
        expect(port, isNot(contains('parameterResetValue')));
        if (port['config']['dataType'] == 'audio') {
          expect(port['config']['channelCount'], 4);
        }
      }
    });

    test('processorless parameters retain their default and plugin formatting does not imply a baseline', () async {
      for (final processor in [null, 'VST3ProcessorModel']) {
        final port = _oldParameterPort(metadata: {'displayMode': 'pan'});
        final node = _oldNode(
          processor: processor,
          isThirdPartyPlugin: processor != null,
        )..['controlInputPorts'] = [port];
        await migrateProjectJson(_projectWithNode(node));
        expect(port['config']['parameterConfig']['factoryDefaultValue'], 0.2);
        expect(port['parameterResetValue'], 0.2);
        expect(port['presentation'], {'normalizedVisualBaseline': 0.0});
      }
    });

    test(
      'reports invalid legacy baseline and default values as migration errors',
      () async {
        for (final value in [
          -0.1,
          1.1,
          double.nan,
          double.infinity,
          'center',
          null,
        ]) {
          final port = _oldParameterPort(
            metadata: {'normalizedVisualBaseline': value},
          );
          final node = _oldNode()..['controlInputPorts'] = [port];
          await expectLater(
            migrateProjectJson(_projectWithNode(node)),
            throwsA(
              isA<ProjectFileMigrationException>().having(
                (error) => error.cause,
                'cause',
                isA<FormatException>(),
              ),
            ),
          );
        }
        for (final value in [null, 'default']) {
          final port = _oldParameterPort();
          port['config']['parameterConfig']['defaultValue'] = value;
          final node = _oldNode()..['controlInputPorts'] = [port];
          await expectLater(
            migrateProjectJson(_projectWithNode(node)),
            throwsA(
              isA<ProjectFileMigrationException>().having(
                (error) => error.cause,
                'cause',
                isA<FormatException>(),
              ),
            ),
          );
        }
      },
    );

    test('rejects malformed processing graph metadata', () async {
      final mutations = <void Function(Map<String, dynamic>)>[
        (json) => json.remove('processingGraph'),
        (json) => json['processingGraph'] = <dynamic>[],
        (json) => json['processingGraph']['nodes'] = <dynamic>[],
        (json) => json['processingGraph']['nodes']['1'] = <dynamic>[],
        (json) => json['processingGraph']['nodes']['1']['isThirdPartyPlugin'] =
            'true',
        (json) =>
            json['processingGraph']['nodes']['1']['processor'] = <dynamic>[],
        (json) => json['processingGraph']['nodes']['1']['controlInputPorts'] =
            <String, dynamic>{},
        (json) => json['processingGraph']['nodes']['1']['controlInputPorts'] =
            <dynamic>[<dynamic>[]],
        (json) => json['processingGraph']['nodes']['1']['controlInputPorts'] =
            <dynamic>[
              <String, dynamic>{'config': <dynamic>[]},
            ],
        (json) => json['processingGraph']['nodes']['1']['controlInputPorts'] =
            <dynamic>[
              <String, dynamic>{
                'config': <String, dynamic>{'parameterConfig': <dynamic>[]},
              },
            ],
      ];
      for (final mutate in mutations) {
        final project = _projectWithNode(_oldNode());
        mutate(project);
        await expectLater(
          migrateProjectJson(project),
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
