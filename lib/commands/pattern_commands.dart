/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/commands/pattern_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/shared/time_signature.dart';

import 'command.dart';

void _addPatternToProject({
  required ProjectModel project,
  required PatternModel pattern,
  required int index,
}) {
  project.song.patternOrder.insert(index, pattern.id);
  project.song.patterns[pattern.id] = pattern;
}

void _removePatternFromProject({
  required ProjectModel project,
  required ID patternID,
}) {
  project.song.patternOrder.removeWhere((element) => element == patternID);
  project.song.patterns.remove(patternID);
}

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

class AddPatternCommand extends Command {
  PatternModel pattern;
  int index;

  AddPatternCommand({
    required ProjectModel project,
    required this.pattern,
    required this.index,
  }) : super(project);

  @override
  List<StateChange> execute() {
    _addPatternToProject(
      project: project,
      pattern: pattern,
      index: index,
    );
    return [
      StateChange.pattern(
        PatternStateChange.patternAdded(project.id, pattern.id),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    _removePatternFromProject(
      project: project,
      patternID: pattern.id,
    );
    return [
      StateChange.pattern(
        PatternStateChange.patternDeleted(project.id, pattern.id),
      )
    ];
  }
}

class DeletePatternCommand extends Command {
  PatternModel pattern;
  int index;

  DeletePatternCommand({
    required ProjectModel project,
    required this.pattern,
    required this.index,
  }) : super(project);

  @override
  List<StateChange> execute() {
    _removePatternFromProject(
      project: project,
      patternID: pattern.id,
    );
    return [
      StateChange.pattern(
        PatternStateChange.patternDeleted(project.id, pattern.id),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    _addPatternToProject(
      project: project,
      pattern: pattern,
      index: index,
    );
    return [
      StateChange.pattern(
        PatternStateChange.patternAdded(project.id, pattern.id),
      )
    ];
  }
}

class SetPatternNameCommand extends Command {
  ID patternID;
  late String oldName;
  String newName;

  SetPatternNameCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newName,
  }) : super(project) {
    oldName = project.song.patterns[patternID]!.name;
  }

  @override
  List<StateChange> execute() {
    project.song.patterns[patternID]!.name = newName;
    return [StateChange.pattern(PatternNameChanged(project.id, patternID))];
  }

  @override
  List<StateChange> rollback() {
    project.song.patterns[patternID]!.name = oldName;
    return [StateChange.pattern(PatternNameChanged(project.id, patternID))];
  }
}

class SetPatternColorCommand extends Command {
  ID patternID;
  late AnthemColor oldColor;
  AnthemColor newColor;

  SetPatternColorCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newColor,
  }) : super(project) {
    oldColor = project.song.patterns[patternID]!.color;
  }

  @override
  List<StateChange> execute() {
    project.song.patterns[patternID]!.color = newColor;
    return [StateChange.pattern(PatternColorChanged(project.id, patternID))];
  }

  @override
  List<StateChange> rollback() {
    project.song.patterns[patternID]!.color = oldColor;
    return [StateChange.pattern(PatternColorChanged(project.id, patternID))];
  }
}

void _addNote(
  PatternModel pattern,
  ID generatorID,
  NoteModel note,
) {
  if (!pattern.notes.containsKey(generatorID)) {
    pattern.notes[generatorID] = [];
  }

  pattern.notes[generatorID]!.add(note);
}

void _removeNote(
  PatternModel pattern,
  ID generatorID,
  ID noteID,
) {
  pattern.notes[generatorID]!.removeWhere((element) => element.id == noteID);
}

NoteModel _getNote(
  PatternModel pattern,
  ID generatorID,
  ID noteID,
) {
  return pattern.notes[generatorID]!
      .firstWhere((element) => element.id == noteID);
}

class AddNoteCommand extends Command {
  ID patternID;
  ID generatorID;
  NoteModel note;

  AddNoteCommand({
    required ProjectModel project,
    required this.patternID,
    required this.generatorID,
    required this.note,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    _addNote(pattern, generatorID, note);

    return [
      StateChange.note(
        NoteStateChange.noteAdded(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    _removeNote(pattern, generatorID, note.id);

    return [
      StateChange.note(
        NoteStateChange.noteDeleted(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }
}

class DeleteNoteCommand extends Command {
  ID patternID;
  ID generatorID;
  NoteModel note;

  DeleteNoteCommand({
    required ProjectModel project,
    required this.patternID,
    required this.generatorID,
    required this.note,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    _removeNote(pattern, generatorID, note.id);

    return [
      StateChange.note(
        NoteStateChange.noteDeleted(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    _addNote(pattern, generatorID, note);

    return [
      StateChange.note(
        NoteStateChange.noteAdded(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }
}

class MoveNoteCommand extends Command {
  ID patternID;
  ID generatorID;
  ID noteID;
  int oldKey;
  int newKey;
  int oldOffset;
  int newOffset;

  MoveNoteCommand({
    required ProjectModel project,
    required this.patternID,
    required this.generatorID,
    required this.noteID,
    required this.oldKey,
    required this.newKey,
    required this.oldOffset,
    required this.newOffset,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    final note = _getNote(pattern, generatorID, noteID);

    note.key = newKey;
    note.offset = newOffset;

    return [
      StateChange.note(
        NoteStateChange.noteMoved(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    final note = _getNote(pattern, generatorID, noteID);

    note.key = oldKey;
    note.offset = oldOffset;

    return [
      StateChange.note(
        NoteStateChange.noteMoved(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }
}

class ResizeNoteCommand extends Command {
  ID patternID;
  ID generatorID;
  ID noteID;
  int oldLength;
  int newLength;

  ResizeNoteCommand({
    required ProjectModel project,
    required this.patternID,
    required this.generatorID,
    required this.noteID,
    required this.oldLength,
    required this.newLength,
  }) : super(project);

  @override
  List<StateChange> execute() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    final note = _getNote(pattern, generatorID, noteID);

    note.length = newLength;

    return [
      StateChange.note(
        NoteStateChange.noteResized(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return [];
    }

    final note = _getNote(pattern, generatorID, noteID);

    note.length = newLength;

    return [
      StateChange.note(
        NoteStateChange.noteResized(
          project.id,
          patternID,
          generatorID,
          note.id,
        ),
      )
    ];
  }
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
