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

  group('create-note interactions', () {
    test(
      'empty-space pencil press creates a snapped note using cursor parameters',
      () {
        fixture.viewModel.cursorNoteLength = 48;
        fixture.viewModel.cursorNoteVelocity = 0.25;
        fixture.viewModel.cursorNotePan = 0.6;

        fixture.pointerDown(key: 60.9, offset: 145.2);

        expect(fixture.notes, isEmpty);
        expect(fixture.transientNotes, hasLength(1));
        final note = fixture.transientNotes.single;
        expect(note.key, equals(60));
        expect(note.offset, equals(fixture.snappedTime(145)));
        expect(note.length, equals(48));
        expect(note.velocity, equals(0.25));
        expect(note.pan, equals(0.6));
        expect(fixture.viewModel.pressedNote, equals(note.id));

        fixture.pointerUp(key: 60.9, offset: 145.2);

        fixture.expectNoActiveTransientState();
        expect(fixture.notes, hasLength(1));

        fixture.project.undo();
        expect(fixture.notes, isEmpty);
      },
    );

    test('negative-time empty-space press does not create a note', () {
      fixture.pointerDown(key: 60.9, offset: -1);

      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.pressedNote, isNull);
    });

    test(
      'created notes can be repositioned during the same gesture and commit on cancel',
      () {
        fixture.viewModel.cursorNoteLength = 48;

        fixture.pointerDown(key: 60.9, offset: 145.2, alt: true);

        expect(fixture.notes, isEmpty);
        final createdNoteId = fixture.transientNotes.single.id;

        fixture.pointerMove(key: 63.5, offset: 173.8, alt: true);
        expect(fixture.notes, isEmpty);
        expect(fixture.transientNoteById(createdNoteId).key, equals(63));
        expect(fixture.transientNoteById(createdNoteId).offset, equals(173));
        fixture.pointerCancel(key: 63.5, offset: 173.8, alt: true);

        final note = fixture.noteById(createdNoteId);
        expect(note.key, equals(63));
        expect(note.offset, equals(173));

        fixture.project.undo();
        expect(fixture.notes, isEmpty);
      },
    );
  });
}
