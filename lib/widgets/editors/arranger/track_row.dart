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

class AutomationParameterTarget {
  final Id ownerTrackId;
  final Id nodeId;
  final int portId;
  final String ownerName;
  final String parameterName;

  const AutomationParameterTarget({
    required this.ownerTrackId,
    required this.nodeId,
    required this.portId,
    required this.ownerName,
    required this.parameterName,
  });

  String get title => '$ownerName $parameterName';
}

class PhantomAutomationLaneInfo {
  final Id id;
  final Id parentTrackId;
  final AutomationParameterTarget? target;

  const PhantomAutomationLaneInfo({
    required this.id,
    required this.parentTrackId,
    required this.target,
  });

  String get title => target?.title ?? 'No parameter selected';
}

/// Semantic data for one visible track row, independent of calculated layout.
sealed class TrackRow {
  final bool isSendTrack;
  final int trackDepth;

  const TrackRow({required this.isSendTrack, required this.trackDepth});

  Id get rowId;
}

/// A visible row backed by a track in the project model.
class ProjectTrackRow extends TrackRow {
  final Id trackId;

  const ProjectTrackRow({
    required this.trackId,
    required super.isSendTrack,
    required super.trackDepth,
  });

  @override
  Id get rowId => trackId;
}

/// A temporary automation row that does not yet have a project-model track.
class PhantomAutomationTrackRow extends TrackRow {
  final PhantomAutomationLaneInfo phantomLane;

  const PhantomAutomationTrackRow({
    required this.phantomLane,
    required super.isSendTrack,
    required super.trackDepth,
  });

  @override
  Id get rowId => phantomLane.id;
}
