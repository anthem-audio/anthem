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

import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/simple_midi_generator.dart';
import 'package:anthem/model/processing_graph/processors/simple_volume_lfo.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'processors/master_output.dart';
import 'processors/tone_generator.dart';

part 'node.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'Node',
  cppBehaviorClassIncludePath: 'modules/processing_graph/model/node.h',
)
class NodeModel extends _NodeModel
    with _$NodeModel, _$NodeModelAnthemModelMixin {
  NodeModel({
    required super.id,
    super.processor,
    AnthemObservableList<NodePortModel>? audioInputPorts,
    AnthemObservableList<NodePortModel>? eventInputPorts,
    AnthemObservableList<NodePortModel>? controlInputPorts,
    AnthemObservableList<NodePortModel>? audioOutputPorts,
    AnthemObservableList<NodePortModel>? eventOutputPorts,
    AnthemObservableList<NodePortModel>? controlOutputPorts,
  }) : super(
         audioInputPorts: audioInputPorts ?? AnthemObservableList(),
         eventInputPorts: eventInputPorts ?? AnthemObservableList(),
         controlInputPorts: controlInputPorts ?? AnthemObservableList(),
         audioOutputPorts: audioOutputPorts ?? AnthemObservableList(),
         eventOutputPorts: eventOutputPorts ?? AnthemObservableList(),
         controlOutputPorts: controlOutputPorts ?? AnthemObservableList(),
       );

  NodeModel.uninitialized()
    : super(
        id: '',
        audioInputPorts: AnthemObservableList(),
        eventInputPorts: AnthemObservableList(),
        controlInputPorts: AnthemObservableList(),
        audioOutputPorts: AnthemObservableList(),
        eventOutputPorts: AnthemObservableList(),
        controlOutputPorts: AnthemObservableList(),
        processor: null,
      );

  factory NodeModel.fromJson(Map<String, dynamic> json) =>
      _$NodeModelAnthemModelMixin.fromJson(json);

  NodePortModel getPortById(int portId) {
    for (final port in audioInputPorts) {
      if (port.id == portId) return port;
    }
    for (final port in eventInputPorts) {
      if (port.id == portId) return port;
    }
    for (final port in controlInputPorts) {
      if (port.id == portId) return port;
    }
    for (final port in audioOutputPorts) {
      if (port.id == portId) return port;
    }
    for (final port in eventOutputPorts) {
      if (port.id == portId) return port;
    }
    for (final port in controlOutputPorts) {
      if (port.id == portId) return port;
    }
    throw Exception('Port with id $portId not found');
  }

  Iterable<NodePortModel> getAllPorts() {
    return audioInputPorts
        .followedBy(audioOutputPorts)
        .followedBy(eventInputPorts)
        .followedBy(eventOutputPorts)
        .followedBy(controlInputPorts)
        .followedBy(controlOutputPorts);
  }
}

abstract class _NodeModel with Store, AnthemModelBase {
  String id;

  AnthemObservableList<NodePortModel> audioInputPorts;
  AnthemObservableList<NodePortModel> eventInputPorts;
  AnthemObservableList<NodePortModel> controlInputPorts;

  AnthemObservableList<NodePortModel> audioOutputPorts;
  AnthemObservableList<NodePortModel> eventOutputPorts;
  AnthemObservableList<NodePortModel> controlOutputPorts;

  @Union([
    GainProcessorModel,
    MasterOutputProcessorModel,
    SimpleMidiGeneratorProcessorModel,
    SimpleVolumeLfoProcessorModel,
    ToneGeneratorProcessorModel,
  ])
  Object? processor;

  _NodeModel({
    required this.id,
    required this.audioInputPorts,
    required this.eventInputPorts,
    required this.controlInputPorts,
    required this.audioOutputPorts,
    required this.eventOutputPorts,
    required this.controlOutputPorts,
    required this.processor,
  });
}
