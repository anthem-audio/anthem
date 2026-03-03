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

import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';

void _addNote(PatternModel pattern, NoteModel note) {
  pattern.notes.add(note);
}

void _removeNote(PatternModel pattern, Id noteID) {
  pattern.notes.removeWhere((element) => element.id == noteID);
}

NoteModel _getNote(PatternModel pattern, Id noteID) {
  return pattern.notes.firstWhere((element) => element.id == noteID);
}

PatternModel _requirePattern(ProjectModel project, Id patternID) {
  final pattern = project.sequence.patterns[patternID];
  if (pattern == null) {
    throw StateError('Pattern $patternID was not found.');
  }

  return pattern;
}

NoteModel _requireNote(PatternModel pattern, Id noteID) {
  try {
    return _getNote(pattern, noteID);
  } on StateError {
    throw StateError('Note $noteID was not found in pattern ${pattern.id}.');
  }
}

typedef _DeleteNoteSnapshot = ({
  Id id,
  int key,
  double velocity,
  int length,
  int offset,
  double pan,
});

NoteModel _restoreDeletedNote(_DeleteNoteSnapshot snapshot) {
  return NoteModel(
    key: snapshot.key,
    velocity: snapshot.velocity,
    length: snapshot.length,
    offset: snapshot.offset,
    pan: snapshot.pan,
  )..id = snapshot.id;
}

class AddNoteCommand extends Command {
  Id patternID;
  NoteModel note;

  AddNoteCommand({required this.patternID, required this.note});

  @override
  void execute(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _addNote(pattern, note);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _removeNote(pattern, note.id);
  }
}

class DeleteNoteCommand extends Command {
  Id patternID;
  NoteModel note;

  DeleteNoteCommand({required this.patternID, required this.note});

  @override
  void execute(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _removeNote(pattern, note.id);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    _addNote(pattern, note);
  }
}

class MoveNotesCommand extends Command {
  final Id patternID;
  final List<
    ({Id noteID, int oldOffset, int newOffset, int oldKey, int newKey})
  >
  noteMoves;

  MoveNotesCommand({
    required this.patternID,
    required List<
      ({Id noteID, int oldOffset, int newOffset, int oldKey, int newKey})
    >
    noteMoves,
  }) : noteMoves = List.unmodifiable(noteMoves),
       super();

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final noteMove in noteMoves) {
      final note = _requireNote(pattern, noteMove.noteID);
      note.offset = noteMove.newOffset;
      note.key = noteMove.newKey;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final noteMove in noteMoves.reversed) {
      final note = _requireNote(pattern, noteMove.noteID);
      note.offset = noteMove.oldOffset;
      note.key = noteMove.oldKey;
    }
  }
}

class ResizeNotesCommand extends Command {
  final Id patternID;
  final List<({Id noteID, int oldLength, int newLength})> noteResizes;

  ResizeNotesCommand({
    required this.patternID,
    required List<({Id noteID, int oldLength, int newLength})> noteResizes,
  }) : noteResizes = List.unmodifiable(noteResizes),
       super();

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final noteResize in noteResizes) {
      final note = _requireNote(pattern, noteResize.noteID);
      note.length = noteResize.newLength;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final noteResize in noteResizes.reversed) {
      final note = _requireNote(pattern, noteResize.noteID);
      note.length = noteResize.oldLength;
    }
  }
}

class DeleteNotesCommand extends Command {
  final Id patternID;
  final List<_DeleteNoteSnapshot> notes;

  DeleteNotesCommand({
    required this.patternID,
    required Iterable<NoteModel> notes,
  }) : notes = List.unmodifiable(
         notes.map(
           (note) => (
             id: note.id,
             key: note.key,
             velocity: note.velocity,
             length: note.length,
             offset: note.offset,
             pan: note.pan,
           ),
         ),
       ),
       super();

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final note in notes) {
      _removeNote(pattern, note.id);
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, patternID);

    for (final note in notes.reversed) {
      _addNote(pattern, _restoreDeletedNote(note));
    }
  }
}

enum NoteAttribute { key, offset, length, velocity, pan }

class SetNoteAttributeCommand extends Command {
  Id patternID;
  Id noteID;
  NoteAttribute attribute;
  num oldValue;
  num newValue;

  SetNoteAttributeCommand({
    required this.patternID,
    required this.noteID,
    required this.attribute,
    required this.oldValue,
    required this.newValue,
  });

  void setAttribute(NoteModel note, num value) {
    switch (attribute) {
      case NoteAttribute.key:
        note.key = value.toInt();
        break;
      case NoteAttribute.offset:
        note.offset = value.toInt();
        break;
      case NoteAttribute.length:
        note.length = value.toInt();
        break;
      case NoteAttribute.velocity:
        note.velocity = value.toDouble();
        break;
      case NoteAttribute.pan:
        note.pan = value.toDouble();
        break;
    }
  }

  @override
  void execute(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    final note = _getNote(pattern, noteID);

    setAttribute(note, newValue);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID];

    if (pattern == null) {
      return;
    }

    final note = _getNote(pattern, noteID);

    setAttribute(note, oldValue);
  }
}
