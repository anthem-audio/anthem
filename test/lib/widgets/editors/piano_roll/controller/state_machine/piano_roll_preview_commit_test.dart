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

  group('preview vs commit regression', () {
    test('move preview leaves the real note unchanged until commit', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 48);

      fixture.pointerDown(key: 60.5, offset: 100, noteUnderCursor: note.id);
      fixture.pointerMove(key: 62.5, offset: 155);

      final expectedOffset = fixture.snappedTime(
        155,
        round: true,
        startTime: 100,
      );
      final preview = fixture.noteOverrideById(note.id);

      expect(fixture.noteById(note.id).offset, equals(100));
      expect(fixture.noteById(note.id).key, equals(60));
      expect(preview, isNotNull);
      expect(preview!.offset, equals(expectedOffset));
      expect(preview.key, equals(62));
      expect(fixture.viewModel.pressedNote, equals(note.id));

      fixture.pointerUp(key: 62.5, offset: 155);

      expect(fixture.noteById(note.id).offset, equals(expectedOffset));
      expect(fixture.noteById(note.id).key, equals(62));
      fixture.expectNoActiveTransientState();
    });

    test('resize preview leaves the real note unchanged until commit', () {
      final note = fixture.addNote(key: 60, offset: 100, length: 96);

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
      final preview = fixture.noteOverrideById(note.id);

      expect(fixture.noteById(note.id).length, equals(96));
      expect(preview, isNotNull);
      expect(preview!.length, equals(expectedLength));
      expect(fixture.viewModel.pressedNote, equals(note.id));

      fixture.pointerUp(key: 60.5, offset: 250);

      expect(fixture.noteById(note.id).length, equals(expectedLength));
      fixture.expectNoActiveTransientState();
    });

    test('create preview stays transient until commit', () {
      fixture.viewModel.cursorNoteLength = 48;

      fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

      expect(fixture.notes, isEmpty);
      expect(fixture.transientNotes, hasLength(1));
      final createdNoteId = fixture.transientNotes.single.id;

      fixture.pointerMove(key: 63.5, offset: 173.8, alt: true);

      final preview = fixture.transientNoteById(createdNoteId);
      expect(fixture.notes, isEmpty);
      expect(preview.key, equals(63));
      expect(preview.offset, equals(173));
      expect(preview.length, equals(48));
      expect(fixture.viewModel.pressedNote, equals(createdNoteId));

      fixture.pointerUp(key: 63.5, offset: 173.8, alt: true);

      final committed = fixture.noteById(createdNoteId);
      expect(committed.key, equals(63));
      expect(committed.offset, equals(173));
      expect(committed.length, equals(48));
      fixture.expectNoActiveTransientState();
    });

    test(
      'single-note duplicate preview keeps the duplicate transient until commit',
      () {
        final note = fixture.addNote(key: 60, offset: 100, length: 48);

        fixture.pointerDown(
          key: 60.5,
          offset: 100,
          noteUnderCursor: note.id,
          shift: true,
        );
        expect(
          fixture.notes.map((note) => note.id).toList(growable: false),
          orderedEquals([note.id]),
        );
        expect(fixture.transientNotes, hasLength(1));
        final duplicateId = fixture.transientNotes.single.id;

        fixture.pointerMove(key: 62.5, offset: 200);

        final expectedOffset = fixture.snappedTime(
          200,
          round: true,
          startTime: 100,
        );
        final movedDuplicatePreview = fixture.transientNoteById(duplicateId);

        expect(fixture.noteById(note.id).offset, equals(100));
        expect(fixture.noteById(note.id).key, equals(60));
        expect(fixture.pattern.noteOverrides, isEmpty);
        expect(movedDuplicatePreview.offset, equals(expectedOffset));
        expect(movedDuplicatePreview.key, equals(62));
        expect(fixture.viewModel.pressedNote, equals(duplicateId));
        expect(
          fixture.viewModel.selectedNotes.nonObservableInner,
          equals({duplicateId}),
        );

        fixture.pointerUp(key: 62.5, offset: 200);

        expect(fixture.noteById(note.id).offset, equals(100));
        expect(fixture.noteById(note.id).key, equals(60));
        expect(fixture.noteById(duplicateId).offset, equals(expectedOffset));
        expect(fixture.noteById(duplicateId).key, equals(62));
        fixture.expectNoActiveTransientState();
      },
    );

    test(
      'selected-group duplicate preview keeps clones transient until commit',
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

        final clonedIds = fixture.viewModel.selectedNotes.nonObservableInner
            .toSet();
        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id}),
        );
        expect(fixture.transientNotes, hasLength(2));

        fixture.pointerMove(key: 61.5, offset: 200);

        final movedDistance =
            fixture.snappedTime(200, round: true, startTime: 100) - 100;
        final previewPositions = clonedIds.map((clonedId) {
          final note = fixture.transientNoteById(clonedId);
          return (key: note.key, offset: note.offset);
        }).toSet();

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));
        expect(fixture.pattern.noteOverrides, isEmpty);
        expect(
          previewPositions,
          equals({
            (key: 61, offset: 100 + movedDistance),
            (key: 65, offset: 180 + movedDistance),
          }),
        );

        fixture.pointerUp(key: 61.5, offset: 200);

        expect(fixture.noteById(noteA.id).offset, equals(100));
        expect(fixture.noteById(noteA.id).key, equals(60));
        expect(fixture.noteById(noteB.id).offset, equals(180));
        expect(fixture.noteById(noteB.id).key, equals(64));

        final committedClonePositions = clonedIds.map((clonedId) {
          final note = fixture.noteById(clonedId);
          return (key: note.key, offset: note.offset);
        }).toSet();
        expect(committedClonePositions, equals(previewPositions));
        fixture.expectNoActiveTransientState();
      },
    );
  });
}
