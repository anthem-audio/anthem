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

import 'stem_editor_state_machine_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PianoRollStemEditorStateMachineTestFixture fixture;

  setUp(() {
    fixture = PianoRollStemEditorStateMachineTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('fixture', () {
    test('creates an active pattern and inert state machine shell', () {
      expect(
        fixture.project.sequence.activePatternID,
        equals(fixture.pattern.id),
      );
      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.activeStem, equals(PianoRollStem.velocity));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.pointerSessionState.parentState, same(fixture.idleState));
      expect(fixture.editState.parentState, same(fixture.pointerSessionState));
    });

    test('dispose is idempotent', () {
      fixture.stateMachine.dispose();
      fixture.stateMachine.dispose();
    });

    test('dispose clears an in-progress note override', () {
      final note = fixture.addNote();

      fixture.pointerDown();
      expect(fixture.noteOverrideById(note.id), isNotNull);

      fixture.stateMachine.dispose();

      expect(fixture.pattern.noteOverrides, isEmpty);
    });
  });

  group('stem edit state', () {
    test('uses pattern overrides until pointerUp commits the command', () {
      final note = fixture.addNote();

      fixture.pointerDown();

      expect(fixture.stateMachine.currentState, same(fixture.editState));
      expect(note.velocity, equals(0.8));
      expect(fixture.noteOverrideById(note.id), isNotNull);
      expect(fixture.noteOverrideById(note.id)!.velocity, equals(0.25));
      expect(fixture.viewModel.cursorNoteVelocity, equals(0.25));

      fixture.pointerUp();

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(note.velocity, equals(0.25));
      expect(fixture.pattern.noteOverrides, isEmpty);

      fixture.project.undo();
      expect(note.velocity, equals(0.8));
    });

    test('edits pan when pan is the active stem', () {
      final note = fixture.addNote();
      fixture.viewModel.activeStem = PianoRollStem.pan;

      fixture.pointerDown(normalizedY: 0.75);
      fixture.pointerUp(normalizedY: 0.75);

      expect(note.pan, equals(0.5));
      expect(note.velocity, equals(0.8));
      expect(fixture.viewModel.cursorNotePan, equals(0.5));

      fixture.project.undo();
      expect(note.pan, equals(0));
    });

    test('edits selected committed notes at the targeted offset', () {
      final note = fixture.addNote();
      final selectedNote = fixture.addNote(velocity: 0.4);
      final unselectedNote = fixture.addNote(velocity: 0.6);
      fixture.selectNotes([note.id, selectedNote.id]);

      fixture.pointerDown(normalizedY: 0.3);
      fixture.pointerUp(normalizedY: 0.3);

      expect(note.velocity, equals(0.3));
      expect(selectedNote.velocity, equals(0.3));
      expect(unselectedNote.velocity, equals(0.6));
    });

    test('does not edit when no stem is close enough', () {
      final note = fixture.addNote();

      fixture.pointerDown(offset: 1000);
      fixture.pointerUp(offset: 1000);

      expect(note.velocity, equals(0.8));
      expect(fixture.pattern.noteOverrides, isEmpty);
    });

    test('latches the active stem for the pointer session', () {
      final note = fixture.addNote();

      fixture.pointerDown(normalizedY: 0.2, pointer: 7);
      fixture.viewModel.activeStem = PianoRollStem.pan;
      fixture.pointerMove(normalizedY: 0.75, pointer: 7);
      fixture.pointerUp(normalizedY: 0.75, pointer: 7);

      expect(note.velocity, equals(0.75));
      expect(note.pan, equals(0));
    });

    test('clears previews without committing if the pattern disappears', () {
      final note = fixture.addNote();

      fixture.pointerDown();
      expect(fixture.noteOverrideById(note.id), isNotNull);

      fixture.project.sequence.patterns.remove(fixture.pattern.id);

      expect(() => fixture.pointerUp(), returnsNormally);
      expect(fixture.pattern.noteOverrides, isEmpty);
      expect(note.velocity, equals(0.8));
    });

    test('ignores preview-only notes', () {
      final previewNote = fixture.addPreviewNote(velocity: 0.4);
      fixture.selectNotes([previewNote.id]);

      fixture.pointerDown(normalizedY: 0.3);
      fixture.pointerUp(normalizedY: 0.3);

      expect(fixture.transientNoteById(previewNote.id).velocity, equals(0.4));
      expect(fixture.notes, isEmpty);
      expect(fixture.transientNotes, hasLength(1));
      expect(fixture.pattern.noteOverrides, isEmpty);
    });
  });
}
