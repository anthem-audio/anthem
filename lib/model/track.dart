/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processors/db_meter.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';

part 'track.g.dart';

@AnthemModel(serializable: true, generateModelSync: true)
class TrackAutomationTargetModel extends _TrackAutomationTargetModel
    with
        _$TrackAutomationTargetModel,
        _$TrackAutomationTargetModelAnthemModelMixin {
  TrackAutomationTargetModel({required super.nodeId, required super.portId});

  TrackAutomationTargetModel.uninitialized() : super(nodeId: -1, portId: -1);

  factory TrackAutomationTargetModel.fromJson(Map<String, dynamic> json) =>
      _$TrackAutomationTargetModelAnthemModelMixin.fromJson(json);
}

abstract class _TrackAutomationTargetModel with Store, AnthemModelBase {
  /// The processing graph node that owns the automated parameter.
  @anthemObservable
  Id nodeId;

  /// The control input port ID for the automated parameter.
  @anthemObservable
  int portId;

  _TrackAutomationTargetModel({required this.nodeId, required this.portId});
}

@AnthemModel.syncedModel()
class TrackProcessingModel extends _TrackProcessingModel
    with _$TrackProcessingModel, _$TrackProcessingModelAnthemModelMixin {
  TrackProcessingModel()
    : super(
        devices: AnthemObservableList(),
        deviceRoutingConnectionIds: AnthemObservableList(),
      );

  TrackProcessingModel.uninitialized()
    : super(
        devices: AnthemObservableList(),
        deviceRoutingConnectionIds: AnthemObservableList(),
      );

  factory TrackProcessingModel.fromJson(Map<String, dynamic> json) =>
      _$TrackProcessingModelAnthemModelMixin.fromJson(json);

  static List<String> buildDbMeterVisualizationIds(Id trackId) {
    return ['db-meter-$trackId-left', 'db-meter-$trackId-right'];
  }
}

abstract class _TrackProcessingModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  @anthemObservable
  Id? utilityNodeId;

  NodeModel? get utilityNode => project.processingGraph.nodes[utilityNodeId];

  @anthemObservable
  Id? dbMeterNodeId;

  NodeModel? get dbMeterNode => project.processingGraph.nodes[dbMeterNodeId];

  @anthemObservable
  AnthemObservableList<DeviceModel> devices;

  /// Generated rack routing connection IDs.
  ///
  /// These connections are derived from [devices] and should be rebuilt rather
  /// than edited as device-owned graph state.
  @anthemObservable
  AnthemObservableList<Id> deviceRoutingConnectionIds;

  /// Sequence note provider node assigned to this track.
  ///
  /// This node is the sequencer -> processing graph interface for track notes.
  @anthemObservable
  Id? sequenceNoteProviderNodeId;

  /// Live event provider node assigned to this track.
  ///
  /// This node allows direct note audition for this track's instrument.
  @anthemObservable
  Id? liveEventProviderNodeId;

  NodeModel? get sequenceNoteProviderNode =>
      project.processingGraph.nodes[sequenceNoteProviderNodeId];

  NodeModel? get liveEventProviderNode =>
      project.processingGraph.nodes[liveEventProviderNodeId];

  Id get audioOutputNodeId => utilityNodeId!;
  int get audioOutputPortId => UtilityProcessorModel.audioOutputPortId;

  TrackModel get track => getFirstAncestorOfType<TrackModel>();

  List<Id> getOwnedNodeIds() {
    return [
      utilityNodeId,
      dbMeterNodeId,
      sequenceNoteProviderNodeId,
      liveEventProviderNodeId,
      ...devices.expand((device) => device.nodeIds),
    ].nonNulls.toList();
  }

  /// Visualization IDs used for this track's stereo dB meter.
  List<String> get dbMeterVisualizationIds =>
      TrackProcessingModel.buildDbMeterVisualizationIds(track.id);

  void createAndRegisterNodes({
    required TrackModel track,
    required ProjectModel project,
    required ProjectEntityIdAllocator idAllocator,
  }) {
    final trackId = track.id;

    final utilityNode = UtilityProcessorModel.create(
      idAllocator: idAllocator,
    ).createNode();
    utilityNode.owner = NodeOwnerModel(trackId: trackId);
    utilityNodeId = utilityNode.id;
    project.processingGraph.addNode(utilityNode);

    final dbMeterNode = DbMeterProcessorModel.create(
      idAllocator: idAllocator,
      publishEverySamples: 1024,
      visualizationIds: TrackProcessingModel.buildDbMeterVisualizationIds(
        trackId,
      ),
    ).createNode();
    dbMeterNode.owner = NodeOwnerModel(trackId: trackId);
    dbMeterNodeId = dbMeterNode.id;
    project.processingGraph.addNode(dbMeterNode);

    project.processingGraph.addConnection(
      NodeConnectionModel(
        idAllocator: idAllocator,
        sourceNodeId: utilityNodeId!,
        sourcePortId: UtilityProcessorModel.audioOutputPortId,
        destinationNodeId: dbMeterNodeId!,
        destinationPortId: DbMeterProcessorModel.audioInputPortId,
        dataType: NodePortDataType.audio,
      ),
    );

    final sequenceNoteProviderNode = SequenceNoteProviderProcessorModel.create(
      idAllocator: idAllocator,
      trackId: trackId,
    ).createNode();
    sequenceNoteProviderNode.owner = NodeOwnerModel(trackId: trackId);
    sequenceNoteProviderNodeId = sequenceNoteProviderNode.id;
    project.processingGraph.addNode(sequenceNoteProviderNode);

    final liveEventProviderNode = LiveEventProviderProcessorModel.create(
      idAllocator: idAllocator,
    ).createNode();
    liveEventProviderNode.owner = NodeOwnerModel(trackId: trackId);
    liveEventProviderNodeId = liveEventProviderNode.id;
    project.processingGraph.addNode(liveEventProviderNode);
  }

  _TrackProcessingModel({
    required this.devices,
    required this.deviceRoutingConnectionIds,
  }) : utilityNodeId = null,
       dbMeterNodeId = null,
       sequenceNoteProviderNodeId = null,
       liveEventProviderNodeId = null,
       super();
}

