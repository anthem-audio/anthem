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

  group('controller commands', () {
    test(
      'deleteSelected removes selected notes, clears selection, and undoes',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
        final noteC = fixture.addNote(key: 67, offset: 288, length: 48);
        fixture.selectNotes([noteA.id, noteC.id]);

        fixture.deleteSelected();

        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );
        fixture.expectSelection(const []);

        fixture.project.undo();
        expect(
          fixture.notes.map((note) => note.id).toSet(),
          equals({noteA.id, noteB.id, noteC.id}),
        );

        fixture.project.redo();
        expect(
          fixture.notes.map((note) => note.id).toList(),
          orderedEquals([noteB.id]),
        );
        fixture.expectSelection(const []);
      },
    );
  });
}
