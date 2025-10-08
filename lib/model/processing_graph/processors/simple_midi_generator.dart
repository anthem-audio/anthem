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
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
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
  SimpleMidiGeneratorProcessorModel({required super.nodeId});

  SimpleMidiGeneratorProcessorModel.uninitialized() : super(nodeId: '');

  factory SimpleMidiGeneratorProcessorModel.fromJson(
    Map<String, dynamic> json,
  ) => _$SimpleMidiGeneratorProcessorModelAnthemModelMixin.fromJson(json);

  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  static NodeModel createNode() {
    final id = 'simple-midi-generator-${getId()}';

    return NodeModel(
      id: id,
      processor: SimpleMidiGeneratorProcessorModel(nodeId: id),
      eventOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: eventOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
    );
  }

  static int get eventOutputPortId =>
      _SimpleMidiGeneratorProcessorModel.eventOutputPortId;
}

abstract class _SimpleMidiGeneratorProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const eventOutputPortId = 0;

  String nodeId;

  _SimpleMidiGeneratorProcessorModel({required this.nodeId});
}
