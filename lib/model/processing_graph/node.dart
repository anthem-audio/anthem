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

import 'dart:async';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/balance.dart';
import 'package:anthem/model/processing_graph/processors/db_meter.dart';
import 'package:anthem/model/processing_graph/processors/gain.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/processor.dart';
import 'package:anthem/model/processing_graph/processors/sequence_automation_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/processing_graph/processors/simple_midi_generator.dart';
import 'package:anthem/model/processing_graph/processors/simple_volume_lfo.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/processing_graph/processors/vst3_processor.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'processors/master_output.dart';
import 'processors/tone_generator.dart';

part 'node.g.dart';

const _controlInputPortIndexBinding = 'controlInputPortIndex';

@AnthemModel(serializable: true, generateModelSync: true)
class NodeOwnerModel extends _NodeOwnerModel
    with _$NodeOwnerModel, _$NodeOwnerModelAnthemModelMixin {
  NodeOwnerModel({super.trackId, super.deviceId}) {
    if (deviceId != null && trackId == null) {
      throw ArgumentError('NodeOwnerModel.deviceId requires trackId.');
    }
  }

  NodeOwnerModel.uninitialized() : super();

  factory NodeOwnerModel.fromJson(Map<String, dynamic> json) =>
      _$NodeOwnerModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeOwnerModel with Store, AnthemModelBase {
  /// The track this node semantically belongs to, if any.
  @anthemObservable
  Id? trackId;

  /// The device this node semantically belongs to, if any.
  ///
  /// If this is set, [trackId] must also be set.
  @anthemObservable
  Id? deviceId;

  _NodeOwnerModel({this.trackId, this.deviceId});
}

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
    super.owner,
  }) : super(
         audioInputPorts: audioInputPorts ?? AnthemObservableList(),
         eventInputPorts: eventInputPorts ?? AnthemObservableList(),
         controlInputPorts: controlInputPorts ?? AnthemObservableList(),
         audioOutputPorts: audioOutputPorts ?? AnthemObservableList(),
         eventOutputPorts: eventOutputPorts ?? AnthemObservableList(),
         controlOutputPorts: controlOutputPorts ?? AnthemObservableList(),
       ) {
    _initParameterTouchTracking();
  }

  NodeModel.create({
    required ProjectEntityIdAllocator idAllocator,
    super.processor,
    AnthemObservableList<NodePortModel>? audioInputPorts,
    AnthemObservableList<NodePortModel>? eventInputPorts,
    AnthemObservableList<NodePortModel>? controlInputPorts,
    AnthemObservableList<NodePortModel>? audioOutputPorts,
    AnthemObservableList<NodePortModel>? eventOutputPorts,
    AnthemObservableList<NodePortModel>? controlOutputPorts,
    super.isThirdPartyPlugin = false,
    super.owner,
  }) : super(
         id: idAllocator.allocateId(),
         audioInputPorts: audioInputPorts ?? AnthemObservableList(),
         eventInputPorts: eventInputPorts ?? AnthemObservableList(),
         controlInputPorts: controlInputPorts ?? AnthemObservableList(),
         audioOutputPorts: audioOutputPorts ?? AnthemObservableList(),
         eventOutputPorts: eventOutputPorts ?? AnthemObservableList(),
         controlOutputPorts: controlOutputPorts ?? AnthemObservableList(),
       ) {
    _initParameterTouchTracking();
  }

  NodeModel.uninitialized()
    : super(
        id: -1,
        audioInputPorts: AnthemObservableList(),
        eventInputPorts: AnthemObservableList(),
        controlInputPorts: AnthemObservableList(),
        audioOutputPorts: AnthemObservableList(),
        eventOutputPorts: AnthemObservableList(),
        controlOutputPorts: AnthemObservableList(),
        processor: null,
        isThirdPartyPlugin: false,
        owner: null,
      ) {
    _initParameterTouchTracking();
  }

  factory NodeModel.fromJson(Map<String, dynamic> json) =>
      _$NodeModelAnthemModelMixin.fromJson(json);

  AnthemObservableList<NodePortModel> getInputPortsByType(
    NodePortDataType dataType,
  ) {
    return switch (dataType) {
      NodePortDataType.audio => audioInputPorts,
      NodePortDataType.event => eventInputPorts,
      NodePortDataType.control => controlInputPorts,
    };
  }

  AnthemObservableList<NodePortModel> getOutputPortsByType(
    NodePortDataType dataType,
  ) {
    return switch (dataType) {
      NodePortDataType.audio => audioOutputPorts,
      NodePortDataType.event => eventOutputPorts,
      NodePortDataType.control => controlOutputPorts,
    };
  }

  NodePortModel getInputPortById(NodePortDataType dataType, int portId) {
    for (final port in getInputPortsByType(dataType)) {
      if (port.id == portId) return port;
    }

    throw Exception('Input port with type $dataType and id $portId not found');
  }

  NodePortModel getOutputPortById(NodePortDataType dataType, int portId) {
    for (final port in getOutputPortsByType(dataType)) {
      if (port.id == portId) return port;
    }

    throw Exception('Output port with type $dataType and id $portId not found');
  }

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

  void _initParameterTouchTracking() {
    onChange(
      (b) => b
          .controlInputPorts()
          .anyElement(bindIndexTo: _controlInputPortIndexBinding)
          .parameterValue(),
      (_, bindings) {
        if (isParameterTouchTrackingSuppressed(this)) {
          return;
        }

        final portIndex = bindings.maybeGet<int>(_controlInputPortIndexBinding);
        if (portIndex == null ||
            portIndex < 0 ||
            portIndex >= controlInputPorts.length) {
          return;
        }

        final changedPort = controlInputPorts[portIndex];
        if (changedPort.config.parameterConfig == null ||
            lastChangedControlPortId == changedPort.id) {
          return;
        }

        lastChangedControlPortId = changedPort.id;
      },
    );
  }
}

