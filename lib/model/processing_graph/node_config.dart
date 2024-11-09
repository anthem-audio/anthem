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

import 'package:anthem/model/shared/hydratable.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'node_port_config.dart';

part 'node_config.g.dart';

/// Enumerates the possible node processors.
///
/// Each node in the Anthem processing graph must have a processor. This
/// processor is one of two things:
/// - A built-in processor, such as a gain node or a delay node.
/// - A plugin processor, such as a VST3 plugin.
///
/// All built-in processors are enumerated here. Plugin processors are listed
/// here by their type, such as VST3 or AU. When a plugin processor is
/// instantiated, a NodeConfigModel must be generated for it, whose ports are
/// set up in the config to match what the plugin requests. Since this can only
/// be done in the engine, we have a "handshake" process where the UI asks the
/// engine to enumerate the specific plugin's ports, and then the engine sends
/// back the information needed to compose a NodeConfigModel.
@AnthemEnum()
enum ProcessorKind {
  masterOutput,
  gain,
  toneGenerator,
}

@AnthemModel.syncedModel()
class NodeConfigModel extends _NodeConfigModel
    with _$NodeConfigModel, _$NodeConfigModelAnthemModelMixin {
  NodeConfigModel({
    required super.processorKind,
    required super.audioInputs,
    required super.midiInputs,
    required super.controlInputs,
    required super.audioOutputs,
    required super.midiOutputs,
    required super.controlOutputs,
  });

  NodeConfigModel.uninitialized()
      : super(
            processorKind: ProcessorKind.gain,
            audioInputs: AnthemObservableList(),
            midiInputs: AnthemObservableList(),
            controlInputs: AnthemObservableList(),
            audioOutputs: AnthemObservableList(),
            midiOutputs: AnthemObservableList(),
            controlOutputs: AnthemObservableList());

  factory NodeConfigModel.fromJson(Map<String, dynamic> json) =>
      _$NodeConfigModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeConfigModel extends Hydratable with Store, AnthemModelBase {
  ProcessorKind processorKind;

  AnthemObservableList<NodePortConfigModel> audioInputs;
  AnthemObservableList<NodePortConfigModel> midiInputs;
  AnthemObservableList<NodePortConfigModel> controlInputs;

  AnthemObservableList<NodePortConfigModel> audioOutputs;
  AnthemObservableList<NodePortConfigModel> midiOutputs;
  AnthemObservableList<NodePortConfigModel> controlOutputs;

  _NodeConfigModel({
    required this.processorKind,
    required this.audioInputs,
    required this.midiInputs,
    required this.controlInputs,
    required this.audioOutputs,
    required this.midiOutputs,
    required this.controlOutputs,
  }) {
    isHydrated = true;
    (this as _$NodeConfigModelAnthemModelMixin).init();
  }
}
