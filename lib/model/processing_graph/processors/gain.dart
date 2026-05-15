/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'gain.g.dart';

/// A gain processor, used for basic volume controls.
///
/// Takes a single audio input and output, and a control input for gain.
///
/// The control input expects a [0.0, 1.0] value, where 0.0 is -inf dB and 1.0
/// is +12 dB. The mapping uses a linear-in-amplitude floor up to -180 dB, a
/// curved section up to -36 dB, and a linear dB section above that. Unity gain
/// is at [gainParameterZeroDbNormalized].
///
/// This processor is implemented in the engine at:
/// - `engine/src/modules/processors/gain.h`
/// - `engine/src/modules/processors/gain.cpp`
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'GainProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/gain.h',
)
class GainProcessorModel extends _GainProcessorModel
    with Processor, _$GainProcessorModel, _$GainProcessorModelAnthemModelMixin {
  GainProcessorModel({required super.nodeId});

  GainProcessorModel.create({required ProjectEntityIdAllocator idAllocator})
    : super(nodeId: idAllocator.allocateId());

  GainProcessorModel.uninitialized() : super(nodeId: -1);

  factory GainProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$GainProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: audioInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: audioOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: gainPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: gainPortId,
              defaultValue: gainParameterZeroDbNormalized,
            ),
          ),
        ),
      ]),
    );
  }

  static int get audioInputPortId => _GainProcessorModel.audioInputPortId;
  static int get audioOutputPortId => _GainProcessorModel.audioOutputPortId;
  static int get gainPortId => _GainProcessorModel.gainPortId;
}

abstract class _GainProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int audioInputPortId = 0;
  static const int audioOutputPortId = 1;
  static const int gainPortId = 2;

  Id nodeId;

  _GainProcessorModel({required this.nodeId});
}
