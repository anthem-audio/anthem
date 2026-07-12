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

  group('resize interactions', () {
    test(
      'resize on an unselected note clears the selection and only resizes that note',
      () {
        final selectedNote = fixture.addNote(key: 60, offset: 100, length: 96);
        final resizedNote = fixture.addNote(key: 64, offset: 220, length: 96);
        fixture.selectNotes([selectedNote.id]);

        fixture.pointerDown(
          key: 64.5,
          offset: 316,
          noteUnderCursor: resizedNote.id,
          isResize: true,
        );
        fixture.pointerMove(key: 64.5, offset: 360, alt: true);
        fixture.pointerUp(key: 64.5, offset: 360, alt: true);

        fixture.expectSelection(const []);
        expect(fixture.noteById(selectedNote.id).length, equals(96));
        expect(fixture.noteById(resizedNote.id).length, equals(140));
      },
    );

    test(
      'resizes a single note with snapping and updates cursor note parameters',
      () {
        final note = fixture.addNote(
          key: 60,
          offset: 100,
          length: 96,
          velocity: 0.4,
          pan: -0.2,
        );
        fixture.viewModel.cursorNoteLength = 12;
        fixture.viewModel.cursorNoteVelocity = 0.1;
        fixture.viewModel.cursorNotePan = 0.8;

        fixture.pointerDown(
          key: 60.5,
          offset: 196,
          noteUnderCursor: note.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: 250);

        final snappedOriginal = fixture.snappedTime(196, round: true);
        final snappedEvent = fixture.snappedTime(250, round: true);
        final expectedLength = 96 + (snappedEvent - snappedOriginal);

        expect(fixture.noteById(note.id).length, equals(96));
        expect(
          fixture.noteOverrideById(note.id)?.length,
          equals(expectedLength),
        );
        expect(fixture.viewModel.cursorNoteLength, equals(expectedLength));
        expect(fixture.viewModel.cursorNoteVelocity, equals(0.4));
        expect(fixture.viewModel.cursorNotePan, equals(-0.2));

        fixture.pointerUp(key: 60.5, offset: 250);

        fixture.project.undo();
        expect(fixture.noteById(note.id).length, equals(96));

        fixture.project.redo();
        expect(fixture.noteById(note.id).length, equals(expectedLength));
      },
    );

    test('resize notes overrides the global cursor until release', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

      fixture.pointerDown(
        key: 60.5,
        offset: 196,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 240, alt: true);

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        SystemMouseCursors.resizeLeftRight,
      );

      fixture.pointerUp(key: 60.5, offset: 240, alt: true);

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        MouseCursor.defer,
      );
    });

    test('pointer cancel still commits a resize session and can be undone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

      fixture.pointerDown(
        key: 60.5,
        offset: 196,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 240, alt: true);
      fixture.pointerCancel(key: 60.5, offset: 240, alt: true);

      expect(fixture.noteById(note.id).length, equals(140));

      fixture.project.undo();
      expect(fixture.noteById(note.id).length, equals(96));
    });

    test(
      'resizing a selected group applies the same diff to every selected note',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 96);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 144);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 196,
          noteUnderCursor: noteA.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: 221, alt: true);
        fixture.pointerUp(key: 60.5, offset: 221, alt: true);

        expect(fixture.noteById(noteA.id).length, equals(121));
        expect(fixture.noteById(noteB.id).length, equals(169));

        fixture.project.undo();
        expect(fixture.noteById(noteA.id).length, equals(96));
        expect(fixture.noteById(noteB.id).length, equals(144));
      },
    );

    test('alt resize clamps the minimum note length to 1 tick', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 10);

      fixture.pointerDown(
        key: 60.5,
        offset: 110,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 50, alt: true);
      fixture.pointerUp(key: 60.5, offset: 50, alt: true);

      expect(fixture.noteById(note.id).length, equals(1));
    });

    test('snapped resize retreats to the nearest valid snap interval', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 192);

      fixture.pointerDown(
        key: 60.5,
        offset: 292,
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(key: 60.5, offset: 96);
      fixture.pointerUp(key: 60.5, offset: 96);

      expect(fixture.noteById(note.id).length, equals(fixture.snapSizeAt(100)));
    });

    test(
      'snapped resize does not immediately grow notes smaller than the snap size',
      () {
        final snapSize = fixture.snapSizeAt(100);
        expect(snapSize, greaterThan(1));
        final originalLength = snapSize ~/ 2;
        final note = fixture.addNote(
          key: 60,
          offset: 100,
          length: originalLength,
        );
        final resizeOffset = note.offset + originalLength;

        fixture.pointerDown(
          key: 60.5,
          offset: resizeOffset.toDouble(),
          noteUnderCursor: note.id,
          isResize: true,
        );
        fixture.pointerMove(key: 60.5, offset: resizeOffset.toDouble());

        expect(fixture.noteOverrideById(note.id), isNull);
        expect(fixture.viewModel.cursorNoteLength, equals(originalLength));

        fixture.pointerUp(key: 60.5, offset: resizeOffset.toDouble());

        expect(fixture.noteById(note.id).length, equals(originalLength));
      },
    );

    test('snapped resize can return a small note to its original length', () {
      final snapSize = fixture.snapSizeAt(100);
      expect(snapSize, greaterThan(1));
      final originalLength = snapSize ~/ 2;
      final note = fixture.addNote(
        key: 60,
        offset: 100,
        length: originalLength,
      );
      final resizeOffset = note.offset + originalLength;

      fixture.pointerDown(
        key: 60.5,
        offset: resizeOffset.toDouble(),
        noteUnderCursor: note.id,
        isResize: true,
      );
      fixture.pointerMove(
        key: 60.5,
        offset: (resizeOffset + snapSize).toDouble(),
      );

      expect(
        fixture.noteOverrideById(note.id)?.length,
        equals(originalLength + snapSize),
      );

      fixture.pointerMove(key: 60.5, offset: resizeOffset.toDouble());

      expect(fixture.noteOverrideById(note.id), isNull);

      fixture.pointerUp(key: 60.5, offset: resizeOffset.toDouble());

      expect(fixture.noteById(note.id).length, equals(originalLength));
    });

    test(
      'synthetic resize hints without a rendered resize hit are ignored',
      () {
        fixture.pointerDown(key: 60.5, offset: 196, isResize: true);

        expect(
          fixture.activeInteractionFamily,
          equals(PianoRollInteractionFamily.createNote),
        );
        expect(
          fixture.stateMachine.currentState,
          same(fixture.createNoteState),
        );
      },
    );
  });
}
