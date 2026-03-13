/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

part 'tone_generator.g.dart';

/// A processor that generates a tone.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'ToneGeneratorProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/tone_generator.h',
)
class ToneGeneratorProcessorModel extends _ToneGeneratorProcessorModel
    with
        Processor,
        _$ToneGeneratorProcessorModel,
        _$ToneGeneratorProcessorModelAnthemModelMixin {
  ToneGeneratorProcessorModel({required super.nodeId});

  ToneGeneratorProcessorModel.create({
    required ProjectEntityIdAllocator idAllocator,
  }) : super(nodeId: idAllocator.allocateId());

  ToneGeneratorProcessorModel.uninitialized() : super(nodeId: -1);

  factory ToneGeneratorProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ToneGeneratorProcessorModelAnthemModelMixin.fromJson(json);

  @override
  NodeModel createNode() {
    return NodeModel(
      id: nodeId,
      processor: this,
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: _ToneGeneratorProcessorModel.audioOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: _ToneGeneratorProcessorModel.frequencyPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: _ToneGeneratorProcessorModel.frequencyPortId,
              defaultValue: 440,
              minimumValue: 1,
              maximumValue: 22500,
              smoothingDurationSeconds: 0.5,
            ),
          ),
        ),
        NodePortModel(
          nodeId: nodeId,
          id: _ToneGeneratorProcessorModel.amplitudePortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.control,
            parameterConfig: ParameterConfigModel(
              id: _ToneGeneratorProcessorModel.amplitudePortId,
              defaultValue: 0.75,
              minimumValue: 0,
              maximumValue: 1,
              smoothingDurationSeconds: 0.5,
            ),
          ),
        ),
      ]),
      eventInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: nodeId,
          id: _ToneGeneratorProcessorModel.eventInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.event),
        ),
      ]),
    );
  }

  static int get audioOutputPortId =>
      _ToneGeneratorProcessorModel.audioOutputPortId;
  static int get frequencyPortId =>
      _ToneGeneratorProcessorModel.frequencyPortId;
  static int get amplitudePortId =>
      _ToneGeneratorProcessorModel.amplitudePortId;
  static int get eventInputPortId =>
      _ToneGeneratorProcessorModel.eventInputPortId;
}

abstract class _ToneGeneratorProcessorModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  static const int audioOutputPortId = 0;

  static const int frequencyPortId = 1;
  static const int amplitudePortId = 2;

  static const int eventInputPortId = 3;

  Id nodeId;

  _ToneGeneratorProcessorModel({required this.nodeId});
}
