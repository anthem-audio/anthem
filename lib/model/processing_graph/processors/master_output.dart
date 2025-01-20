/*
  Copyright (C) 2024 Joshua Wade

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

import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'master_output.g.dart';

/// Defines a processor that is the final output of the processing graph.
///
/// Note that this only links to the actual node in the processing graph. As
/// this is a synced model, the actual audio implementation attaches to the
/// generated version of this class in the engine.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'MasterOutputProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/master_output.h',
)
class MasterOutputProcessorModel extends _MasterOutputProcessorModel
    with
        _$MasterOutputProcessorModel,
        _$MasterOutputProcessorModelAnthemModelMixin {
  MasterOutputProcessorModel.uninitialized() : super(nodeId: '');

  MasterOutputProcessorModel({required super.nodeId});

  factory MasterOutputProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$MasterOutputProcessorModelAnthemModelMixin.fromJson(json);

  /// The node that this processor represents.
  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  /// Creates a node for this processor.
  static NodeModel createNode(String nodeId) {
    return NodeModel(
      id: nodeId,
      processor: MasterOutputProcessorModel(nodeId: nodeId),
      audioInputPorts: AnthemObservableList.of([
        NodePortModel(
          id: _MasterOutputProcessorModel.inputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
          nodeId: nodeId,
        ),
      ]),
    );
  }
}

abstract class _MasterOutputProcessorModel with Store, AnthemModelBase {
  static const int inputPortId = 0;

  late String nodeId;

  _MasterOutputProcessorModel({required this.nodeId});
}
