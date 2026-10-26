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
import 'dart:typed_data';

import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/format.dart';
import 'package:anthem/logic/project_file/gzip.dart';
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/model/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/prealpha_1_project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> encodeProjectJson(Map<String, dynamic> projectJson) async {
    final output = BytesBuilder(copy: false)..add(projectFileHeader);
    final jsonBytes = Uint8List.fromList(
      JsonUtf8Encoder().convert(projectJson),
    );
    output.add(await compressGzip(jsonBytes));
    return output.takeBytes();
  }

  group('project file codec', () {
    test('encodes and decodes a project', () async {
      final project = ProjectModel.create()
        ..fileRetentions = '{"claim":"plugin states/State 01.bin"}';
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
      final restored = ProjectModel.fromJson(decodedJson);
      addTearDown(restored.dispose);
      expect(restored.fileRetentions, project.fileRetentions);
    });

    test('rejects an unsupported container header', () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);
      final unsupported = await encodeProjectFile(project);
      unsupported[11] = 99;
      await expectLater(
        decodeProjectFileBytes(unsupported),
        throwsA(isA<InvalidProjectFileException>()),
      );
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

    test('preserves the stored version and schema until explicit migration', () async {
      final oldProjectJson =
          jsonDecode(prealpha1ProjectJson) as Map<String, dynamic>;
      // Add a fixed legacy VST node to exercise opaque-state extraction and
      // migration of plugin parameter metadata alongside the native ports.
      oldProjectJson['processingGraph']['nodes']['17'] = {
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
      oldProjectJson['processingGraph']['connections']['18'] = {
        'id': 18,
        'sourceNodeId': 17,
        'sourcePortId': 0,
        'destinationNodeId': 4,
        'destinationPortId': 0,
        'dataType': 'audio',
      };
      oldProjectJson['processingGraph']['nodes']['4']['audioInputPorts'][0]['connections'] =
          [18];
      oldProjectJson['idCounter'] = 19;
      final bytes = await encodeProjectJson(oldProjectJson);

      final decodedJson = await decodeProjectFileBytes(bytes);
      expect(decodedJson, oldProjectJson);
      final savedVersion = readSavedProjectVersion(decodedJson);
      expect(savedVersion.toString(), '0.0.0-prealpha.1');
      final extracted = await Directory.systemTemp.createTemp(
        'anthem_extracted_project_',
      );
      addTearDown(() => extracted.delete(recursive: true));
      await migrateProjectJson(decodedJson, projectDirectory: extracted.path);
      expect(
        await File('${extracted.path}/plugin states/1.bin').readAsBytes(),
        [1, 2, 3],
      );
      expect(
        savedVersion < ProjectFileVersion.parse('0.0.0-prealpha.2'),
        isTrue,
      );
      expect(readSavedProjectVersion(decodedJson), currentProjectFileVersion);
      final decodedProject = ProjectModel.fromJson(decodedJson);
      addTearDown(decodedProject.dispose);
      expect(decodedProject.sequence.arrangement.id, 0);
      expect(decodedProject.tracks[2]!.name, 'Persistence track');
      expect(decodedProject.sequence.beatsPerMinuteRaw, 13700);
      expect(decodedProject.sequence.patterns[16]!.notes[0]!.key, 67);
      final gain = decodedProject.processingGraph.nodes[4]!.getPortById(2);
      expect(gain.parameterValue, 0.321);
      expect(gain.parameterResetValue, 0.65625);
      expect(gain.presentation.normalizedVisualBaseline, 0.25);
      expect(gain.config.parameterConfig!.factoryDefaultValue, isNull);
      final plugin = decodedProject.processingGraph.nodes[17]!;
      expect(
        jsonDecode(
          decodedProject.fileRetentions,
        )[plugin.processorStateRetentionId],
        'plugin states/1.bin',
      );
      final pluginParameter = plugin.getPortById(7);
      expect(pluginParameter.parameterValue, 0.123);
      expect(pluginParameter.parameterResetValue, 0.2);
      expect(pluginParameter.config.parameterConfig!.factoryDefaultValue, 0.2);
      expect(
        pluginParameter.config.parameterConfig!.displayMode,
        ParameterDisplayMode.pluginText,
      );
      expect(pluginParameter.presentation.normalizedVisualBaseline, 0.75);
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
      expect(
        await decodeProjectFileBytes(await encodeProjectFile(decodedProject)),
        decodedProject.toJson(),
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'anthem_project_file_migration_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final path = '${tempDir.path}${Platform.pathSeparator}project.anthem';
      await File(path).writeAsBytes(bytes);

      final storedJson = await readProjectFile(path);
      expect(storedJson, oldProjectJson);
      expect(
        await migrateProjectJson(
          storedJson,
          projectDirectory: '${tempDir.path}/extracted',
        ),
        decodedJson,
      );
      expect(await readProjectFile(path), oldProjectJson);
    });

    test('rejects files without an Anthem project file header', () async {
      final bytes = utf8.encode('{"id":"not-compressed"}');

      await expectLater(
        decodeProjectFileBytes(bytes),
        throwsA(isA<InvalidProjectFileException>()),
      );
    });

    test('reports file-system errors separately from invalid files', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'anthem_missing_project_file_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final missingPath =
          '${tempDir.path}${Platform.pathSeparator}missing.anthem';

      await expectLater(
        readProjectFile(missingPath),
        throwsA(isA<ProjectFileReadException>()),
      );
    });
  });
}