final Expando<int> _parameterTouchSuppressionDepths = Expando<int>(
  'parameterTouchSuppressionDepth',
);

bool isParameterTouchTrackingSuppressed(NodeModel node) =>
    (_parameterTouchSuppressionDepths[node] ?? 0) > 0;

extension NodeParameterTouchTracking on NodeModel {
  T withoutParameterTouchTracking<T>(T Function() action) {
    _parameterTouchSuppressionDepths[this] =
        (_parameterTouchSuppressionDepths[this] ?? 0) + 1;

    try {
      return action();
    } finally {
      final nextDepth = (_parameterTouchSuppressionDepths[this] ?? 1) - 1;
      _parameterTouchSuppressionDepths[this] = nextDepth > 0 ? nextDepth : null;
    }
  }
}

abstract class _NodeModel with Store, AnthemModelBase, ProjectModelGetterMixin {
  Id id;

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
  /// from the plugin needs to be serialized into the project model. For these
  /// plugins, this opaque state is the only state restored into the plugin on
  /// engine start; mirrored control port parameter values are not replayed.
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

  /// The control input port ID of the most recently changed plugin parameter.
  @anthemObservable
  @hideButAllowOnChange
  int? lastChangedControlPortId;

  /// Optional semantic owner information for UI/project logic.
  ///
  /// The processing graph remains authoritative for audio topology, while
  /// tracks and devices remain authoritative for structural ownership. This is
  /// denormalized metadata used for fast reverse lookups from node to owner.
  @anthemObservable
  @hideFromCpp
  NodeOwnerModel? owner;

  /// Schedules a state update for the processor.
  ///
  /// This sends a request to the engine to get the current state of the
  /// processor. This is be debounced to avoid excessive requests.
  void scheduleDebouncedStateUpdate() async {
    _stateUpdateDebouncedAction ??= TimerDebouncedAction(() async {
      await updateStateFromEngine(true);
    }, Duration(seconds: 1));
    _stateUpdateDebouncedAction!.execute();
  }

  Future<void> updateStateFromEngine([bool waitForSend = false]) async {
    if (!project.engine.isRunning) {
      return;
    }

    if (waitForSend) {
      await stateIsSentToEngineCompleter.future;
    }

    final newState = await project.engine.processingGraphApi.getPluginState(id);
    if (newState != processorState) {
      processorState = newState;

      // Mark project as dirty
      project.isDirty = true;
    }
  }

  /// Sends the current state of the processor to the engine.
  ///
  /// On engine start, this must be run to ensure the engine has the correct
  /// state of the processor.
  void sendStateToEngine() {
    if (!project.engine.isRunning) {
      return;
    }

    if (processorState.isNotEmpty) {
      project.engine.processingGraphApi.setPluginState(id, processorState);
    }

    if (!stateIsSentToEngineCompleter.isCompleted) {
      stateIsSentToEngineCompleter.complete();
    }
  }

  void handleEngineStateChange(EngineState state) {
    if (state == EngineState.stopped) {
      lastChangedControlPortId = null;
    }

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
    BalanceProcessorModel,
    DbMeterProcessorModel,
    GainProcessorModel,
    LiveEventProviderProcessorModel,
    MasterOutputProcessorModel,
    SequenceAutomationProviderProcessorModel,
    SequenceNoteProviderProcessorModel,
    SimpleMidiGeneratorProcessorModel,
    SimpleVolumeLfoProcessorModel,
    ToneGeneratorProcessorModel,
    UtilityProcessorModel,
    VST3ProcessorModel,
  ])
  Processor? processor;

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
    required this.owner,
  }) {
    onModelFirstAttached(() {
      if (!isThirdPartyPlugin) return;
      if (!project.engine.isRunning) return;

      pluginLoadedCompleter.future.then((_) {
        sendStateToEngine();
      });
    });
  }
}
