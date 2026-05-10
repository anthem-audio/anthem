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

import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      final gainNodeB = GainProcessorModel.create(
        idAllocator: idAllocator,
      ).createNode();
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

      final gainNodeD = GainProcessorModel.create(
        idAllocator: idAllocator,
      ).createNode();
      final audioDeviceD = _audioDevice(
        project: project,
        node: gainNodeD,
        name: 'Gain D',
      );
      project.processingGraph.addNode(gainNodeD);

      track.devices.addAll([
        toneGenerator.device,
        audioDeviceB,
        unchainableSourceC.device,
        audioDeviceD,
      ]);

      ServiceRegistry.forProject(
        project.id,
      ).deviceController.rebuildTrackDeviceRouting(track.id);

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
          destinationNodeId: track.utilityNodeId!,
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
