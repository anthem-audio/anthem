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

import 'dart:async';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/processing_graph/processors/simple_midi_generator.dart';
import 'package:anthem/model/processing_graph/processors/simple_volume_lfo.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
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
    super.isThirdPartyPlugin = false,
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
        isThirdPartyPlugin: false,
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

  /// Whether this node is a third-party plugin.
  ///
  /// If this is a third-party plugin, its processor will need to save and load
  /// serialized plugin state, so if this is true then it will trigger machinery
  /// to handle that.
  bool isThirdPartyPlugin;

  /// Serialized state of the processor.
  ///
  /// This is currently only used for third-party plugins, where arbitrary state
  /// from the plugin needs to be serialized into the project model.
  @hideFromCpp
  String processorState = '';

  /// Whether the plugin has been loaded in the engine, if applicable.
  ///
  /// This is currently only used for third-party plugins, where the plugin
  /// needs to be loaded in the engine before we can send or receive state.
  @hide
  Completer<void> pluginLoadedCompleter = Completer<void>();

  /// Whether this model's state has been sent to the engine yet.
  ///
  /// When a node is first created, it has a blank state. However, if a node is
  /// loaded from a project, it may have a state that was serialized from a
  /// previous session, saved in [processorState]. Before we can ever load the
  /// live state from the plugin in the engine, we need to first send the state
  /// that we have; otherwise we will overwrite our state and the plugin will
  /// remain in its initial state.
  ///
  /// This also applies to stopping and starting the engine. We will keep the
  /// state here up-to-date with the latest from the engine, and if the engine
  /// stops or crashes and is then restarted, we will need to make sure we send
  /// our state to the engine before we start reading it back again.
  @hide
  Completer<void> stateIsSentToEngineCompleter = Completer<void>();

  @hide
  TimerDebouncedAction? _stateUpdateDebouncedAction;

  /// Schedules a state update for the processor.
  ///
  /// This sends a request to the engine to get the current state of the
  /// processor. This is be debounced to avoid excessive requests.
  void scheduleDebouncedStateUpdate() async {
    _stateUpdateDebouncedAction ??= TimerDebouncedAction(() async {
      await updateStateFromEngine();
    }, Duration(seconds: 1));
    _stateUpdateDebouncedAction!.execute();
  }

  Future<void> updateStateFromEngine() async {
    if (!project.engine.isRunning) {
      return;
    }

    await stateIsSentToEngineCompleter.future;

    processorState = await project.engine.processingGraphApi.getPluginState(id);
  }

  /// Sends the current state of the processor to the engine.
  ///
  /// On engine start, this must be run to ensure the engine has the correct
  /// state of the processor.
  void sendStateToEngine() {
    if (!project.engine.isRunning) {
      return;
    }

    // Send the current state of the processor to the engine.
    project.engine.processingGraphApi.setPluginState(id, processorState);
    stateIsSentToEngineCompleter.complete();
  }

  void handleEngineStateChange(EngineState state) {
    if (!isThirdPartyPlugin) return;

    if (state == EngineState.stopped) {
      stateIsSentToEngineCompleter = Completer<void>();
      pluginLoadedCompleter = Completer<void>();
    } else if (state == EngineState.running) {
      pluginLoadedCompleter.future.then((_) {
        sendStateToEngine();
      });
    }
  }

  @Union([
    GainProcessorModel,
    LiveEventProviderProcessorModel,
    MasterOutputProcessorModel,
    SequenceNoteProviderProcessorModel,
    SimpleMidiGeneratorProcessorModel,
    SimpleVolumeLfoProcessorModel,
    ToneGeneratorProcessorModel,
    VST3ProcessorModel,
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
    required this.isThirdPartyPlugin,
  }) {
    onModelAttached(() {
      if (!isThirdPartyPlugin) return;
      if (!project.engine.isRunning) return;

      pluginLoadedCompleter.future.then((_) {
        sendStateToEngine();
      });
    });
  }
}