@AnthemModel(serializable: true, generateModelSync: true)
class TrackAutomationProcessingModel extends _TrackAutomationProcessingModel
    with
        _$TrackAutomationProcessingModel,
        _$TrackAutomationProcessingModelAnthemModelMixin {
  TrackAutomationProcessingModel()
    : super(
        devices: AnthemObservableList(),
        deviceRoutingConnectionIds: AnthemObservableList(),
      );

  TrackAutomationProcessingModel.uninitialized()
    : super(
        devices: AnthemObservableList(),
        deviceRoutingConnectionIds: AnthemObservableList(),
      );

  factory TrackAutomationProcessingModel.fromJson(Map<String, dynamic> json) =>
      _$TrackAutomationProcessingModelAnthemModelMixin.fromJson(json);
}

abstract class _TrackAutomationProcessingModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  /// Sequence automation provider node assigned to this automation lane.
  @anthemObservable
  Id? sequenceAutomationProviderNodeId;

  NodeModel? get sequenceAutomationProviderNode =>
      project.processingGraph.nodes[sequenceAutomationProviderNodeId];

  @anthemObservable
  AnthemObservableList<DeviceModel> devices;

  /// Generated automation device routing connection IDs.
  ///
  /// These connections are derived from [devices] and should be rebuilt rather
  /// than edited as device-owned graph state.
  @anthemObservable
  AnthemObservableList<Id> deviceRoutingConnectionIds;

  TrackModel get track => getFirstAncestorOfType<TrackModel>();

  List<Id> getOwnedNodeIds() {
    return [
      sequenceAutomationProviderNodeId,
      ...devices.expand((device) => device.nodeIds),
    ].nonNulls.toList();
  }

  _TrackAutomationProcessingModel({
    required this.devices,
    required this.deviceRoutingConnectionIds,
  }) : sequenceAutomationProviderNodeId = null,
       super();
}

