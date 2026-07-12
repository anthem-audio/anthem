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

    test('does not edit when the nearest stem is outside the hit radius', () {
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

    test('interpolates stem values across fast drags', () {
      final startNote = fixture.addNote(offset: 120);
      final middleNote = fixture.addNote(offset: 240);
      final endNote = fixture.addNote(offset: 360);
      final afterEndNote = fixture.addNote(offset: 480);
      final outsideNote = fixture.addNote(offset: 600);

      fixture.pointerDown(offset: 120, normalizedY: 0);
      fixture.pointerMove(offset: 360, normalizedY: 1);
      fixture.pointerUp(offset: 360, normalizedY: 1);

      expect(startNote.velocity, equals(0));
      expect(middleNote.velocity, closeTo(0.5, 1e-9));
      expect(endNote.velocity, equals(1));
      expect(afterEndNote.velocity, equals(0.8));
      expect(outsideNote.velocity, equals(0.8));
    });

    test('uses nearest stem edges as the drag range', () {
      final beforeStartNote = fixture.addNote(offset: 0);
      final startNote = fixture.addNote(offset: 120);
      final middleNote = fixture.addNote(offset: 240);
      final endNote = fixture.addNote(offset: 360);
      final afterEndNote = fixture.addNote(offset: 480);

      fixture.pointerDown(offset: 120, normalizedY: 0);
      fixture.pointerMove(offset: 360, normalizedY: 1);
      fixture.pointerUp(offset: 360, normalizedY: 1);

      expect(beforeStartNote.velocity, equals(0.8));
      expect(startNote.velocity, equals(0));
      expect(middleNote.velocity, closeTo(0.5, 1e-9));
      expect(endNote.velocity, equals(1));
      expect(afterEndNote.velocity, equals(0.8));
    });

    test('interpolates nearest stem edges in reverse drag direction', () {
      final outsideNote = fixture.addNote(offset: 0);
      final endNote = fixture.addNote(offset: 120);
      final middleNote = fixture.addNote(offset: 240);
      final startNote = fixture.addNote(offset: 360);

      fixture.pointerDown(offset: 360, normalizedY: 0);
      fixture.pointerMove(offset: 120, normalizedY: 1);
      fixture.pointerUp(offset: 120, normalizedY: 1);

      expect(outsideNote.velocity, equals(0.8));
      expect(endNote.velocity, equals(1));
      expect(middleNote.velocity, closeTo(0.5, 1e-9));
      expect(startNote.velocity, equals(0));
    });

    test('point edits only the nearest stem offset', () {
      final firstNote = fixture.addNote(offset: 120);
      final sameStemNote = fixture.addNote(offset: 120, velocity: 0.6);
      final secondNote = fixture.addNote(offset: 200);
      final outsideNote = fixture.addNote(offset: 300);

      fixture.pointerDown(offset: 150, normalizedY: 0.3);
      fixture.pointerUp(offset: 150, normalizedY: 0.3);

      expect(firstNote.velocity, equals(0.3));
      expect(sameStemNote.velocity, equals(0.3));
      expect(secondNote.velocity, equals(0.8));
      expect(outsideNote.velocity, equals(0.8));
    });

    test('latches selected candidates for the pointer session', () {
      final selectedNote = fixture.addNote(offset: 0);
      final laterSelectedNote = fixture.addNote(offset: 240);
      fixture.selectNotes([selectedNote.id]);

      fixture.pointerDown(offset: 0, normalizedY: 0);
      fixture.selectNotes([selectedNote.id, laterSelectedNote.id]);
      fixture.pointerMove(offset: 240, normalizedY: 1);
      fixture.pointerUp(offset: 240, normalizedY: 1);

      expect(selectedNote.velocity, equals(0));
      expect(laterSelectedNote.velocity, equals(0.8));
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
