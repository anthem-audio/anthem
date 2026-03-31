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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'balance.g.dart';

/// A balance processor, used for basic stereo balancing controls.
///
/// Takes a single audio input and output, and a control input for balance.
///
/// The control input expects a normalized [0.0, 1.0] value. The processor maps
/// that to a pan value where 0.0 is full left, 0.5 is center, and 1.0 is full
/// right.
///
/// This processor is implemented in the engine at:
/// - `engine/src/modules/processors/balance.h`
/// - `engine/src/modules/processors/balance.cpp`
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'BalanceProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/balance.h',
)
class BalanceProcessorModel extends _BalanceProcessorModel
    with
        Processor,
        _$BalanceProcessorModel,
        _$BalanceProcessorModelAnthemModelMixin {
  BalanceProcessorModel({required super.nodeId});

  BalanceProcessorModel.create({required ProjectEntityIdAllocator idAllocator})
    : super(nodeId: idAllocator.allocateId());

  BalanceProcessorModel.uninitialized() : super(nodeId: -1);

  factory BalanceProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$BalanceProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this..nodeId = nodeId,
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
          id: balancePortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: balancePortId,
              defaultValue: BalanceProcessorModel.panToParameterValue(0.0),
              smoothingDurationSeconds: 0.01,
            ),
          ),
        ),
      ]),
    );
  }

  static int get audioInputPortId => _BalanceProcessorModel.audioInputPortId;
  static int get audioOutputPortId => _BalanceProcessorModel.audioOutputPortId;
  static int get balancePortId => _BalanceProcessorModel.balancePortId;

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

abstract class _BalanceProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id nodeId;

  _BalanceProcessorModel({required this.nodeId});

  static const int audioInputPortId = 0;
  static const int audioOutputPortId = 1;
  static const int balancePortId = 2;
}
