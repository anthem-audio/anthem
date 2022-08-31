/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/commands/pattern_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';

import 'command.dart';

void _addTimeSignatureChangeToPattern({
  required ProjectModel project,
  required ID patternID,
  required TimeSignatureChangeModel change,
}) {
  final pattern = project.song.patterns[patternID]!;
  pattern.timeSignatureChanges.add(change);
  pattern.timeSignatureChanges.sort((a, b) => a.offset.compareTo(b.offset));
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

class AddTimeSignatureChangeCommand extends Command {
  ID patternID;
  // This is mutable, which might cause some fun problems.
  // TODO: Use freezed for models?
  TimeSignatureChangeModel change;

  AddTimeSignatureChangeCommand({
    required ProjectModel project,
    required this.patternID,
    required this.change,
  }) : super(project);

  @override
  List<StateChange> execute() {
    _addTimeSignatureChangeToPattern(
      project: project,
      patternID: patternID,
      change: change,
    );
    return [
      StateChange.pattern(
        PatternStateChange.timeSignatureChangeListUpdated(
          project.id,
          patternID,
        ),
      ),
    ];
  }

  @override
  List<StateChange> rollback() {
    _removeTimeSignatureChangeFromPattern(
      project: project,
      patternID: patternID,
      changeID: change.id,
    );
    return [
      StateChange.pattern(
        PatternStateChange.timeSignatureChangeListUpdated(
          project.id,
          patternID,
        ),
      ),
    ];
  }
}

class RemoveTimeSignatureChangeCommand extends Command {
  ID patternID;
  // This is mutable, which might cause some fun problems.
  // TODO: Use freezed for models?
  late TimeSignatureChangeModel change;

  RemoveTimeSignatureChangeCommand({
    required ProjectModel project,
    required this.patternID,
    required ID changeID,
  }) : super(project) {
    change = project.song.patterns[patternID]!.timeSignatureChanges
        .firstWhere((change) => change.id == changeID);
  }

  @override
  List<StateChange> execute() {
    _removeTimeSignatureChangeFromPattern(
      project: project,
      patternID: patternID,
      changeID: change.id,
    );
    return [
      StateChange.pattern(
        PatternStateChange.timeSignatureChangeListUpdated(
          project.id,
          patternID,
        ),
      ),
    ];
  }

  @override
  List<StateChange> rollback() {
    _addTimeSignatureChangeToPattern(
      project: project,
      patternID: patternID,
      change: change,
    );
    return [
      StateChange.pattern(
        PatternStateChange.timeSignatureChangeListUpdated(
          project.id,
          patternID,
        ),
      ),
    ];
  }
}
