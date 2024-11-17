/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/commands/command.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';

void _addNote(
  PatternModel pattern,
  ID generatorID,
  NoteModel note,
) {
  if (!pattern.notes.containsKey(generatorID)) {
    pattern.notes[generatorID] = AnthemObservableList();
  }

  pattern.notes[generatorID]!.add(note);
  pattern.scheduleClipNotesRenderCacheUpdate();
}

void _removeNote(
  PatternModel pattern,
  ID generatorID,
  ID noteID,
) {
  pattern.notes[generatorID]!.removeWhere((element) => element.id == noteID);
  pattern.scheduleClipNotesRenderCacheUpdate();
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
    required this.patternID,
    required this.generatorID,
    required this.note,
  });

  @override
  void execute(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _addNote(pattern, generatorID, note);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _removeNote(pattern, generatorID, note.id);
  }
}

class DeleteNoteCommand extends Command {
  ID patternID;
  ID generatorID;
  NoteModel note;

  DeleteNoteCommand({
    required this.patternID,
    required this.generatorID,
    required this.note,
  });

  @override
  void execute(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _removeNote(pattern, generatorID, note.id);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _addNote(pattern, generatorID, note);
  }
}

enum NoteAttribute { key, offset, length, velocity, pan }

class SetNoteAttributeCommand extends Command {
  ID patternID;
  ID generatorID;
  ID noteID;
  NoteAttribute attribute;
  int oldValue;
  int newValue;

  SetNoteAttributeCommand({
    required this.patternID,
    required this.generatorID,
    required this.noteID,
    required this.attribute,
    required this.oldValue,
    required this.newValue,
  });

  void setAttribute(NoteModel note, int value) {
    switch (attribute) {
      case NoteAttribute.key:
        note.key = value;
        break;
      case NoteAttribute.offset:
        note.offset = value;
        break;
      case NoteAttribute.length:
        note.length = value;
        break;
      case NoteAttribute.velocity:
        note.velocity = value;
        break;
      case NoteAttribute.pan:
        note.pan = value;
        break;
    }
  }

  void updateClipRenderCacheIfNeeded(PatternModel pattern) {
    switch (attribute) {
      case NoteAttribute.key:
      case NoteAttribute.offset:
      case NoteAttribute.length:
        pattern.scheduleClipNotesRenderCacheUpdate();
      default:
        break;
    }
  }

  @override
  void execute(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    final note = _getNote(pattern, generatorID, noteID);

    setAttribute(note, newValue);
    updateClipRenderCacheIfNeeded(pattern);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.song.patterns[patternID];

    if (pattern == null) {
      return;
    }

    final note = _getNote(pattern, generatorID, noteID);

    setAttribute(note, oldValue);
    updateClipRenderCacheIfNeeded(pattern);
  }
}
