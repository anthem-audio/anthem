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
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/model/processing_graph/parameter_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Map<String, dynamic> createPrealpha1ProjectJson(ProjectModel project) {
    final projectJson = project.toJson()
      ..['savedInSoftwareVersion'] = '0.0.0-prealpha.1';
    final sequence = projectJson['sequence'] as Map<String, dynamic>;
    final arrangement = sequence.remove('arrangement') as Map<String, dynamic>;
    final arrangementId = arrangement['id'] as int;

    sequence['arrangements'] = <String, dynamic>{
      arrangementId.toString(): arrangement,
    };
    sequence['arrangementOrder'] = <int>[arrangementId];

    final nodes = projectJson['processingGraph']['nodes'] as Map;
    for (final node in nodes.values) {
      for (final group in [
        'audioInputPorts',
        'audioOutputPorts',
        'eventInputPorts',
        'eventOutputPorts',
        'controlInputPorts',
        'controlOutputPorts',
      ]) {
        for (final port in node[group] as List) {
          final presentation = port.remove('presentation') as Map;
          final resetValue = port.remove('parameterResetValue');
          final parameter = port['config']['parameterConfig'] as Map?;
          if (parameter == null) continue;
          final factoryDefault = parameter.remove('factoryDefaultValue');
          parameter['defaultValue'] = resetValue ?? factoryDefault;
          parameter['normalizedVisualBaseline'] =
              presentation['normalizedVisualBaseline'];
        }
      }
    }

    return projectJson;
  }

  group('project file codec', () {
    test('encodes and decodes a project', () async {
      final project = ProjectModel.create();
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

    test('migrates byte and path reads before returning JSON', () async {
      final project = ProjectModel.create();
      addTearDown(project.dispose);

      final utility =
          project.processingGraph.nodes[project
              .tracks[project.trackOrder.single]!
              .requireProcessing
              .utilityNodeId]!;
      final gain = utility.getPortById(UtilityProcessorModel.gainPortId)
        ..parameterValue = 0.321;
      gain.presentation.normalizedVisualBaseline = 0.25;
      final plugin = VST3ProcessorModel.create(
        idAllocator: project.idAllocator,
        vst3Path: '/test/plugin.vst3',
      ).createNode()..processorState = 'c2F2ZWQgcGx1Z2luIHN0YXRl';
      plugin.controlInputPorts.add(
        NodePortModel(
          id: 7,
          nodeId: plugin.id,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: 7,
              factoryDefaultValue: 0.2,
              displayMode: ParameterDisplayMode.pluginText,
            ),
          ),
          initialParameterValue: 0.123,
          parameterResetValue: 0.2,
          presentation: ParameterPresentationModel(
            normalizedVisualBaseline: 0.75,
          ),
        ),
      );
      project.processingGraph.addNode(plugin);
      project.processingGraph.addConnection(
        NodeConnectionModel(
          idAllocator: project.idAllocator,
          sourceNodeId: plugin.id,
          sourcePortId: VST3ProcessorModel.audioOutputPortId,
          destinationNodeId: utility.id,
          destinationPortId: UtilityProcessorModel.audioInputPortId,
          dataType: NodePortDataType.audio,
        ),
      );

      final oldProjectJson = createPrealpha1ProjectJson(project);
      final bytes = await encodeProjectJson(oldProjectJson);
      final expectedJson = project.toJson();

      final decodedJson = await decodeProjectFileBytes(bytes);
      expect(decodedJson, equals(expectedJson));
      final decodedProject = ProjectModel.fromJson(decodedJson);
      addTearDown(decodedProject.dispose);
      expect(
        decodedProject.sequence.arrangement.id,
        project.sequence.arrangement.id,
      );
      expect(decodedProject.toJson(), expectedJson);

      final tempDir = await Directory.systemTemp.createTemp(
        'anthem_project_file_migration_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final path = '${tempDir.path}${Platform.pathSeparator}project.anthem';
      await File(path).writeAsBytes(bytes);

      expect(await readProjectFile(path), equals(expectedJson));
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
