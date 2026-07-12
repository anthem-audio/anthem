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

  group('selection box interactions', () {
    test('ctrl drag clears a previous selection when shift is not held', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      final noteC = fixture.addNote(key: 72, offset: 600, length: 48);
      fixture.selectNotes([noteC.id]);

      fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
      fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);
      fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test(
      'ctrl drag creates an additive selection box and keeps result on up',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
        fixture.addNote(key: 72, offset: 600, length: 48);

        fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
        fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);

        fixture.expectSelectionBox(left: 80, top: 59.5, width: 280, height: 6);
        fixture.expectSelection([noteA.id, noteB.id]);

        fixture.pointerUp(key: 65.5, offset: 360, ctrl: true);

        expect(fixture.viewModel.selectionBox, isNull);
        fixture.expectSelection([noteA.id, noteB.id]);
        fixture.expectNoActiveTransientState();
      },
    );

    test('shift drag in select tool creates a subtractive selection box', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      final noteC = fixture.addNote(key: 70, offset: 480, length: 48);
      fixture.selectNotes([noteA.id, noteB.id, noteC.id]);
      fixture.setTool(EditorTool.select);

      fixture.pointerDown(
        key: 64.5,
        offset: 300,
        shift: true,
        noteUnderCursor: noteB.id,
      );
      fixture.pointerMove(key: 59.5, offset: 80, shift: true);

      fixture.expectSelection([noteC.id]);

      fixture.pointerUp(key: 59.5, offset: 80, shift: true);

      expect(fixture.viewModel.selectionBox, isNull);
      fixture.expectSelection([noteC.id]);
    });

    test('select tool drag creates an additive selection box without ctrl', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 288, length: 48);
      fixture.setTool(EditorTool.select);

      fixture.pointerDown(key: 59.5, offset: 80);
      fixture.pointerMove(key: 65.5, offset: 360);
      fixture.pointerUp(key: 65.5, offset: 360);

      fixture.expectSelection([noteA.id, noteB.id]);
    });

    test(
      'pointer cancel clears selection box but preserves last selection result',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 288, length: 48);

        fixture.pointerDown(key: 59.5, offset: 80, ctrl: true);
        fixture.pointerMove(key: 65.5, offset: 360, ctrl: true);
        fixture.pointerCancel(key: 65.5, offset: 360, ctrl: true);

        expect(fixture.viewModel.selectionBox, isNull);
        fixture.expectSelection([noteA.id, noteB.id]);
        fixture.expectNoActiveTransientState();
      },
    );
  });
}
