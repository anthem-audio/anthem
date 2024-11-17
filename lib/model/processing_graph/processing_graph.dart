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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/processors/master_output.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'node.dart';
import 'node_connection.dart';
import 'processors/tone_generator.dart';

part 'processing_graph.g.dart';

@AnthemModel.syncedModel()
class ProcessingGraphModel extends _ProcessingGraphModel
    with _$ProcessingGraphModel, _$ProcessingGraphModelAnthemModelMixin {
  ProcessingGraphModel.uninitialized();

  ProcessingGraphModel() {
    // Set up the master output node
    final masterOutputNode = MasterOutputProcessorModel.createNode();
    nodes[masterOutputNode.id] = masterOutputNode;
    masterOutput = MasterOutputProcessorModel(nodeId: masterOutputNode.id);

    // For testing purposes, connect a tone generator to the master output
    final toneGeneratorNode = ToneGeneratorProcessorModel.createNode();
    nodes[toneGeneratorNode.id] = toneGeneratorNode;
    toneGenerator = ToneGeneratorProcessorModel(nodeId: toneGeneratorNode.id);

    final connectionId = getID();
    connections[connectionId] = NodeConnectionModel(
      id: connectionId,
      sourceNodeId: toneGeneratorNode.id,
      sourcePortId: toneGeneratorNode.audioOutputPorts[0].id,
      destinationNodeId: masterOutputNode.id,
      destinationPortId: masterOutputNode.audioInputPorts[0].id,
    );
  }

  factory ProcessingGraphModel.fromJson(Map<String, dynamic> json) =>
      _$ProcessingGraphModelAnthemModelMixin.fromJson(json);
}

abstract class _ProcessingGraphModel with Store, AnthemModelBase {
  @anthemObservable
  AnthemObservableMap<String, NodeModel> nodes = AnthemObservableMap();

  @anthemObservable
  AnthemObservableMap<String, NodeConnectionModel> connections =
      AnthemObservableMap();

  @anthemObservable
  late MasterOutputProcessorModel masterOutput;

  @AnthemObservable()
  late ToneGeneratorProcessorModel toneGenerator;
}
