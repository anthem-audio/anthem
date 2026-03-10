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
/// This first scaffold keeps the target passive. Later migration steps can add
/// model lookup and mutation helpers once the controller owns live behavior.
class TimelineInteractionTarget {
  final TimelineKind kind;
  final Id sequenceId;
  final Id? arrangementID;
  final Id? patternID;

  const TimelineInteractionTarget._({
    required this.kind,
    required this.sequenceId,
    required this.arrangementID,
    required this.patternID,
  });

  bool get isArrangement => kind == TimelineKind.arrangement;
  bool get isPattern => kind == TimelineKind.pattern;

  PatternModel? pattern(ProjectModel project) {
    final patternID = this.patternID;
    if (patternID == null) {
      return null;
    }

    return project.sequence.patterns[patternID];
  }

  ArrangementModel? arrangement(ProjectModel project) {
    final arrangementID = this.arrangementID;
    if (arrangementID == null) {
      return null;
    }

    return project.sequence.arrangements[arrangementID];
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

  static TimelineInteractionTarget? tryCreate({
    required Id? arrangementID,
    required Id? patternID,
  }) {
    assert(
      arrangementID == null || patternID == null,
      'TimelineInteractionTarget can target at most one sequence at a time.',
    );

    if (patternID != null) {
      return TimelineInteractionTarget._(
        kind: TimelineKind.pattern,
        sequenceId: patternID,
        arrangementID: null,
        patternID: patternID,
      );
    }

    if (arrangementID != null) {
      return TimelineInteractionTarget._(
        kind: TimelineKind.arrangement,
        sequenceId: arrangementID,
        arrangementID: arrangementID,
        patternID: null,
      );
    }

    return null;
  }
}
