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
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockProjectModel extends Mock implements ProjectModel {
  MockProjectModel(this._sequence);

  final SequencerModel _sequence;

  @override
  SequencerModel get sequence => _sequence;
}

void main() {
  late MockProjectModel project;
  late SequencerModel sequence;
  late AnthemObservableMap<Id, PatternModel> patterns;

  PatternModel addPatternToProject(String name) {
    final pattern = PatternModel.create(name: name);
    patterns[pattern.id] = pattern;
    return pattern;
  }

  NoteModel addNote(
    PatternModel pattern, {
    required int key,
    required int offset,
    required int length,
    double velocity = 0.75,
    double pan = 0,
  }) {
    final note = NoteModel(
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );
    pattern.notes[note.id] = note;
    return note;
  }

  setUp(() {
    sequence = SequencerModel.uninitialized();
    patterns = AnthemObservableMap();
    sequence.patterns = patterns;
    project = MockProjectModel(sequence);
  });

  group('AddNoteCommand', () {
    test('execute and rollback add and remove a note', () {
      final pattern = addPatternToProject('Pattern');
      final note = NoteModel(
        key: 60,
        velocity: 0.75,
        length: 48,
        offset: 64,
        pan: 0,
      );
      final command = AddNoteCommand(patternID: pattern.id, note: note);

      command.execute(project);
      expect(pattern.notes.values.single.id, equals(note.id));

      command.rollback(project);
      expect(pattern.notes, isEmpty);
    });

    test('execute throws when pattern does not exist', () {
      final command = AddNoteCommand(
        patternID: getId(),
        note: NoteModel(
          key: 60,
          velocity: 0.75,
          length: 48,
          offset: 64,
          pan: 0,
        ),
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('execute throws when note already exists in the pattern', () {
      final pattern = addPatternToProject('Pattern');
      final note = addNote(pattern, key: 60, offset: 64, length: 48);
      final command = AddNoteCommand(patternID: pattern.id, note: note);

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('DeleteNoteCommand', () {
    test('execute and rollback delete and restore a note', () {
      final pattern = addPatternToProject('Pattern');
      final note = addNote(pattern, key: 60, offset: 64, length: 48);
      final command = DeleteNoteCommand(patternID: pattern.id, note: note);

      command.execute(project);
      expect(pattern.notes, isEmpty);

      command.rollback(project);
      expect(pattern.notes.values.single.id, equals(note.id));
    });

    test('execute throws when pattern does not exist', () {
      final command = DeleteNoteCommand(
        patternID: getId(),
        note: NoteModel(
          key: 60,
          velocity: 0.75,
          length: 48,
          offset: 64,
          pan: 0,
        ),
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('execute throws when note does not exist', () {
      final pattern = addPatternToProject('Pattern');
      final command = DeleteNoteCommand(
        patternID: pattern.id,
        note: NoteModel(
          key: 60,
          velocity: 0.75,
          length: 48,
          offset: 64,
          pan: 0,
        ),
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('MoveNotesCommand', () {
    test('execute and rollback update keys and offsets for multiple notes', () {
      final pattern = addPatternToProject('Pattern');
      final noteA = addNote(pattern, key: 60, offset: 64, length: 48);
      final noteB = addNote(pattern, key: 64, offset: 96, length: 72);

      final command = MoveNotesCommand(
        patternID: pattern.id,
        noteMoves: [
          (
            noteID: noteA.id,
            oldOffset: 64,
            newOffset: 128,
            oldKey: 60,
            newKey: 62,
          ),
          (
            noteID: noteB.id,
            oldOffset: 96,
            newOffset: 144,
            oldKey: 64,
            newKey: 67,
          ),
        ],
      );

      command.execute(project);
      expect(noteA.offset, equals(128));
      expect(noteA.key, equals(62));
      expect(noteB.offset, equals(144));
      expect(noteB.key, equals(67));

      command.rollback(project);
      expect(noteA.offset, equals(64));
      expect(noteA.key, equals(60));
      expect(noteB.offset, equals(96));
      expect(noteB.key, equals(64));
    });

    test('execute throws when pattern does not exist', () {
      final command = MoveNotesCommand(
        patternID: getId(),
        noteMoves: [
          (
            noteID: getId(),
            oldOffset: 0,
            newOffset: 96,
            oldKey: 60,
            newKey: 61,
          ),
        ],
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('ResizeNotesCommand', () {
    test('execute and rollback update lengths for multiple notes', () {
      final pattern = addPatternToProject('Pattern');
      final noteA = addNote(pattern, key: 60, offset: 64, length: 48);
      final noteB = addNote(pattern, key: 64, offset: 96, length: 72);

      final command = ResizeNotesCommand(
        patternID: pattern.id,
        noteResizes: [
          (noteID: noteA.id, oldLength: 48, newLength: 96),
          (noteID: noteB.id, oldLength: 72, newLength: 120),
        ],
      );

      command.execute(project);
      expect(noteA.length, equals(96));
      expect(noteB.length, equals(120));

      command.rollback(project);
      expect(noteA.length, equals(48));
      expect(noteB.length, equals(72));
    });

    test('execute throws when note does not exist', () {
      final pattern = addPatternToProject('Pattern');
      final command = ResizeNotesCommand(
        patternID: pattern.id,
        noteResizes: [(noteID: getId(), oldLength: 48, newLength: 96)],
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });

  group('DeleteNotesCommand', () {
    test('execute and rollback delete and restore multiple notes', () {
      final pattern = addPatternToProject('Pattern');
      final noteA = addNote(pattern, key: 60, offset: 64, length: 48);
      final noteB = addNote(pattern, key: 64, offset: 96, length: 72);
      final noteC = addNote(pattern, key: 67, offset: 144, length: 24);

      final command = DeleteNotesCommand(
        patternID: pattern.id,
        notes: [noteA, noteC],
      );

      command.execute(project);
      expect(
        pattern.notes.values.map((note) => note.id).toList(),
        orderedEquals([noteB.id]),
      );

      command.rollback(project);
      expect(
        pattern.notes.values.map((note) => note.id).toSet(),
        equals({noteA.id, noteB.id, noteC.id}),
      );
    });

    test(
      'rollback restores the original snapshot across repeated undo/redo cycles',
      () {
        final pattern = addPatternToProject('Pattern');
        final note = addNote(
          pattern,
          key: 60,
          offset: 64,
          length: 48,
          velocity: 0.5,
          pan: -0.25,
        );

        final command = DeleteNotesCommand(
          patternID: pattern.id,
          notes: [note],
        );

        command.execute(project);
        command.rollback(project);

        final restoredNote = pattern.notes.values.single;
        expect(restoredNote.id, equals(note.id));
        restoredNote.key = 72;
        restoredNote.offset = 192;
        restoredNote.length = 24;
        restoredNote.velocity = 0.9;
        restoredNote.pan = 0.5;

        command.execute(project);
        expect(pattern.notes, isEmpty);

        command.rollback(project);
        final restoredAgain = pattern.notes.values.single;
        expect(restoredAgain.id, equals(note.id));
        expect(restoredAgain.key, equals(60));
        expect(restoredAgain.offset, equals(64));
        expect(restoredAgain.length, equals(48));
        expect(restoredAgain.velocity, equals(0.5));
        expect(restoredAgain.pan, equals(-0.25));
      },
    );
  });

  group('SetNoteAttributeCommand', () {
    test('execute and rollback update a note attribute', () {
      final pattern = addPatternToProject('Pattern');
      final note = addNote(pattern, key: 60, offset: 64, length: 48);
      final command = SetNoteAttributeCommand(
        patternID: pattern.id,
        noteID: note.id,
        attribute: NoteAttribute.velocity,
        oldValue: note.velocity,
        newValue: 0.25,
      );

      command.execute(project);
      expect(note.velocity, equals(0.25));

      command.rollback(project);
      expect(note.velocity, equals(0.75));
    });

    test('execute throws when pattern does not exist', () {
      final command = SetNoteAttributeCommand(
        patternID: getId(),
        noteID: getId(),
        attribute: NoteAttribute.key,
        oldValue: 60,
        newValue: 61,
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });

    test('execute throws when note does not exist', () {
      final pattern = addPatternToProject('Pattern');
      final command = SetNoteAttributeCommand(
        patternID: pattern.id,
        noteID: getId(),
        attribute: NoteAttribute.key,
        oldValue: 60,
        newValue: 61,
      );

      expect(() => command.execute(project), throwsA(isA<StateError>()));
    });
  });
}
