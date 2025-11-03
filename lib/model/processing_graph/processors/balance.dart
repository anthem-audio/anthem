/*
  Copyright (C) 2025 Joshua Wade

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
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'balance.g.dart';

/// A balance processor, used for basic stereo balancing controls.
///
/// Takes a single audio input and output, and a control input for balance.
///
/// The control input expects a [-1.0, 1.0] value, where -1.0 is full left,
/// 0.0 is center, 1.0 is full right.
///
/// This processor is implemented in the engine at:
/// - `engine/src/modules/processors/balance.h`
/// - `engine/src/modules/processors/balance.cpp`
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'BalanceProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/balance.h',
)
class BalanceProcessorModel extends _BalanceProcessorModel
    with _$BalanceProcessorModel, _$BalanceProcessorModelAnthemModelMixin {
  BalanceProcessorModel({required super.nodeId});

  BalanceProcessorModel.uninitialized() : super(nodeId: '');

  factory BalanceProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$BalanceProcessorModelAnthemModelMixin.fromJson(json);

  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  static NodeModel createNode() {
    final id = 'balance-${getId()}';
    return NodeModel(
      id: id,
      processor: BalanceProcessorModel(nodeId: id),
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: audioInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: audioOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: balancePortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: balancePortId,
              defaultValue: 0.0,
              minimumValue: -1.0,
              maximumValue: 1.0,
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
}

abstract class _BalanceProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  String nodeId;

  _BalanceProcessorModel({required this.nodeId});

  static const int audioInputPortId = 0;
  static const int audioOutputPortId = 1;
  static const int balancePortId = 2;
}
