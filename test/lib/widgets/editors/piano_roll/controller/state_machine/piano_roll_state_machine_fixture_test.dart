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

import 'piano_roll_state_machine_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PianoRollStateMachineTestFixture fixture;

  setUp(() {
    fixture = PianoRollStateMachineTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('fixture', () {
    test('creates an active pattern, track, and controller', () {
      expect(
        fixture.project.sequence.activePatternID,
        equals(fixture.pattern.id),
      );
      expect(
        fixture.project.sequence.activeTrackID,
        equals(TrackIds.instrument),
      );
      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.tool, equals(EditorTool.pencil));
    });

    test('controller owns an inert state machine shell', () {
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.stateMachine.controller, same(fixture.controller));
      expect(fixture.pointerSessionState.parentState, same(fixture.idleState));
      expect(
        fixture.selectionBoxState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.eraseNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.moveNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.resizeNotesState.parentState,
        same(fixture.pointerSessionState),
      );
      expect(
        fixture.createNoteState.parentState,
        same(fixture.pointerSessionState),
      );
    });

    test('controller dispose is idempotent', () {
      fixture.controller.dispose();
      fixture.controller.dispose();
    });

    test('controller dispose clears in-progress transient preview state', () {
      fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

      expect(fixture.transientNotes, hasLength(1));
      expect(fixture.viewModel.pressedNote, isNotNull);

      fixture.controller.dispose();

      fixture.expectNoActiveTransientState();
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('controller dispose clears an active selection box', () {
      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.controller.dispose();

      fixture.expectNoActiveTransientState();
      expect(fixture.activeInteractionFamily, isNull);
    });

    test(
      'pointer-down gestures classify through the public controller path',
      () {
        final selectionFixture = PianoRollStateMachineTestFixture.create();
        try {
          selectionFixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
          expect(
            selectionFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.selectionBox),
          );
        } finally {
          selectionFixture.dispose();
        }

        final moveFixture = PianoRollStateMachineTestFixture.create();
        try {
          final note = moveFixture.addNote(key: 60, offset: 100, length: 48);
          moveFixture.pointerDown(
            key: 60.5,
            offset: 100,
            noteUnderCursor: note.id,
          );
          expect(
            moveFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.moveNotes),
          );
        } finally {
          moveFixture.dispose();
        }

        final resizeFixture = PianoRollStateMachineTestFixture.create();
        try {
          final note = resizeFixture.addNote(key: 64, offset: 220, length: 96);
          resizeFixture.pointerDown(
            key: 64.5,
            offset: 316,
            noteUnderCursor: note.id,
            isResize: true,
          );
          expect(
            resizeFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.resizeNotes),
          );
        } finally {
          resizeFixture.dispose();
        }

        final createFixture = PianoRollStateMachineTestFixture.create();
        try {
          createFixture.pointerDown(key: 60.5, offset: 100);
          expect(
            createFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.createNote),
          );
        } finally {
          createFixture.dispose();
        }

        final eraseFixture = PianoRollStateMachineTestFixture.create();
        try {
          final note = eraseFixture.addNote(key: 60, offset: 100, length: 48);
          eraseFixture.pointerDown(
            key: 60.5,
            offset: 100,
            noteUnderCursor: note.id,
            buttons: kSecondaryMouseButton,
          );
          expect(
            eraseFixture.activeInteractionFamily,
            equals(PianoRollInteractionFamily.erase),
          );
        } finally {
          eraseFixture.dispose();
        }
      },
    );
  });
}