@AnthemModel.syncedModel()
class TrackModel extends _TrackModel
    with _$TrackModel, _$TrackModelAnthemModelMixin {
  TrackModel({
    required ProjectEntityIdAllocator idAllocator,
    required super.name,
    required super.color,
    required super.type,
    super.automationTarget,
  }) : super(
         id: idAllocator.allocateId(),
         processing: type == TrackType.automationLane
             ? null
             : TrackProcessingModel(),
         automationProcessing: type == TrackType.automationLane
             ? TrackAutomationProcessingModel()
             : null,
       );

  TrackModel.uninitialized()
    : super(
        id: -1,
        name: '',
        color: AnthemColor.uninitialized(),
        type: .normal,
        automationTarget: null,
        processing: null,
        automationProcessing: null,
      );

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelAnthemModelMixin.fromJson(json);
}

@AnthemEnum()
enum TrackType { normal, group, automationLane }

abstract class _TrackModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  /// This track's ID.
  ///
  /// This ID must be used to key this track in [ProjectModel.tracks].
  Id id;

  /// The human-readable name of this track.
  ///
  /// Defaults to something like "Track 1".
  @anthemObservable
  String name;

  /// The color of this track.
  @anthemObservable
  AnthemColor color;

  /// The type of this track.
  ///
  /// Normal and group tracks participate in audio/event processing. Automation
  /// lanes own automation processing instead.
  @anthemObservable
  TrackType type;

  /// IDs of the child tracks of this track.
  ///
  /// If this track is a group track, it likely has child tracks. These tracks
  /// are referenced here.
  ///
  /// Note that these will not show up in the high-level track order or send
  /// track order. They will show up in the [ProjectModel.tracks] map.
  @anthemObservable
  AnthemObservableList<Id> childTracks = AnthemObservableList<Id>();

  /// IDs of automation lanes owned by this track.
  ///
  /// These lanes are rendered below this track when automation is expanded, but
  /// they are not group children and do not participate in audio processing.
  @anthemObservable
  AnthemObservableList<Id> automationLanes = AnthemObservableList<Id>();

  @anthemObservable
  /// The ID of the parent of this track, if there is any.
  ///
  /// This is calculated automatically after tracks are added, removed, or moved
  /// around.
  Id? parentTrackId;

  /// Whether this track is the master track.
  ///
  /// The master track outputs to the speakers, and cannot be removed.
  @anthemObservable
  bool isMasterTrack = false;

  /// The track that owns this automation lane, if this track is an automation
  /// lane.
  @anthemObservable
  Id? automationLaneParentTrackId;

  /// Audio/event processing state for normal and group tracks.
  ///
  /// Automation lanes deliberately leave this null.
  @anthemObservable
  TrackProcessingModel? processing;

  /// Automation/control processing state for automation lanes.
  ///
  /// Normal and group tracks deliberately leave this null.
  @anthemObservable
  @hideFromCpp
  TrackAutomationProcessingModel? automationProcessing;

  /// Parameter target represented by this automation lane.
  ///
  /// Only automation lanes should set this. It is UI/project data for now and
  /// is not part of the engine-side track model.
  @anthemObservable
  @hideFromCpp
  TrackAutomationTargetModel? automationTarget;

  bool get isAutomationLane => type == TrackType.automationLane;
  bool get hasProcessing => processing != null;
  bool get hasAutomationProcessing => automationProcessing != null;

  TrackProcessingModel get requireProcessing {
    final processing = this.processing;
    if (processing == null) {
      throw StateError('Track $id does not have processing state.');
    }

    return processing;
  }

  TrackAutomationProcessingModel get requireAutomationProcessing {
    final automationProcessing = this.automationProcessing;
    if (automationProcessing == null) {
      throw StateError('Track $id does not have automation processing state.');
    }

    return automationProcessing;
  }

  void createAndRegisterNodes(
    ProjectModel project,
    ProjectEntityIdAllocator idAllocator,
  ) {
    requireProcessing.createAndRegisterNodes(
      track: this as TrackModel,
      project: project,
      idAllocator: idAllocator,
    );
  }

  _TrackModel({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    required this.automationTarget,
    required this.processing,
    required this.automationProcessing,
  }) : super();
}
