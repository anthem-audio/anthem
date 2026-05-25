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

  group('erase interactions', () {
    test(
      'secondary click deletes a note, clears selection, and supports undo',
      () {
        final note = fixture.addNote(key: 60, offset: 96, length: 48);
        fixture.addNote(key: 64, offset: 288, length: 48);
        fixture.selectNotes([note.id]);

        fixture.pointerDown(
          key: 60.5,
          offset: 96,
          noteUnderCursor: note.id,
          buttons: kSecondaryMouseButton,
        );

        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );
        fixture.expectSelection(const []);

        fixture.pointerUp(key: 60.5, offset: 96);

        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );

        fixture.project.undo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          contains(note.id),
        );

        fixture.project.redo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          isNot(contains(note.id)),
        );
        fixture.expectNoActiveTransientState();
      },
    );

    test('eraser tool deletes with the primary button', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);
      fixture.setTool(EditorTool.eraser);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: note.id,
        buttons: kPrimaryMouseButton,
      );
      fixture.pointerUp(key: 60.5, offset: 96);

      expect(fixture.notes, isEmpty);
    });

    test('drag erase deletes multiple notes and undoes as one action', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 60, offset: 192, length: 48);
      final noteC = fixture.addNote(key: 60, offset: 288, length: 48);

      fixture.pointerDown(
        key: 60.5,
        offset: 96,
        noteUnderCursor: noteA.id,
        buttons: kSecondaryMouseButton,
      );
      fixture.pointerMove(key: 60.5, offset: 336);
      fixture.pointerUp(key: 60.5, offset: 336);

      expect(fixture.notes, isEmpty);

      fixture.project.undo();
      expect(
        fixture.notes.map((note) => note.id).toSet(),
        equals({noteA.id, noteB.id, noteC.id}),
      );

      fixture.project.redo();
      expect(fixture.notes, isEmpty);
    });

    test(
      'secondary click on a resize handle outside the note body does not delete',
      () {
        final note = fixture.addNote(key: 60, offset: 96, length: 48);

        fixture.pointerDown(
          key: 60.5,
          offset: 144,
          noteUnderCursor: note.id,
          buttons: kSecondaryMouseButton,
        );
        fixture.pointerUp(key: 60.5, offset: 144);

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([note.id]),
        );
      },
    );

    test(
      'overlapping notes are ignored until the cursor leaves and re-enters',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 120);
        final noteB = fixture.addNote(key: 60, offset: 120, length: 120);

        fixture.pointerDown(
          key: 60.5,
          offset: 130,
          noteUnderCursor: noteA.id,
          buttons: kSecondaryMouseButton,
        );

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 131);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 260);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 300);
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );

        fixture.pointerMove(key: 60.5, offset: 150);
        expect(fixture.notes, isEmpty);

        fixture.pointerUp(key: 60.5, offset: 150);
      },
    );
  });
}
