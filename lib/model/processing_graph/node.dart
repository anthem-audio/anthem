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
import 'package:anthem/model/processing_graph/node_config.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'node.g.dart';

@AnthemModel.syncedModel()
class NodeModel extends _NodeModel
    with _$NodeModel, _$NodeModelAnthemModelMixin {
  NodeModel(
      {required super.id,
      required super.config,
      AnthemObservableList<NodePortModel>? audioInputPorts,
      AnthemObservableList<NodePortModel>? midiInputPorts,
      AnthemObservableList<NodePortModel>? controlInputPorts,
      AnthemObservableList<NodePortModel>? audioOutputPorts,
      AnthemObservableList<NodePortModel>? midiOutputPorts,
      AnthemObservableList<NodePortModel>? controlOutputPorts})
      : super(
          audioInputPorts: audioInputPorts ?? AnthemObservableList(),
          midiInputPorts: midiInputPorts ?? AnthemObservableList(),
          controlInputPorts: controlInputPorts ?? AnthemObservableList(),
          audioOutputPorts: audioOutputPorts ?? AnthemObservableList(),
          midiOutputPorts: midiOutputPorts ?? AnthemObservableList(),
          controlOutputPorts: controlOutputPorts ?? AnthemObservableList(),
        ) {
    init();
  }

  NodeModel.uninitialized()
      : super(
          id: '',
          config: NodeConfigModel.uninitialized(),
          audioInputPorts: AnthemObservableList(),
          midiInputPorts: AnthemObservableList(),
          controlInputPorts: AnthemObservableList(),
          audioOutputPorts: AnthemObservableList(),
          midiOutputPorts: AnthemObservableList(),
          controlOutputPorts: AnthemObservableList(),
        ) {
    init();
  }

  void init() {}

  factory NodeModel.fromJson(Map<String, dynamic> json) =>
      _$NodeModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeModel with Store, AnthemModelBase {
  String id;

  NodeConfigModel config;

  AnthemObservableList<NodePortModel> audioInputPorts;
  AnthemObservableList<NodePortModel> midiInputPorts;
  AnthemObservableList<NodePortModel> controlInputPorts;

  AnthemObservableList<NodePortModel> audioOutputPorts;
  AnthemObservableList<NodePortModel> midiOutputPorts;
  AnthemObservableList<NodePortModel> controlOutputPorts;

  _NodeModel({
    required this.id,
    required this.config,
    required this.audioInputPorts,
    required this.midiInputPorts,
    required this.controlInputPorts,
    required this.audioOutputPorts,
    required this.midiOutputPorts,
    required this.controlOutputPorts,
  });
}
