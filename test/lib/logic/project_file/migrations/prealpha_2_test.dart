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
import 'dart:typed_data';

import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../../../fixtures/prealpha_1_project.dart';

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

Future<Uint8List> _privateStateBytes(File file) async {
  final bytes = await file.readAsBytes();
  expect(ascii.decode(bytes.sublist(0, 8)), 'ANTHST01');
  final metadataLength = ByteData.sublistView(
    bytes,
    8,
    12,
  ).getUint32(0, Endian.little);
  final metadata =
      jsonDecode(utf8.decode(bytes.sublist(12, 12 + metadataLength))) as Map;
  expect(metadata['version'], 1);
  return bytes.sublist(12 + metadataLength);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anthem_migration_');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<Map<String, dynamic>> migrateMetadata(
    Map<String, dynamic> json,
  ) async {
    final storage = await directory.createTemp('metadata_');
    return migrateProjectJson(json, projectDirectory: storage.path);
  }

  group('prealpha.2 project-file migration', () {
    test('migrates a complete legacy project into the current model', () async {
      final projectJson =
          jsonDecode(prealpha1ProjectJson) as Map<String, dynamic>;
      // Add a fixed legacy VST node to exercise opaque-state extraction and
      // migration of plugin parameter metadata alongside the native ports.
      projectJson['processingGraph']['nodes']['17'] = {
        'id': 17,
        'audioInputPorts': <dynamic>[],
        'audioOutputPorts': [
          {
            'id': 0,
            'nodeId': 17,
            'config': {'dataType': 'audio'},
            'connections': [18],
          },
        ],
        'eventInputPorts': <dynamic>[],
        'eventOutputPorts': <dynamic>[],
        'controlInputPorts': [
          {
            'id': 7,
            'nodeId': 17,
            'config': {
              'dataType': 'control',
              'parameterConfig': {
                'id': 7,
                'defaultValue': 0.2,
                'displayMode': 'pluginText',
                'normalizedVisualBaseline': 0.75,
              },
            },
            'connections': <dynamic>[],
            'parameterValue': 0.123,
          },
        ],
        'controlOutputPorts': <dynamic>[],
        'isThirdPartyPlugin': true,
        'processor': {
          'VST3ProcessorModel': {'nodeId': 17, 'vst3Path': '/test/plugin.vst3'},
        },
        'processorState': '3.AHv.',
      };
      projectJson['processingGraph']['connections']['18'] = {
        'id': 18,
        'sourceNodeId': 17,
        'sourcePortId': 0,
        'destinationNodeId': 4,
        'destinationPortId': 0,
        'dataType': 'audio',
      };
      projectJson['processingGraph']['nodes']['4']['audioInputPorts'][0]['connections'] =
          [18];
      projectJson['idCounter'] = 19;
      await migrateProjectJson(projectJson, projectDirectory: directory.path);
      final pluginRetention =
          projectJson['processingGraph']['nodes']['17']['processorStateRetentionId'];
      final pluginPath =
          (jsonDecode(projectJson['fileRetentions']) as Map)[pluginRetention]
              as String;
      expect(
        await _privateStateBytes(File(path.join(directory.path, pluginPath))),
        [1, 2, 3],
      );
      expect(readSavedProjectVersion(projectJson), currentProjectFileVersion);
      final decodedProject = ProjectModel.fromJson(projectJson);
      addTearDown(decodedProject.dispose);
      expect(decodedProject.sequence.arrangement.id, 0);
      expect(decodedProject.tracks[2]!.name, 'Persistence track');
      expect(decodedProject.sequence.beatsPerMinuteRaw, 13700);
      expect(decodedProject.sequence.patterns[16]!.notes[0]!.key, 67);
      final gain = decodedProject.processingGraph.nodes[4]!.getPortById(2);
      expect(gain.parameterValue, 0.321);
      expect(gain.parameterResetValue, 0.65625);
      expect(gain.config.parameterConfig!.normalizedVisualBaseline, 0.25);
      expect(gain.config.parameterConfig!.factoryDefaultValue, isNull);
      final plugin = decodedProject.processingGraph.nodes[17]!;
      expect(
        jsonDecode(
          decodedProject.fileRetentions,
        )[plugin.processorStateRetentionId],
        pluginPath,
      );
      final pluginParameter = plugin.getPortById(7);
      expect(pluginParameter.parameterValue, 0.123);
      expect(pluginParameter.parameterResetValue, 0.2);
      expect(pluginParameter.config.parameterConfig!.factoryDefaultValue, 0.2);
      expect(
        pluginParameter.config.parameterConfig!.displayMode,
        ParameterDisplayMode.pluginText,
      );
      expect(
        pluginParameter.config.parameterConfig!.normalizedVisualBaseline,
        0.75,
      );
      final connection = decodedProject.processingGraph.connections[18]!;
      expect(connection.sourceNodeId, plugin.id);
      expect(connection.destinationNodeId, 4);
      expect(plugin.getPortById(0).connections, [18]);
      expect(
        decodedProject.processingGraph.nodes[4]!.getPortById(0).connections,
        [18],
      );
      expect(
        decodedProject.toJson()['processingGraph']['nodes']['17'],
        isNot(contains('processorState')),
      );
      final currentJson = decodedProject.toJson();
      final restored = ProjectModel.fromJson(currentJson);
      addTearDown(restored.dispose);
      expect(restored.toJson(), currentJson);
    });

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
        await _privateStateBytes(
          File(path.join(directory.path, 'plugin states', '1.bin')),
        ),
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
        await _privateStateBytes(
          File(path.join(directory.path, 'plugin states', '1.bin')),
        ),
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
        await _privateStateBytes(
          File(path.join(directory.path, 'plugin states', '2.bin')),
        ),
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
      'preserves routing and automation while migrating parameter metadata',
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

        await migrateMetadata(project);

        final parameter = port['config']['parameterConfig'] as Map;
        expect(parameter, {
          'id': 7,
          'factoryDefaultValue': 0.2,
          'displayMode': 'percent',
          'unitLabel': '%',
          'normalizedVisualBaseline': 0.25,
        });
        expect(port['parameterValue'], 0.1);
        expect(port['parameterResetValue'], 0.2);
        expect(port, isNot(contains('presentation')));
        expect(port['connections'], [17]);
        expect(node, isNot(contains('processorState')));
        expect(node['processorStateRetentionId'], isNotNull);
        expect(node['initialParameterValues'], isEmpty);
        expect(node, isNot(contains('isThirdPartyPlugin')));
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
      await migrateMetadata(_projectWithNode(node));

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
          await migrateMetadata(_projectWithNode(node));
          expect(
            port['config']['parameterConfig']['normalizedVisualBaseline'],
            baseline ?? 0.5,
          );
          expect(port['parameterResetValue'], 0.5);
          expect(port, isNot(contains('presentation')));
        }
      });
    }

    test('keeps non-parameter ports free of parameter metadata', () async {
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
      await migrateMetadata(_projectWithNode(node));
      for (final port in ports) {
        expect(port, isNot(contains('presentation')));
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
        await migrateMetadata(_projectWithNode(node));
        expect(port['config']['parameterConfig']['factoryDefaultValue'], 0.2);
        expect(port['parameterResetValue'], 0.2);
        expect(port, isNot(contains('presentation')));
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
            migrateMetadata(_projectWithNode(node)),
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
            migrateMetadata(_projectWithNode(node)),
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
