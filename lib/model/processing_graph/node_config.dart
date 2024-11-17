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
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'node_port_config.dart';

part 'node_config.g.dart';

@AnthemModel.syncedModel()
class NodeConfigModel extends _NodeConfigModel
    with _$NodeConfigModel, _$NodeConfigModelAnthemModelMixin {
  NodeConfigModel({
    AnthemObservableList<NodePortConfigModel>? audioInputs,
    AnthemObservableList<NodePortConfigModel>? midiInputs,
    AnthemObservableList<NodePortConfigModel>? controlInputs,
    AnthemObservableList<NodePortConfigModel>? audioOutputs,
    AnthemObservableList<NodePortConfigModel>? midiOutputs,
    AnthemObservableList<NodePortConfigModel>? controlOutputs,
  }) : super(
          audioInputs: audioInputs ?? AnthemObservableList(),
          midiInputs: midiInputs ?? AnthemObservableList(),
          controlInputs: controlInputs ?? AnthemObservableList(),
          audioOutputs: audioOutputs ?? AnthemObservableList(),
          midiOutputs: midiOutputs ?? AnthemObservableList(),
          controlOutputs: controlOutputs ?? AnthemObservableList(),
        );

  NodeConfigModel.uninitialized()
      : super(
            audioInputs: AnthemObservableList(),
            midiInputs: AnthemObservableList(),
            controlInputs: AnthemObservableList(),
            audioOutputs: AnthemObservableList(),
            midiOutputs: AnthemObservableList(),
            controlOutputs: AnthemObservableList());

  factory NodeConfigModel.fromJson(Map<String, dynamic> json) =>
      _$NodeConfigModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeConfigModel with Store, AnthemModelBase {
  AnthemObservableList<NodePortConfigModel> audioInputs;
  AnthemObservableList<NodePortConfigModel> midiInputs;
  AnthemObservableList<NodePortConfigModel> controlInputs;

  AnthemObservableList<NodePortConfigModel> audioOutputs;
  AnthemObservableList<NodePortConfigModel> midiOutputs;
  AnthemObservableList<NodePortConfigModel> controlOutputs;

  _NodeConfigModel({
    required this.audioInputs,
    required this.midiInputs,
    required this.controlInputs,
    required this.audioOutputs,
    required this.midiOutputs,
    required this.controlOutputs,
  });
}
