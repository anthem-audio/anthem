/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
  required ID patternID,
  required TimeSignatureChangeModel change,
}) {
  final pattern = project.song.patterns[patternID]!;
  pattern.timeSignatureChanges.add(change);
  _sortTimeSignatureChanges(pattern.timeSignatureChanges);
}

void _removeTimeSignatureChangeFromPattern({
  required ProjectModel project,
  required ID patternID,
  required ID changeID,
}) {
  final pattern = project.song.patterns[patternID]!;
  final change = pattern.timeSignatureChanges
      .firstWhere((change) => change.id == changeID);
  pattern.timeSignatureChanges.remove(change);
  // Should still be sorted, so no need to sort here
}

void _sortTimeSignatureChanges(List<TimeSignatureChangeModel> changes) {
  changes.sort((changeA, changeB) => changeA.offset.compareTo(changeB.offset));
}

class AddTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  ID? patternID;
  ID? arrangementID;
  TimeSignatureChangeModel change;

  AddTimeSignatureChangeCommand({
    required this.timelineKind,
    required ProjectModel project,
    this.patternID,
    this.arrangementID,
    required this.change,
  }) : super(project);

  @override
  void execute() {
    if (timelineKind == TimelineKind.pattern) {
      _addTimeSignatureChangeToPattern(
        project: project,
        patternID: patternID!,
        change: change,
      );
    } else {
      throw Exception(
        "Arrangement time signature changes aren't supported yet.",
      );
    }
  }

  @override
  void rollback() {
    if (timelineKind == TimelineKind.pattern) {
      _removeTimeSignatureChangeFromPattern(
        project: project,
        patternID: patternID!,
        changeID: change.id,
      );
    } else {
      throw Exception(
        "Arrangement time signature changes aren't supported yet.",
      );
    }
  }
}

class RemoveTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  ID? patternID;
  ID? arrangementID;
  late TimeSignatureChangeModel change;

  RemoveTimeSignatureChangeCommand({
    required this.timelineKind,
    required ProjectModel project,
    this.patternID,
    this.arrangementID,
    required ID changeID,
  }) : super(project) {
    if (timelineKind == TimelineKind.pattern) {
      change = project.song.patterns[patternID]!.timeSignatureChanges
          .firstWhere((change) => change.id == changeID);
    } else {
      throw Exception(
        "Arrangement time signature changes aren't supported yet.",
      );
    }
  }

  @override
  void execute() {
    if (timelineKind == TimelineKind.pattern) {
      _removeTimeSignatureChangeFromPattern(
        project: project,
        patternID: patternID!,
        changeID: change.id,
      );
    } else {
      throw Exception(
        "Arrangement time signature changes aren't supported yet.",
      );
    }
  }

  @override
  void rollback() {
    if (timelineKind == TimelineKind.pattern) {
      _addTimeSignatureChangeToPattern(
        project: project,
        patternID: patternID!,
        change: change,
      );
    } else {
      throw Exception(
        "Arrangement time signature changes aren't supported yet.",
      );
    }
  }
}

class MoveTimeSignatureChangeCommand extends Command {
  TimelineKind timelineKind;
  ID? patternID;
  ID? arrangementID;
  late List<TimeSignatureChangeModel> changeList;
  late TimeSignatureChangeModel change;
  late Time oldOffset;
  Time newOffset;

  MoveTimeSignatureChangeCommand({
    required ProjectModel project,
    required this.timelineKind,
    this.patternID,
    this.arrangementID,
    required ID changeID,
    Time? oldOffset,
    required this.newOffset,
  }) : super(project) {
    changeList = project.song.patterns[patternID]!.timeSignatureChanges;
    change = changeList.firstWhere((change) => change.id == changeID);
    this.oldOffset = oldOffset ?? change.offset;
  }

  @override
  void execute() {
    if (timelineKind == TimelineKind.arrangement) {
      throw Exception("Not supported yet");
    }

    change.offset = newOffset;
    _sortTimeSignatureChanges(changeList);
  }

  @override
  void rollback() {
    if (timelineKind == TimelineKind.arrangement) {
      throw Exception("Not supported yet");
    }

    change.offset = oldOffset;
    _sortTimeSignatureChanges(changeList);
  }
}

class SetTimeSignatureNumeratorCommand extends Command {
  late TimelineKind timelineKind;
  ID? patternID;
  ID? arrangementID;
  late TimeSignatureChangeModel change;
  late int oldNumerator;
  int numerator;

  SetTimeSignatureNumeratorCommand({
    required ProjectModel project,
    this.patternID,
    this.arrangementID,
    required ID changeID,
    required this.numerator,
  }) : super(project) {
    if (patternID != null) {
      timelineKind = TimelineKind.pattern;
    } else if (arrangementID != null) {
      timelineKind = TimelineKind.arrangement;
    } else {
      throw ArgumentError(
          "Arguments should specify a pattern ID or arrangement ID, but neither was specified.");
    }

    change = project.song.patterns[patternID]!.timeSignatureChanges
        .firstWhere((change) => change.id == changeID);

    oldNumerator = change.timeSignature.numerator;
  }

  @override
  void execute() {
    change.timeSignature.numerator = numerator;
  }

  @override
  void rollback() {
    change.timeSignature.numerator = oldNumerator;
  }
}

class SetTimeSignatureDenominatorCommand extends Command {
  late TimelineKind timelineKind;
  ID? patternID;
  ID? arrangementID;
  late TimeSignatureChangeModel change;
  late int oldDenominator;
  int denominator;

  SetTimeSignatureDenominatorCommand({
    required ProjectModel project,
    this.patternID,
    this.arrangementID,
    required ID changeID,
    required this.denominator,
  }) : super(project) {
    if (patternID != null) {
      timelineKind = TimelineKind.pattern;
    } else if (arrangementID != null) {
      timelineKind = TimelineKind.arrangement;
    } else {
      throw ArgumentError(
          "Arguments should specify a pattern ID or arrangement ID, but neither was specified.");
    }

    change = project.song.patterns[patternID]!.timeSignatureChanges
        .firstWhere((change) => change.id == changeID);

    oldDenominator = change.timeSignature.denominator;
  }

  @override
  void execute() {
    change.timeSignature.denominator = denominator;
  }

  @override
  void rollback() {
    change.timeSignature.denominator = oldDenominator;
  }
}
