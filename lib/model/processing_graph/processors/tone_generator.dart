/*
  Copyright (C) 2024 - 2025 Joshua Wade

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
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'tone_generator.g.dart';

/// A processor that generates a tone.
@AnthemModel.syncedModel(
  cppBehaviorClassName: 'ToneGeneratorProcessor',
  cppBehaviorClassIncludePath: 'modules/processors/tone_generator.h',
)
class ToneGeneratorProcessorModel extends _ToneGeneratorProcessorModel
    with
        _$ToneGeneratorProcessorModel,
        _$ToneGeneratorProcessorModelAnthemModelMixin {
  ToneGeneratorProcessorModel({required super.nodeId});

  ToneGeneratorProcessorModel.uninitialized() : super(nodeId: '');

  factory ToneGeneratorProcessorModel.fromJson(Map<String, dynamic> json) =>
      _$ToneGeneratorProcessorModelAnthemModelMixin.fromJson(json);

  /// The node that this processor represents.
  NodeModel get node => (project.processingGraph.nodes[nodeId])!;

  /// Creates a node for this processor.
  static NodeModel createNode() {
    final id = 'tone-generator-${getId()}';

    return NodeModel(
      id: id,
      processor: ToneGeneratorProcessorModel(nodeId: id),
      audioOutputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: _ToneGeneratorProcessorModel.audioOutputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.audio),
        ),
      ]),
      controlInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: _ToneGeneratorProcessorModel.frequencyPortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
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
          nodeId: id,
          id: _ToneGeneratorProcessorModel.amplitudePortId,
          config: NodePortConfigModel(
            dataType: NodePortDataType.audio,
            parameterConfig: ParameterConfigModel(
              id: _ToneGeneratorProcessorModel.amplitudePortId,
              defaultValue: 0.125,
              minimumValue: 0,
              maximumValue: 1,
              smoothingDurationSeconds: 0.5,
            ),
          ),
        ),
      ]),
      midiInputPorts: AnthemObservableList.of([
        NodePortModel(
          nodeId: id,
          id: _ToneGeneratorProcessorModel.midiInputPortId,
          config: NodePortConfigModel(dataType: NodePortDataType.midi),
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
  static int get midiInputPortId =>
      _ToneGeneratorProcessorModel.midiInputPortId;
}

abstract class _ToneGeneratorProcessorModel with Store, AnthemModelBase {
  static const int audioOutputPortId = 0;

  static const int frequencyPortId = 1;
  static const int amplitudePortId = 2;

  static const int midiInputPortId = 3;

  String nodeId;

  _ToneGeneratorProcessorModel({required this.nodeId});
}
