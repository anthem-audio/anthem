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

import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/device_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path/path.dart' as path;

import '../../helpers/file_dialog_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VST3 selection', () {
    late ProjectModel project;
    late _Vst3FileSelector selector;
    late RecordingDialog recordingDialog;
    late Directory directory;

    setUp(() {
      final originalSelector = FileSelectorPlatform.instance;
      selector = _Vst3FileSelector();
      FileSelectorPlatform.instance = selector;
      addTearDown(() => FileSelectorPlatform.instance = originalSelector);
      directory = Directory.systemTemp.createTempSync('anthem_vst3_picker_');
      addTearDown(() => directory.deleteSync(recursive: true));
      project = ProjectModel.create();
      project.engine.processingGraphApi = _UnstartedProcessingGraphApi();
      ServiceRegistry.initializeProject(project);
      addTearDown(() {
        ServiceRegistry.removeProject(project.id);
        project.dispose();
      });
      recordingDialog = RecordingDialog();
      ServiceRegistry.dialogController.initialize(recordingDialog);
      addTearDown(ServiceRegistry.dialogController.dispose);
    });

    test('cancellation leaves the rack unchanged without an error', () async {
      final track = project.tracks[project.trackOrder.first]!;
      final devices = track.requireProcessing.devices.toList();

      await DeviceController(project)
          .addDevice(trackId: track.id, type: DeviceType.vst3Plugin);

      expect(selector.selectionCount, 1);
      expect(track.requireProcessing.devices, devices);
      expect(project.isDirty, isFalse);
      expect(recordingDialog.shownCount, 0);
    });

    test('the selected bundle path reaches the VST3 processor', () async {
      final bundle = Directory(path.join(directory.path, 'Test Plugin.VST3'))
        ..createSync();
      selector.selectedPluginPath = bundle.path;
      final track = project.tracks[project.trackOrder.first]!;
      final deviceCount = track.requireProcessing.devices.length;

      await DeviceController(project)
          .addDevice(trackId: track.id, type: DeviceType.vst3Plugin, index: 0);

      expect(selector.selectionCount, 1);
      expect(track.requireProcessing.devices, hasLength(deviceCount + 1));
      final device = track.requireProcessing.devices.first;
      expect(device.type, DeviceType.vst3Plugin);
      final node = project.processingGraph.nodes[device.nodeIds.single]!;
      expect((node.processor as VST3ProcessorModel).vst3Path, bundle.path);
      expect(project.isDirty, isTrue);
      expect(recordingDialog.shownCount, 0);
    });

    test('a directory without the VST3 suffix is rejected', () async {
      final otherDirectory = Directory(
        path.join(directory.path, 'Not a plugin'),
      )..createSync();
      selector.selectedPluginPath = otherDirectory.path;
      final track = project.tracks[project.trackOrder.first]!;
      final devices = track.requireProcessing.devices.toList();
      final nodeIds = project.processingGraph.nodes.keys.toSet();

      await DeviceController(project)
          .addDevice(trackId: track.id, type: DeviceType.vst3Plugin);

      expect(selector.selectionCount, 1);
      expect(track.requireProcessing.devices, devices);
      expect(project.processingGraph.nodes.keys.toSet(), nodeIds);
      expect(project.isDirty, isFalse);
      expect(recordingDialog.shownCount, 1);
    });
  }, skip: kIsWeb);

  test('rack routing skips incompatible devices in the sparse audio chain', () {
    final project = ProjectModel.create();
    ServiceRegistry.initializeProject(project);

    try {
      final track = project.tracks[project.trackOrder.first]!;
      final idAllocator = project.idAllocator;

      final toneGenerator = DeviceFactories.toneGenerator(
        idAllocator: idAllocator,
      );
      project.processingGraph.restoreGraphFragment(toneGenerator.graphFragment);

      final gainNodeB = GainProcessorModel.create(idAllocator: idAllocator)
          .createNode();
      final audioDeviceB = _audioDevice(
        project: project,
        node: gainNodeB,
        name: 'Gain B',
      );
      project.processingGraph.addNode(gainNodeB);

      final unchainableSourceC = DeviceFactories.toneGenerator(
        idAllocator: idAllocator,
      );
      final nodeC = unchainableSourceC.graphFragment.nodes.single;
      project.processingGraph.restoreGraphFragment(
        unchainableSourceC.graphFragment,
      );

      final gainNodeD = GainProcessorModel.create(idAllocator: idAllocator)
          .createNode();
      final audioDeviceD = _audioDevice(
        project: project,
        node: gainNodeD,
        name: 'Gain D',
      );
      project.processingGraph.addNode(gainNodeD);

      final processing = track.requireProcessing;
      processing.devices.addAll([
        toneGenerator.device,
        audioDeviceB,
        unchainableSourceC.device,
        audioDeviceD,
      ]);

      ServiceRegistry.forProject(project.id).deviceController
          .rebuildTrackDeviceRouting(track.id);

      expect(
        _connectionsMatching(
          project,
          sourceNodeId: toneGenerator.graphFragment.nodes.single.id,
          sourcePortId: ToneGeneratorProcessorModel.audioOutputPortId,
          destinationNodeId: gainNodeB.id,
          destinationPortId: GainProcessorModel.audioInputPortId,
        ),
        hasLength(1),
      );
      expect(
        _connectionsMatching(
          project,
          sourceNodeId: gainNodeB.id,
          sourcePortId: GainProcessorModel.audioOutputPortId,
          destinationNodeId: gainNodeD.id,
          destinationPortId: GainProcessorModel.audioInputPortId,
        ),
        hasLength(1),
      );
      expect(
        _connectionsMatching(
          project,
          sourceNodeId: gainNodeD.id,
          sourcePortId: GainProcessorModel.audioOutputPortId,
          destinationNodeId: processing.utilityNodeId!,
          destinationPortId: UtilityProcessorModel.audioInputPortId,
        ),
        hasLength(1),
      );
      expect(
        project.processingGraph.connections.values.where(
          (connection) =>
              connection.destinationNodeId == nodeC.id ||
              connection.sourceNodeId == nodeC.id,
        ),
        isEmpty,
      );
    } finally {
      ServiceRegistry.removeProject(project.id);
      project.dispose();
    }
  });
}

