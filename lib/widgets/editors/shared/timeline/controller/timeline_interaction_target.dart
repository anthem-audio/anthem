/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';

/// Identifies which shared timeline target is being edited.
///
/// Arrangement targets derive their sequence ID from the project's singular
/// arrangement. Pattern targets retain the selected pattern ID, which may be
/// null while no pattern is open.
class TimelineInteractionTarget {
  final TimelineKind kind;
  final Id? patternID;

  const TimelineInteractionTarget.arrangement()
    : kind = TimelineKind.arrangement,
      patternID = null;

  const TimelineInteractionTarget.pattern(this.patternID)
    : kind = TimelineKind.pattern;

  bool get isArrangement => kind == TimelineKind.arrangement;
  bool get isPattern => kind == TimelineKind.pattern;

  @override
  bool operator ==(Object other) {
    return other is TimelineInteractionTarget &&
        kind == other.kind &&
        patternID == other.patternID;
  }

  @override
  int get hashCode => Object.hash(kind, patternID);

  Id? sequenceId(ProjectModel project) {
    return switch (kind) {
      TimelineKind.pattern => patternID,
      TimelineKind.arrangement => project.sequence.arrangement.id,
    };
  }

  PatternModel? pattern(ProjectModel project) {
    final patternID = this.patternID;
    if (patternID == null) {
      return null;
    }

    return project.sequence.patterns[patternID];
  }

  ArrangementModel? arrangement(ProjectModel project) {
    return kind == TimelineKind.arrangement
        ? project.sequence.arrangement
        : null;
  }

  List<TimeSignatureChangeModel> timeSignatureChanges(ProjectModel project) {
    return switch (kind) {
      TimelineKind.pattern => pattern(project)?.timeSignatureChanges ?? [],
      TimelineKind.arrangement =>
        arrangement(project)?.timeSignatureChanges ?? [],
    };
  }

  LoopPointsModel? loopPoints(ProjectModel project) {
    return switch (kind) {
      TimelineKind.pattern => pattern(project)?.loopPoints,
      TimelineKind.arrangement => arrangement(project)?.loopPoints,
    };
  }

  void clearLoopPoints(ProjectModel project) {
    switch (kind) {
      case TimelineKind.pattern:
        final pattern = this.pattern(project);
        if (pattern == null) {
          return;
        }

        pattern.loopPoints = null;
        return;
      case TimelineKind.arrangement:
        final arrangement = this.arrangement(project);
        if (arrangement == null) {
          return;
        }

        arrangement.loopPoints = null;
        return;
    }
  }

  void setLoopPoints(
    ProjectModel project, {
    required int start,
    required int end,
  }) {
    final existingLoopPoints = loopPoints(project);
    if (existingLoopPoints == null) {
      switch (kind) {
        case TimelineKind.pattern:
          final pattern = this.pattern(project);
          if (pattern == null) {
            return;
          }

          pattern.loopPoints = LoopPointsModel(start, end);
          return;
        case TimelineKind.arrangement:
          final arrangement = this.arrangement(project);
          if (arrangement == null) {
            return;
          }

          arrangement.loopPoints = LoopPointsModel(start, end);
          return;
      }
    }

    existingLoopPoints.start = start;
    existingLoopPoints.end = end;
  }

  void updateLoopPoints(ProjectModel project, {int? start, int? end}) {
    final existingLoopPoints = loopPoints(project);
    if (existingLoopPoints == null) {
      return;
    }

    if (start != null) {
      existingLoopPoints.start = start;
    }

    if (end != null) {
      existingLoopPoints.end = end;
    }
  }
}
