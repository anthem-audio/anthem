/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

// This file has commands that deal with shared features between pattern
// timelines and arrangement timelines, such as time markers.

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';

import 'command.dart';

enum TimelineKind { pattern, arrangement }

void _addTimeSignatureChangeToPattern({
  required ProjectModel project,
  required Id patternID,
  required TimeSignatureChangeModel change,
}) {
  final pattern = project.sequence.patterns[patternID]!;
  pattern.timeSignatureChanges.add(change);
  _sortTimeSignatureChanges(pattern.timeSignatureChanges);
}

void _removeTimeSignatureChangeFromPattern({
  required ProjectModel project,
  required Id patternID,
  required Id changeID,
}) {
  final pattern = project.sequence.patterns[patternID]!;
  final change = pattern.timeSignatureChanges.firstWhere(
    (change) => change.id == changeID,
  );
  pattern.timeSignatureChanges.remove(change);
  // Should still be sorted, so no need to sort here
}

void _addTimeSignatureChangeToArrangement({
  required ProjectModel project,
  required TimeSignatureChangeModel change,
}) {
  final arrangement = project.sequence.arrangement;
  arrangement.timeSignatureChanges.add(change);
  _sortTimeSignatureChanges(arrangement.timeSignatureChanges);
}

void _removeTimeSignatureChangeFromArrangement({
  required ProjectModel project,
  required Id changeID,
}) {
  final arrangement = project.sequence.arrangement;
  final change = arrangement.timeSignatureChanges.firstWhere(
    (change) => change.id == changeID,
  );
  arrangement.timeSignatureChanges.remove(change);
  // Should still be sorted, so no need to sort here
}

List<TimeSignatureChangeModel> _getChangeList({
  required ProjectModel project,
  required TimelineKind timelineKind,
  Id? patternID,
}) {
  return switch (timelineKind) {
    TimelineKind.pattern =>
      project.sequence.patterns[patternID]!.timeSignatureChanges,
    TimelineKind.arrangement =>
      project.sequence.arrangement.timeSignatureChanges,
  };
}

void _sortTimeSignatureChanges(List<TimeSignatureChangeModel> changes) {
  changes.sort((changeA, changeB) => changeA.offset.compareTo(changeB.offset));
}

class AddTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  Id? patternID;
  TimeSignatureChangeModel change;

  AddTimeSignatureChangeCommand({
    required this.timelineKind,
    this.patternID,
    required this.change,
  });

  @override
  void execute(ProjectModel project) {
    if (timelineKind == TimelineKind.pattern) {
      _addTimeSignatureChangeToPattern(
        project: project,
        patternID: patternID!,
        change: change,
      );
    } else {
      _addTimeSignatureChangeToArrangement(project: project, change: change);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (timelineKind == TimelineKind.pattern) {
      _removeTimeSignatureChangeFromPattern(
        project: project,
        patternID: patternID!,
        changeID: change.id,
      );
    } else {
      _removeTimeSignatureChangeFromArrangement(
        project: project,
        changeID: change.id,
      );
    }
  }
}

class RemoveTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  Id? patternID;
  late TimeSignatureChangeModel change;

  RemoveTimeSignatureChangeCommand({
    required this.timelineKind,
    required ProjectModel project,
    this.patternID,
    required Id changeID,
  }) {
    if (timelineKind == TimelineKind.pattern) {
      change = project.sequence.patterns[patternID]!.timeSignatureChanges
          .firstWhere((change) => change.id == changeID);
    } else {
      change = project.sequence.arrangement.timeSignatureChanges.firstWhere(
        (change) => change.id == changeID,
      );
    }
  }

  @override
  void execute(ProjectModel project) {
    if (timelineKind == TimelineKind.pattern) {
      _removeTimeSignatureChangeFromPattern(
        project: project,
        patternID: patternID!,
        changeID: change.id,
      );
    } else {
      _removeTimeSignatureChangeFromArrangement(
        project: project,
        changeID: change.id,
      );
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (timelineKind == TimelineKind.pattern) {
      _addTimeSignatureChangeToPattern(
        project: project,
        patternID: patternID!,
        change: change,
      );
    } else {
      _addTimeSignatureChangeToArrangement(project: project, change: change);
    }
  }
}

class MoveTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  Id? patternID;
  late List<TimeSignatureChangeModel> changeList;
  late TimeSignatureChangeModel change;
  late Time oldOffset;
  Time newOffset;

  MoveTimeSignatureChangeCommand({
    required ProjectModel project,
    required this.timelineKind,
    this.patternID,
    required Id changeID,
    Time? oldOffset,
    required this.newOffset,
  }) {
    changeList = _getChangeList(
      project: project,
      timelineKind: timelineKind,
      patternID: patternID,
    );
    change = changeList.firstWhere((change) => change.id == changeID);
    this.oldOffset = oldOffset ?? change.offset;
  }

  @override
  void execute(ProjectModel project) {
    change.offset = newOffset;
    _sortTimeSignatureChanges(changeList);
  }

  @override
  void rollback(ProjectModel project) {
    change.offset = oldOffset;
    _sortTimeSignatureChanges(changeList);
  }
}

class SetTimeSignatureNumeratorCommand extends Command {
  TimelineKind timelineKind;
  Id? patternID;
  late TimeSignatureChangeModel change;
  late int oldNumerator;
  int numerator;

  SetTimeSignatureNumeratorCommand({
    required ProjectModel project,
    required this.timelineKind,
    this.patternID,
    required Id changeID,
    required this.numerator,
  }) {
    change = _getChangeList(
      project: project,
      timelineKind: timelineKind,
      patternID: patternID,
    ).firstWhere((change) => change.id == changeID);

    oldNumerator = change.timeSignature.numerator;
  }

  @override
  void execute(ProjectModel project) {
    change.timeSignature.numerator = numerator;
  }

  @override
  void rollback(ProjectModel project) {
    change.timeSignature.numerator = oldNumerator;
  }
}

class SetTimeSignatureDenominatorCommand extends Command {
  TimelineKind timelineKind;
  Id? patternID;
  late TimeSignatureChangeModel change;
  late int oldDenominator;
  int denominator;

  SetTimeSignatureDenominatorCommand({
    required ProjectModel project,
    required this.timelineKind,
    this.patternID,
    required Id changeID,
    required this.denominator,
  }) {
    change = _getChangeList(
      project: project,
      timelineKind: timelineKind,
      patternID: patternID,
    ).firstWhere((change) => change.id == changeID);

    oldDenominator = change.timeSignature.denominator;
  }

  @override
  void execute(ProjectModel project) {
    change.timeSignature.denominator = denominator;
  }

  @override
  void rollback(ProjectModel project) {
    change.timeSignature.denominator = oldDenominator;
  }
}
