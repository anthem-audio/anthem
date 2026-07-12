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

import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem_codegen/include.dart';

typedef DeviceCreateResult = ({
  DeviceModel device,
  ProcessingGraphFragment graphFragment,
});

class DeviceDescriptorForCommand {
  final DeviceType type;
  final int? index;
  final String? vst3Path;

  DeviceDescriptorForCommand({required this.type, this.index, this.vst3Path});
}

class DeviceFactories {
  static DeviceCreateResult create({
    required ProjectEntityIdAllocator idAllocator,
    required DeviceDescriptorForCommand descriptor,
  }) {
    return switch (descriptor.type) {
      DeviceType.toneGenerator => toneGenerator(idAllocator: idAllocator),
      DeviceType.utility => utility(idAllocator: idAllocator),
      DeviceType.vst3Plugin => vst3Plugin(
        idAllocator: idAllocator,
        vst3Path: _getRequiredVst3Path(descriptor),
      ),
    };
  }

  static DeviceCreateResult toneGenerator({
    required ProjectEntityIdAllocator idAllocator,
  }) {
    final node = ToneGeneratorProcessorModel.create(
      idAllocator: idAllocator,
    ).createNode();

    return _singleNodeDevice(
      idAllocator: idAllocator,
      name: 'Tone Generator',
      type: DeviceType.toneGenerator,
      node: node,
      defaultAudioOutputPortId: ToneGeneratorProcessorModel.audioOutputPortId,
      defaultEventInputPortId: ToneGeneratorProcessorModel.eventInputPortId,
    );
  }

  static DeviceCreateResult vst3Plugin({
    required ProjectEntityIdAllocator idAllocator,
    required String vst3Path,
  }) {
    final node = VST3ProcessorModel.create(
      idAllocator: idAllocator,
      vst3Path: vst3Path,
    ).createNode();

    return _singleNodeDevice(
      idAllocator: idAllocator,
      name: _formatVst3DeviceName(vst3Path),
      type: DeviceType.vst3Plugin,
      node: node,
      defaultAudioOutputPortId: VST3ProcessorModel.audioOutputPortId,
      defaultEventInputPortId: VST3ProcessorModel.eventInputPortId,
    );
  }

  static DeviceCreateResult utility({
    required ProjectEntityIdAllocator idAllocator,
  }) {
    final node = UtilityProcessorModel.create(
      idAllocator: idAllocator,
    ).createNode();

    return _singleNodeDevice(
      idAllocator: idAllocator,
      name: 'Utility',
      type: DeviceType.utility,
      node: node,
      defaultAudioInputPortId: UtilityProcessorModel.audioInputPortId,
      defaultAudioOutputPortId: UtilityProcessorModel.audioOutputPortId,
    );
  }

  static DeviceCreateResult _singleNodeDevice({
    required ProjectEntityIdAllocator idAllocator,
    required String name,
    required DeviceType type,
    required NodeModel node,
    int? defaultAudioInputPortId,
    int? defaultAudioOutputPortId,
    int? defaultEventInputPortId,
    int? defaultEventOutputPortId,
  }) {
    final device = DeviceModel(
      idAllocator: idAllocator,
      name: name,
      type: type,
      nodeIds: AnthemObservableList.of([node.id]),
      defaultAudioInputPort: defaultAudioInputPortId == null
          ? null
          : ProcessingGraphPortRefModel(
              nodeId: node.id,
              portId: defaultAudioInputPortId,
            ),
      defaultAudioOutputPort: defaultAudioOutputPortId == null
          ? null
          : ProcessingGraphPortRefModel(
              nodeId: node.id,
              portId: defaultAudioOutputPortId,
            ),
      defaultEventInputPort: defaultEventInputPortId == null
          ? null
          : ProcessingGraphPortRefModel(
              nodeId: node.id,
              portId: defaultEventInputPortId,
            ),
      defaultEventOutputPort: defaultEventOutputPortId == null
          ? null
          : ProcessingGraphPortRefModel(
              nodeId: node.id,
              portId: defaultEventOutputPortId,
            ),
    );

    return (
      device: device,
      graphFragment: ProcessingGraphFragment(nodes: [node], connections: []),
    );
  }

  static String _formatVst3DeviceName(String vst3Path) {
    final fileName = vst3Path.split(RegExp(r'[/\\]')).last;
    if (fileName.toLowerCase().endsWith('.vst3')) {
      return fileName.substring(0, fileName.length - '.vst3'.length);
    }

    return fileName;
  }

  static String _getRequiredVst3Path(DeviceDescriptorForCommand descriptor) {
    final vst3Path = descriptor.vst3Path;
    if (vst3Path == null) {
      throw StateError(
        'DeviceFactories.create(): VST3 devices require a vst3Path.',
      );
    }

    return vst3Path;
  }
}
