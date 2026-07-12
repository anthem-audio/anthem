/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem_codegen/include.dart';

ProjectEntityIdAllocator testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

TrackModel makeTestTrack(Id id, String name, TrackType type) {
  return TrackModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    name: name,
    color: AnthemColor.randomHue(),
    type: type,
  );
}

void resetTestProjectProcessingGraph(
  ProjectModel project, {
  Id? masterOutputNodeId,
}) {
  project.processingGraph = ProcessingGraphModel.create(
    masterOutputNodeId: masterOutputNodeId ?? project.idAllocator.allocateId(),
  );
}

class TestProjectTrack {
  final Id id;
  final String name;
  final TrackType type;
  final List<Id> childTracks;
  final List<Id> automationLanes;
  final Id? parentTrackId;
  final Id? automationLaneParentTrackId;
  final bool isMasterTrack;
  final TrackAutomationTargetModel? automationTarget;
  final AnthemColor? color;

  const TestProjectTrack({
    required this.id,
    required this.name,
    this.type = TrackType.normal,
    this.childTracks = const [],
    this.automationLanes = const [],
    this.parentTrackId,
    this.automationLaneParentTrackId,
    this.isMasterTrack = false,
    this.automationTarget,
    this.color,
  });
}

ProjectModel createTestProject({
  Iterable<TestProjectTrack> tracks = const [],
  Iterable<Id> trackOrder = const [],
  Iterable<Id> sendTrackOrder = const [],
  SequencerModel? sequence,
  Id? masterOutputNodeId,
  int? idCounter,
  bool includeSequence = true,
}) {
  final project = ProjectModel();
  final trackConfigs = tracks.toList(growable: false);
  final reservedTrackIds = trackConfigs.map((track) => track.id).toSet();

  if (idCounter != null) {
    project.idCounter = idCounter;
  }

  if (includeSequence || sequence != null) {
    project.sequence =
        sequence ?? SequencerModel(idAllocator: testIdAllocator());
  }

  final resolvedMasterOutputNodeId =
      masterOutputNodeId ??
      _allocateProjectIdAvoiding(project, reservedTrackIds);
  resetTestProjectProcessingGraph(
    project,
    masterOutputNodeId: resolvedMasterOutputNodeId,
  );

  final trackMap = {
    for (final trackConfig in trackConfigs)
      trackConfig.id:
          TrackModel(
              idAllocator: ProjectEntityIdAllocator.test(() => trackConfig.id),
              name: trackConfig.name,
              color: trackConfig.color ?? AnthemColor.randomHue(),
              type: trackConfig.type,
            )
            ..childTracks.addAll(trackConfig.childTracks)
            ..automationLanes.addAll(trackConfig.automationLanes)
            ..parentTrackId = trackConfig.parentTrackId
            ..automationLaneParentTrackId =
                trackConfig.automationLaneParentTrackId
            ..isMasterTrack = trackConfig.isMasterTrack,
  };

  for (final trackConfig in trackConfigs) {
    final track = trackMap[trackConfig.id]!;
    if (trackConfig.automationTarget != null) {
      track.automationTarget = trackConfig.automationTarget;
    }
  }

  for (final track in trackMap.values) {
    for (final childTrackId in track.childTracks) {
      trackMap[childTrackId]?.parentTrackId = track.id;
    }
    for (final automationLaneId in track.automationLanes) {
      trackMap[automationLaneId]?.automationLaneParentTrackId = track.id;
    }
  }

  project.tracks = AnthemObservableMap.of(trackMap);
  project.trackOrder = AnthemObservableList.of(trackOrder);
  project.sendTrackOrder = AnthemObservableList.of(sendTrackOrder);
  for (final trackId in trackMap.keys) {
    if (project.idCounter <= trackId) {
      project.idCounter = trackId + 1;
    }
  }
  project.isHydrated = true;

  return project;
}

Id _allocateProjectIdAvoiding(ProjectModel project, Set<Id> reservedIds) {
  late Id id;
  do {
    id = project.idAllocator.allocateId();
  } while (reservedIds.contains(id));

  return id;
}
