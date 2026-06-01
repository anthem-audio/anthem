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

import 'package:flutter/services.dart';

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

    test('shortcut semitone transpose moves selected notes and undoes', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      final noteC = fixture.addNote(key: 67, offset: 288, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowUp),
      );

      expect(fixture.noteById(noteA.id).key, equals(61));
      expect(fixture.noteById(noteB.id).key, equals(65));
      expect(fixture.noteById(noteC.id).key, equals(67));
      expect(fixture.noteById(noteA.id).offset, equals(96));
      expect(fixture.noteById(noteB.id).offset, equals(192));
      fixture.expectSelection([noteA.id, noteB.id]);

      fixture.project.undo();
      expect(fixture.noteById(noteA.id).key, equals(60));
      expect(fixture.noteById(noteB.id).key, equals(64));

      fixture.project.redo();
      expect(fixture.noteById(noteA.id).key, equals(61));
      expect(fixture.noteById(noteB.id).key, equals(65));
    });

    test('shortcut semitone transpose clamps selected notes at key range', () {
      final noteA = fixture.addNote(key: 127, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 128, offset: 192, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowUp),
      );

      expect(fixture.noteById(noteA.id).key, equals(127));
      expect(fixture.noteById(noteB.id).key, equals(128));

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowDown),
      );

      expect(fixture.noteById(noteA.id).key, equals(126));
      expect(fixture.noteById(noteB.id).key, equals(127));
    });

    test('shortcut octave transpose requires a complete octave move', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp),
      );

      expect(fixture.noteById(noteA.id).key, equals(72));
      expect(fixture.noteById(noteB.id).key, equals(76));

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown),
      );

      expect(fixture.noteById(noteA.id).key, equals(60));
      expect(fixture.noteById(noteB.id).key, equals(64));
    });

    test('shortcut octave transpose does not clamp to a partial octave', () {
      final topNote = fixture.addNote(key: 120, offset: 96, length: 48);
      fixture.selectNotes([topNote.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp),
      );

      expect(fixture.noteById(topNote.id).key, equals(120));

      final bottomNote = fixture.addNote(key: 5, offset: 192, length: 48);
      fixture.selectNotes([bottomNote.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown),
      );

      expect(fixture.noteById(bottomNote.id).key, equals(5));
    });
  });
}
