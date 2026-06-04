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

  group('hover state', () {
    test('sets the hovered note from hover hit tests', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);

      fixture.hover(key: 60.5, offset: 110, noteUnderCursor: note.id);

      expect(fixture.viewModel.hoveredNote, equals(note.id));
    });

    test('clears the hovered note when hovering empty space', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);

      fixture.hover(key: 60.5, offset: 110, noteUnderCursor: note.id);
      fixture.hover(key: 62.5, offset: 220);

      expect(fixture.viewModel.hoveredNote, isNull);
    });

    test('clears the hovered note on exit', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);

      fixture.hover(key: 60.5, offset: 110, noteUnderCursor: note.id);
      fixture.exit();

      expect(fixture.viewModel.hoveredNote, isNull);
    });
  });
}
