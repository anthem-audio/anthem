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
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'simple_midi_generator.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'SimpleMidiGeneratorProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/simple_midi_generator.h',
)
class SimpleMidiGeneratorProcessorModel
    extends _SimpleMidiGeneratorProcessorModel
    with
        _$SimpleMidiGeneratorProcessorModel,
        _$SimpleMidiGeneratorProcessorModelAnthemModelMixin {
  SimpleMidiGeneratorProcessorModel({
    required super.nodeId,
  });

  SimpleMidiGeneratorProcessorModel.uninitialized() : super(nodeId: '');

  factory SimpleMidiGeneratorProcessorModel.fromJson(
          Map<String, dynamic> json) =>
      _$SimpleMidiGeneratorProcessorModelAnthemModelMixin.fromJson(json);

  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  static NodeModel createNode() {
    final id = 'simple-midi-generator-${getId()}';

    return NodeModel(
      id: id,
      processor: SimpleMidiGeneratorProcessorModel(nodeId: id),
      midiOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: midiOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.midi),
        ),
      ]),
    );
  }

  static int get midiOutputPortId =>
      _SimpleMidiGeneratorProcessorModel.midiOutputPortId;
}

abstract class _SimpleMidiGeneratorProcessorModel with Store, AnthemModelBase {
  static const midiOutputPortId = 0;

  String nodeId;

  _SimpleMidiGeneratorProcessorModel({
    required this.nodeId,
  });
}
