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

part 'utility.g.dart';

/// A utility processor, used for basic track gain and stereo balance controls.
///
/// Takes a single audio input and output, plus control inputs for gain and
/// balance.
///
/// The gain control input expects a [0.0, 1.0] value, where 0.0 is -inf dB and
/// 1.0 is +12 dB. The mapping uses a linear-in-amplitude floor up to -180 dB,
/// a curved section up to -36 dB, and a linear dB section above that. Unity gain
/// is at [gainParameterZeroDbNormalized].
///
/// The balance control input expects a normalized [0.0, 1.0] value. The
/// processor maps that to a pan value where 0.0 is full left, 0.5 is center, and
/// 1.0 is full right.
///
/// This processor is implemented in the engine at:
/// - `engine/src/modules/processors/utility.h`
/// - `engine/src/modules/processors/utility.cpp`
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'UtilityProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/utility.h',
)
class UtilityProcessorModel extends _UtilityProcessorModel
    with
        Processor,
        _$UtilityProcessorModel,
        _$UtilityProcessorModelAnthemModelMixin {
  UtilityProcessorModel({required super.nodeId});

  UtilityProcessorModel.create({required ProjectEntityIdAllocator idAllocator})
    : super(nodeId: idAllocator.allocateId());

  UtilityProcessorModel.uninitialized() : super(nodeId: -1);

  factory UtilityProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$UtilityProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: audioInputPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
            channelCount: 2,
          ),
        ),
      ]),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: audioOutputPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
            channelCount: 2,
          ),
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
        NodePortModel(
          nodeId: nodeId,
          id: balancePortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: balancePortId,
              defaultValue: UtilityProcessorModel.panToParameterValue(0.0),
            ),
          ),
        ),
      ]),
    );
  }

  static int get audioInputPortId => _UtilityProcessorModel.audioInputPortId;
  static int get audioOutputPortId => _UtilityProcessorModel.audioOutputPortId;
  static int get gainPortId => _UtilityProcessorModel.gainPortId;
  static int get balancePortId => _UtilityProcessorModel.balancePortId;

  static double parameterValueToPan(double parameterValue) {
    assert(parameterValue >= 0.0 && parameterValue <= 1.0);
    return parameterValue * 2.0 - 1.0;
  }

  static double panToParameterValue(double pan) {
    assert(pan >= -1.0 && pan <= 1.0);
    return (pan + 1.0) * 0.5;
  }

  static String parameterValueToString(double parameterValue) {
    final pan = parameterValueToPan(parameterValue);

    if (pan.abs() < 0.000001) {
      return 'Center';
    }

    return '${(pan * 100).abs().toStringAsFixed(0)}%${pan < 0 ? ' L' : ' R'}';
  }
}

abstract class _UtilityProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int audioInputPortId = 0;
  static const int audioOutputPortId = 1;
  static const int gainPortId = 2;
  static const int balancePortId = 3;

  Id nodeId;

  _UtilityProcessorModel({required this.nodeId});
}