/// Unit tests stop at the project model; plugin initialization is exercised in
/// integration_test/plugin_test.dart with a real engine.
class _UnstartedProcessingGraphApi extends Fake implements ProcessingGraphApi {
  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: false, results: []);
}

/// Rejects a file-only request on Linux, where it cannot select VST3 bundles.
class _Vst3FileSelector extends FileSelectorPlatform {
  String? selectedPluginPath;
  int selectionCount = 0;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    expect(
      Platform.isLinux,
      isFalse,
      reason: 'Linux VST3 bundles require a directory chooser.',
    );
    expect(acceptedTypeGroups?.single.extensions, ['vst3']);
    final selected = _selectPlugin(confirmButtonText);
    return selected == null ? null : XFile(selected);
  }

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    expect(Platform.isLinux, isTrue);
    return _selectPlugin(confirmButtonText);
  }

  String? _selectPlugin(String? confirmButtonText) {
    selectionCount++;
    expect(confirmButtonText, 'Choose plugin');
    return selectedPluginPath;
  }
}

DeviceModel _audioDevice({
  required ProjectModel project,
  required NodeModel node,
  required String name,
}) {
  return DeviceModel(
    idAllocator: project.idAllocator,
    name: name,
    type: DeviceType.toneGenerator,
    nodeIds: AnthemObservableList.of([node.id]),
    defaultAudioInputPort: ProcessingGraphPortRefModel(
      nodeId: node.id,
      portId: GainProcessorModel.audioInputPortId,
    ),
    defaultAudioOutputPort: ProcessingGraphPortRefModel(
      nodeId: node.id,
      portId: GainProcessorModel.audioOutputPortId,
    ),
  );
}

List<Object> _connectionsMatching(
  ProjectModel project, {
  required int sourceNodeId,
  required int sourcePortId,
  required int destinationNodeId,
  required int destinationPortId,
}) {
  return project.processingGraph.connections.values
      .where(
        (connection) =>
            connection.sourceNodeId == sourceNodeId &&
            connection.sourcePortId == sourcePortId &&
            connection.destinationNodeId == destinationNodeId &&
            connection.destinationPortId == destinationPortId,
      )
      .toList();
}
