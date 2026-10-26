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

import 'package:anthem/logic/service_registry.dart';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/debounced_action.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/balance.dart';
import 'package:anthem/model/processing_graph/processors/control_value_visualization.dart';
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
import 'package:logging/logging.dart';

import 'processors/master_output.dart';
import 'processors/tone_generator.dart';

part 'node.g.dart';

final _log = Logger('processing_graph_node');

/// Initialization status of a node's processor in the current engine.
enum NodeInitializationState {
  /// Initialization has not completed for the current processor instance.
  uninitialized,

  /// Initialization succeeded and its ports and parameter values were applied.
  ready,

  /// Initialization failed. A later attempt may retry it.
  failed,
}

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
       );

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
       );

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
      );

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

  void touchControlInputParameter(NodePortModel port) {
    if (port.nodeId != id ||
        !controlInputPorts.contains(port) ||
        port.config.dataType != NodePortDataType.control ||
        port.config.parameterConfig == null ||
        lastChangedControlPortId == port.id) {
      return;
    }

    lastChangedControlPortId = port.id;
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

  /// ID of this node's retention claim on its opaque processor state file.
  ///
  /// Null means the node has no state file retained by the project. The engine
  /// resolves the ID through project storage and restores the file before
  /// reporting ports and values. Cached parameter values are not replayed into
  /// the plugin.
  @anthemObservable
  String? processorStateRetentionId;

  @anthemObservable
  @hide
  NodeInitializationState _initializationState =
      NodeInitializationState.uninitialized;

  /// The processor's runtime initialization status, independent of graph playback.
  ///
  /// A ready processor has restored any saved state and supplied its current
  /// ports and parameter values. State capture must wait for this confirmation
  /// so it cannot replace saved state with the plugin's initial patch.
  /// Removing the node or stopping the engine resets this status.
  NodeInitializationState get initializationState => _initializationState;

  /// Invalidates captures from before a reset or failed initialization.
  @hide
  int _initializationGeneration = 0;

  @hide
  TimerDebouncedAction? _stateUpdateDebouncedAction;

  /// The control input port ID of the most recently touched parameter.
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
  /// processor. This is debounced to avoid excessive requests.
  void scheduleDebouncedStateUpdate() async {
    _stateUpdateDebouncedAction ??= TimerDebouncedAction(() async {
      try {
        await updateStateFromEngine();
      } catch (error, stack) {
        _log.warning(
          'Could not capture processor state for node $id.',
          error,
          stack,
        );
      }
    }, Duration(seconds: 1));
    _stateUpdateDebouncedAction!.execute();
  }

  @hide
  Future<void>? _stateCaptureCompletion;

  /// Captures the current state, preserving the previous reference on failure.
  /// Concurrent callers are serialized so a save captures edits made while an
  /// earlier background capture was in progress.
  Future<void> updateStateFromEngine() async {
    while (_stateCaptureCompletion != null) {
      await _stateCaptureCompletion;
    }
    // Waiting callers need a completion signal, independent of the outcome.
    // This capture reports errors only through its own returned future.
    final completion = Completer<void>();
    _stateCaptureCompletion = completion.future;
    try {
      await _captureState();
    } finally {
      _stateCaptureCompletion = null;
      completion.complete();
    }
  }

  Future<void> _captureState() async {
    // An unavailable or still-initializing plugin cannot supply authoritative
    // live state. Keep its saved file reference, including when saving the project.
    if (!isThirdPartyPlugin) return;
    final owner = project;
    if (!identical(owner.processingGraph.nodes[id], this) ||
        !owner.engine.isRunning ||
        initializationState != NodeInitializationState.ready) {
      return;
    }

    final generation = _initializationGeneration;
    final path = await owner.engine.processingGraphApi.capturePluginState(id);
    if (generation != _initializationGeneration ||
        !identical(owner.processingGraph.nodes[id], this)) {
      return;
    }
    final previous = processorStateRetentionId;
    if (path == null && previous == null) return;
    final storage = ServiceRegistry.forProject(owner.id).projectStorage;
    if (previous != null && path == storage.resolveRetention(previous)) return;

    // Acquire the new claim before releasing the old one. Saved documents and
    // commands may hold other claims on the same file.
    final replacement = path == null
        ? null
        : storage.retainAssetForProject(path);
    processorStateRetentionId = replacement;
    if (previous != null) storage.releaseAssetFromProject(previous);
    owner.isDirty = true;
  }

  /// Records successful initialization after applying the engine's results.
  ///
  /// The processor has restored any saved state and can supply live captures.
  void markInitialized() {
    _initializationState = NodeInitializationState.ready;
  }

  /// Records a failed attempt and revokes the processor's port confirmations.
  void markInitializationFailed() {
    _invalidateInitialization(NodeInitializationState.failed);
  }

  /// Clears runtime confirmations before a new processor instance is created.
  ///
  /// Used when the engine stops or this node leaves the graph. Saved state
  /// remains available, but capture must wait for the next restoration.
  void resetEngineInitialization() {
    lastChangedControlPortId = null;
    _invalidateInitialization(NodeInitializationState.uninitialized);
  }

  void _invalidateInitialization(NodeInitializationState state) {
    _initializationGeneration++;
    for (final port in (this as NodeModel).getAllPorts()) {
      port.isAvailable = false;
    }
    _initializationState = state;
  }

  void handleEngineStateChange(EngineState state) {
    if (state == EngineState.stopped) resetEngineInitialization();
  }

  @Union([
    BalanceProcessorModel,
    ControlValueVisualizationProcessorModel,
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
  });
}
