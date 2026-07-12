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

  group('move interactions', () {
    test('moves a single note with snapping and supports undo and redo', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);
      fixture.selectNotes([1004]);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 155);

      final movedNote = fixture.noteById(note.id);
      final movedNoteOverride = fixture.noteOverrideById(note.id);
      final expectedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      expect(movedNote.offset, equals(100));
      expect(movedNote.key, equals(60));
      expect(movedNoteOverride, isNotNull);
      expect(movedNoteOverride!.offset, equals(expectedOffset));
      expect(movedNoteOverride.key, equals(62));

      fixture.pointerUp(key: 62.5, offset: 155);

      fixture.expectSelection(const []);
      fixture.expectNoActiveTransientState();

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));

      fixture.project.redo();
      expect(fixture.noteById(note.id).offset, equals(expectedOffset));
      expect(fixture.noteById(note.id).key, equals(62));
    });

    test('pointer cancel still commits a move session and can be undone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 173.8, alt: true);
      fixture.pointerCancel(key: 61.5, offset: 173.8, alt: true);

      expect(fixture.noteById(note.id).offset, equals(173));
      expect(fixture.noteById(note.id).key, equals(61));

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
    });

    test('moves a single note without snapping when alt is held', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 155.9, alt: true);
      fixture.pointerUp(key: 61.5, offset: 155.9, alt: true);

      expect(fixture.noteById(note.id).offset, equals(155));
      expect(fixture.noteById(note.id).key, equals(61));
    });

    test('modifier changes during drag recompute the move preview', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 61.5, offset: 155.9);

      final snappedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      expect(fixture.noteOverrideById(note.id)?.offset, equals(snappedOffset));

      fixture.modifierPressed(PianoRollModifierKey.alt);

      expect(fixture.noteOverrideById(note.id)?.offset, equals(155));

      fixture.modifierReleased(PianoRollModifierKey.alt);

      expect(fixture.noteOverrideById(note.id)?.offset, equals(snappedOffset));
    });

    test('holding shift during drag locks pitch changes', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 200, shift: true);
      fixture.pointerUp(key: 62.5, offset: 200, shift: true);

      expect(fixture.noteById(note.id).key, equals(60));
      expect(
        fixture.noteById(note.id).offset,
        equals(fixture.snappedTime(200, round: true, startTime: 100)),
      );
    });

    test('holding ctrl during drag locks time changes', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 200, ctrl: true);
      fixture.pointerUp(key: 62.5, offset: 200, ctrl: true);

      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(62));
    });

    test('single-note shift drag duplicates and moves the clone', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 100,
        noteUnderCursor: note.id,
        shift: true,
      );

      expect(fixture.notes.length, equals(1));
      expect(fixture.transientNotes, hasLength(1));
      final duplicateId = fixture.transientNotes.single.id;

      fixture.pointerMove(key: 62.5, offset: 200);
      fixture.pointerUp(key: 62.5, offset: 200);

      final original = fixture.noteById(note.id);
      final duplicate = fixture.noteById(duplicateId);
      expect(original.offset, equals(100));
      expect(original.key, equals(60));
      expect(
        duplicate.offset,
        equals(fixture.snappedTime(200, round: true, startTime: 100)),
      );
      expect(duplicate.key, equals(62));

      fixture.project.undo();
      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
      expect(
        fixture.notes.map((note) => note.id).toList(),
        orderedEquals([note.id]),
      );
    });

    test('moves a selected group without duplicating it', () {
      final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: noteA.id);
      fixture.pointerMove(key: 62.5, offset: 190);
      fixture.pointerUp(key: 62.5, offset: 190);

      final movedDistance =
          fixture.snappedTime(190, round: true, startTime: 100) - 100;
      expect(fixture.noteById(noteA.id).offset, equals(100 + movedDistance));
      expect(fixture.noteById(noteB.id).offset, equals(180 + movedDistance));
      expect(fixture.noteById(noteA.id).key, equals(62));
      expect(fixture.noteById(noteB.id).key, equals(66));
      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test('selection move clamps the entire group at the pattern start', () {
      final noteA = fixture.addNote(key: 60, offset: 20, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 100, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.pointerDown(key: 60.5, offset: 20, noteUnderCursor: noteA.id);
      fixture.pointerMove(key: 58.5, offset: -40, alt: true);
      fixture.pointerUp(key: 58.5, offset: -40, alt: true);

      expect(fixture.noteById(noteA.id).offset, equals(0));
      expect(fixture.noteById(noteB.id).offset, equals(80));
      expect(fixture.noteById(noteA.id).key, equals(58));
      expect(fixture.noteById(noteB.id).key, equals(62));
    });

    test(
      'shift drag on a selected group duplicates the selection and moves the clones',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: noteA.id,
          shift: true,
        );

        expect(fixture.notes.length, equals(2));
        expect(fixture.transientNotes, hasLength(2));
        final clonedIds = fixture.viewModel.selectedNotes.nonObservableInner
            .toSet();
        expect(clonedIds, hasLength(2));
        expect(clonedIds.contains(noteA.id), isFalse);
        expect(clonedIds.contains(noteB.id), isFalse);

        fixture.pointerMove(key: 61.5, offset: 200);
        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));

        final movedDistance =
            fixture.snappedTime(200, round: true, startTime: 100) - 100;
        final clonePositions = clonedIds.map((clonedId) {
          final clone = fixture.noteById(clonedId);
          return (key: clone.key, offset: clone.offset);
        }).toSet();
        expect(
          clonePositions,
          equals({
            (key: 61, offset: 100 + movedDistance),
            (key: 65, offset: 180 + movedDistance),
          }),
        );
      },
    );

    test(
      'undoing a duplicated selection move removes the clones in one action',
      () {
        final noteA = fixture.addNote(key: 60, offset: 100, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 180, length: 48);
        fixture.selectNotes([noteA.id, noteB.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: noteA.id,
          shift: true,
        );
        fixture.pointerMove(key: 61.5, offset: 200);
        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.notes, hasLength(4));

        fixture.project.undo();

        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id}),
        );
        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));
      },
    );

    test('move clamps at the pattern start and valid note range', () {
      final note = fixture.addNote(key: 127, offset: 10, length: 48);

      fixture.pointerDown(key: 127.5, offset: 10, noteUnderCursor: note.id);
      fixture.pointerMove(key: 200.5, offset: -50, alt: true);
      fixture.pointerUp(key: 200.5, offset: -50, alt: true);

      expect(fixture.noteById(note.id).offset, equals(0));
      expect(fixture.noteById(note.id).key, equals(maxKeyValue.round()));
    });
  });
}
