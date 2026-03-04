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
  if (pattern.notes.any((existingNote) => existingNote.id == note.id)) {
    throw StateError(
      'Note ${note.id} already exists in pattern ${pattern.id}.',
    );
  }

  pattern.notes.add(note);
}

void _removeNote(PatternModel pattern, Id noteID) {
  pattern.notes.remove(_requireNote(pattern, noteID));
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
  final Id _patternID;
  final NoteModel _note;

  AddNoteCommand({required Id patternID, required NoteModel note})
    : _patternID = patternID,
      _note = note;

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);
    _addNote(pattern, _note);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);
    _removeNote(pattern, _note.id);
  }
}

class DeleteNoteCommand extends Command {
  final Id _patternID;
  final NoteModel _note;

  DeleteNoteCommand({required Id patternID, required NoteModel note})
    : _patternID = patternID,
      _note = note;

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);
    _removeNote(pattern, _note.id);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);
    _addNote(pattern, _note);
  }
}

class MoveNotesCommand extends Command {
  final Id _patternID;
  final List<
    ({Id noteID, int oldOffset, int newOffset, int oldKey, int newKey})
  >
  _noteMoves;

  MoveNotesCommand({
    required Id patternID,
    required List<
      ({Id noteID, int oldOffset, int newOffset, int oldKey, int newKey})
    >
    noteMoves,
  }) : _patternID = patternID,
       _noteMoves = List.unmodifiable(noteMoves),
       super();

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);

    for (final noteMove in _noteMoves) {
      final note = _requireNote(pattern, noteMove.noteID);
      note.offset = noteMove.newOffset;
      note.key = noteMove.newKey;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);

    for (final noteMove in _noteMoves.reversed) {
      final note = _requireNote(pattern, noteMove.noteID);
      note.offset = noteMove.oldOffset;
      note.key = noteMove.oldKey;
    }
  }
}

class ResizeNotesCommand extends Command {
  final Id _patternID;
  final List<({Id noteID, int oldLength, int newLength})> _noteResizes;

  ResizeNotesCommand({
    required Id patternID,
    required List<({Id noteID, int oldLength, int newLength})> noteResizes,
  }) : _patternID = patternID,
       _noteResizes = List.unmodifiable(noteResizes),
       super();

  @override
  void execute(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);

    for (final noteResize in _noteResizes) {
      final note = _requireNote(pattern, noteResize.noteID);
      note.length = noteResize.newLength;
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);

    for (final noteResize in _noteResizes.reversed) {
      final note = _requireNote(pattern, noteResize.noteID);
      note.length = noteResize.oldLength;
    }
  }
}

class DeleteNotesCommand extends Command {
  final Id _patternID;
  final List<_DeleteNoteSnapshot> _notes;

  DeleteNotesCommand({
    required Id patternID,
    required Iterable<NoteModel> notes,
  }) : _patternID = patternID,
       _notes = List.unmodifiable(
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
    final pattern = _requirePattern(project, _patternID);

    for (final note in _notes) {
      _removeNote(pattern, note.id);
    }
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);

    for (final note in _notes.reversed) {
      _addNote(pattern, _restoreDeletedNote(note));
    }
  }
}

enum NoteAttribute { key, offset, length, velocity, pan }

class SetNoteAttributeCommand extends Command {
  final Id _patternID;
  final Id _noteID;
  final NoteAttribute _attribute;
  final num _oldValue;
  final num _newValue;

  SetNoteAttributeCommand({
    required Id patternID,
    required Id noteID,
    required NoteAttribute attribute,
    required num oldValue,
    required num newValue,
  }) : _patternID = patternID,
       _noteID = noteID,
       _attribute = attribute,
       _oldValue = oldValue,
       _newValue = newValue;

  void _setAttribute(NoteModel note, num value) {
    switch (_attribute) {
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
    final pattern = _requirePattern(project, _patternID);
    final note = _requireNote(pattern, _noteID);
    _setAttribute(note, _newValue);
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = _requirePattern(project, _patternID);
    final note = _requireNote(pattern, _noteID);
    _setAttribute(note, _oldValue);
  }
}
