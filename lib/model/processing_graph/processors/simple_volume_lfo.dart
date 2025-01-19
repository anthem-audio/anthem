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
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_config.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'simple_volume_lfo.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'SimpleVolumeLfoProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/simple_volume_lfo.h',
)
class SimpleVolumeLfoProcessorModel extends _SimpleVolumeLfoProcessorModel
    with
        _$SimpleVolumeLfoProcessorModel,
        _$SimpleVolumeLfoProcessorModelAnthemModelMixin {
  SimpleVolumeLfoProcessorModel({
    required super.nodeId,
  });

  SimpleVolumeLfoProcessorModel.uninitialized() : super(nodeId: '');

  factory SimpleVolumeLfoProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$SimpleVolumeLfoProcessorModelAnthemModelMixin.fromJson(json);

  /// The node that this processor represents.
  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  /// Creates a node for this processor.
  static NodeModel createNode() {
    final nodeId = 'simple-volume-lfo-${getId()}';

    return NodeModel(
      config: NodeConfigModel(),
      id: nodeId,
      processor: SimpleVolumeLfoProcessorModel(nodeId: nodeId),
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
          ),
          id: audioInputPortId,
          nodeId: nodeId,
        ),
      ]),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
          ),
          id: audioOutputPortId,
          nodeId: nodeId,
        ),
      ]),
    );
  }

  static int get audioInputPortId =>
      _SimpleVolumeLfoProcessorModel.audioInputPortId;
  static int get audioOutputPortId =>
      _SimpleVolumeLfoProcessorModel.audioOutputPortId;
}

abstract class _SimpleVolumeLfoProcessorModel with Store, AnthemModelBase {
  static const int audioInputPortId = 0;
  static const int audioOutputPortId = 1;

  String nodeId;

  _SimpleVolumeLfoProcessorModel({required this.nodeId});
}
