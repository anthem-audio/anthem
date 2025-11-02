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

part 'gain.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'GainProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/gain.h',
)
class GainProcessorModel extends _GainProcessorModel
    with _$GainProcessorModel, _$GainProcessorModelAnthemModelMixin {
  GainProcessorModel({required super.nodeId});

  GainProcessorModel.uninitialized() : super(nodeId: '');

  factory GainProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$GainProcessorModelAnthemModelMixin.fromJson(json);

  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  static NodeModel createNode() {
    final id = 'gain-${getId()}';

    return NodeModel(
      id: id,
      processor: GainProcessorModel(nodeId: id),
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
          id: gainPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: gainPortId,
              defaultValue: 0.75,
              minimumValue: 0.0,
              maximumValue: 1.0,
              smoothingDurationSeconds: 0.01,
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

  String nodeId;

  _GainProcessorModel({required this.nodeId});
}
