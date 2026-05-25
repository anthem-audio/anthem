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

  group('routing', () {
    test('selection-box routing latches a machine route until pointer up', () {
      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.selectionBox),
      );
      expect(
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.selectionBox),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
      expect(
        fixture.stateMachine.currentState,
        same(fixture.selectionBoxState),
      );

      fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('pointer cancel clears the latched route', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));

      fixture.pointerCancel(key: 61.5, offset: 173.8, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('erase routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: note.id,
        buttons: kSecondaryMouseButton,
      );

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.erase),
      );
      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerMove(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.eraseNotesState));

      fixture.pointerUp(key: 60.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('move routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.moveNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));
      expect(fixture.moveNotesState.sessionData, isNotNull);

      fixture.pointerMove(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.moveNotesState));

      fixture.pointerUp(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('resize routing latches a machine route until pointer up', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

      fixture.pointerDown(
        key: 60.5,
        offset: 196,
        noteUnderCursor: note.id,
        isResize: true,
      );

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.resizeNotes),
      );
      expect(fixture.stateMachine.currentState, same(fixture.resizeNotesState));
      expect(fixture.resizeNotesState.sessionData, isNotNull);

      fixture.pointerMove(key: 60.5, offset: 240, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.resizeNotesState));

      fixture.pointerUp(key: 60.5, offset: 240, alt: true);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('create routing latches a machine route until pointer up', () {
      fixture.pointerDown(key: 60.5, offset: 100);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.createNote),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
      expect(fixture.createNoteState.sessionData, isNotNull);

      fixture.pointerMove(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));

      fixture.pointerUp(key: 61.5, offset: 120);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });

    test('unsupported raw pointer sessions are ignored', () {
      final localPosition = fixture.localPositionFor(key: 60.5, offset: 100);

      fixture.rawPointerDown(
        localPosition: localPosition,
        buttons: kMiddleMouseButton,
      );

      expect(fixture.activeInteractionFamily, isNull);
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.notes, isEmpty);
      fixture.expectNoActiveTransientState();
    });

    test('pointer-session parent stores drag start derived context', () {
      final note = fixture.addNote(key: 64, offset: 220, length: 96);

      fixture.pointerDown(
        key: 64.5,
        offset: 316,
        noteUnderCursor: note.id,
        isResize: true,
      );

      final startContext = fixture.pointerSessionState.startPointerContext;
      expect(startContext, isNotNull);
      expect(startContext!.targetRealNoteId, equals(note.id));
      expect(startContext.isResizeHandleTarget, isTrue);
      expect(startContext.target, isA<PianoRollResizeHandlePointerTarget>());
      expect(startContext.key, closeTo(64.5, 0.0001));
      expect(startContext.offset, closeTo(316, 0.0001));
      expect(fixture.pointerSessionState.dragStartRealNoteId, equals(note.id));
      expect(fixture.pointerSessionState.dragStartIsResizeHandle, isTrue);
    });

    test('pointer-session parent updates current derived context on move', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 173.8, alt: true);

      final currentContext = fixture.pointerSessionState.currentPointerContext;
      expect(currentContext, isNotNull);
      expect(currentContext!.target, isA<PianoRollEmptyPointerTarget>());
      expect(currentContext.key, closeTo(61.5, 0.0001));
      expect(currentContext.offset, closeTo(173.8, 0.0001));
      expect(fixture.pointerSessionState.dragStartKey, closeTo(60.5, 0.0001));
      expect(fixture.pointerSessionState.dragStartOffset, closeTo(100, 0.0001));
    });

    test('raw controller input uses the latest rendered view metrics', () {
      fixture.viewModel.timeView = TimeRange(480, 960);
      fixture.viewModel.keyHeight = 20;
      fixture.viewModel.keyValueAtTop = 72;
      fixture.syncRenderedViewMetrics();

      const localPosition = Offset(240, 60);
      fixture.rawPointerDown(localPosition: localPosition);

      final startContext = fixture.pointerSessionState.startPointerContext;
      expect(startContext, isNotNull);
      expect(
        startContext!.offset,
        closeTo(
          pixelsToTime(
            timeViewStart: 480,
            timeViewEnd: 960,
            viewPixelWidth:
                PianoRollStateMachineTestFixture.pianoRollSize.width,
            pixelOffsetFromLeft: localPosition.dx,
          ),
          0.0001,
        ),
      );
      expect(
        startContext.key,
        closeTo(
          pixelsToKeyValue(
            keyHeight: 20,
            keyValueAtTop: 72,
            pixelOffsetFromTop: localPosition.dy,
          ),
          0.0001,
        ),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
    });

    test('negative-time create does not initialize a create-note session', () {
      fixture.pointerDown(key: 60.5, offset: -1);

      expect(
        fixture.activeInteractionFamily,
        equals(PianoRollInteractionFamily.createNote),
      );
      expect(fixture.stateMachine.currentState, same(fixture.createNoteState));
      expect(fixture.createNoteState.sessionData, isNull);
      expect(fixture.notes, isEmpty);

      fixture.pointerUp(key: 60.5, offset: -1);

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.activeInteractionFamily, isNull);
    });
  });
}
