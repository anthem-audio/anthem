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

import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/model/shared/time_signature.dart';

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

    test('shortcut copy stores selected notes in the clipboard', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      final noteC = fixture.addNote(key: 67, offset: 288, length: 96);
      fixture.selectNotes([noteA.id, noteC.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );

      final content = ServiceRegistry.clipboard.get<NotesClipboardContent>();

      expect(content, isNotNull);
      expect(content!.anchorOffset, equals(96));
      expect(content.serializedNotes, hasLength(2));
      expect(
        content.serializedNotes.map((noteJson) => noteJson['id']).toSet(),
        equals({noteA.id, noteC.id}),
      );
      expect(fixture.notes.map((note) => note.id), contains(noteB.id));
      fixture.expectSelection([noteA.id, noteC.id]);
    });

    test('shortcut cut copies and deletes selected notes', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      fixture.selectNotes([noteA.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX),
      );

      final content = ServiceRegistry.clipboard.get<NotesClipboardContent>();

      expect(content, isNotNull);
      expect(content!.serializedNotes.single['id'], equals(noteA.id));
      expect(fixture.notes.map((note) => note.id).toList(), [noteB.id]);
      fixture.expectSelection(const []);

      fixture.project.undo();
      expect(
        fixture.notes.map((note) => note.id).toSet(),
        equals({noteA.id, noteB.id}),
      );
    });

    test('shortcut paste uses the playback start for the active pattern', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 96);
      fixture.selectNotes([noteA.id, noteB.id]);
      fixture.project.sequence.activeTransportSequenceID = fixture.pattern.id;
      fixture.project.sequence.playbackStartPosition = 384;

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );
      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      );

      final pastedNotes =
          fixture.viewModel.selectedNotes
              .map(fixture.noteById)
              .toList(growable: false)
            ..sort((a, b) => a.offset.compareTo(b.offset));
      final pastedNoteIds = pastedNotes.map((note) => note.id).toSet();

      expect(pastedNotes, hasLength(2));
      expect(pastedNoteIds, isNot(contains(noteA.id)));
      expect(pastedNoteIds, isNot(contains(noteB.id)));
      expect(pastedNotes[0].key, equals(60));
      expect(pastedNotes[0].offset, equals(384));
      expect(pastedNotes[0].length, equals(48));
      expect(pastedNotes[1].key, equals(64));
      expect(pastedNotes[1].offset, equals(480));
      expect(pastedNotes[1].length, equals(96));

      fixture.project.undo();
      expect(
        fixture.notes.map((note) => note.id).toSet(),
        equals({noteA.id, noteB.id}),
      );
    });

    test(
      'shortcut paste uses the visible start snap for another transport',
      () {
        final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
        final noteB = fixture.addNote(key: 64, offset: 192, length: 96);
        fixture.selectNotes([noteA.id, noteB.id]);
        fixture.project.sequence.playbackStartPosition = 384;

        fixture.controller.onShortcut(
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
        );
        fixture.controller.onShortcut(
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
        );

        final pastedNotes =
            fixture.viewModel.selectedNotes
                .map(fixture.noteById)
                .toList(growable: false)
              ..sort((a, b) => a.offset.compareTo(b.offset));
        final pastedNoteIds = pastedNotes.map((note) => note.id).toSet();

        expect(pastedNotes, hasLength(2));
        expect(pastedNoteIds, isNot(contains(noteA.id)));
        expect(pastedNoteIds, isNot(contains(noteB.id)));
        expect(pastedNotes[0].key, equals(60));
        expect(pastedNotes[0].offset, equals(fixture.ceilingSnappedTime(0)));
        expect(pastedNotes[0].length, equals(48));
        expect(pastedNotes[1].key, equals(64));
        expect(
          pastedNotes[1].offset,
          equals(fixture.ceilingSnappedTime(0) + 96),
        );
        expect(pastedNotes[1].length, equals(96));
      },
    );

    test('shortcut paste falls back when the playback start is off screen', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);
      fixture.selectNotes([note.id]);
      fixture.project.sequence.activeTransportSequenceID = fixture.pattern.id;
      fixture.project.sequence.playbackStartPosition = 384;
      fixture.viewModel.timeRange = TimeRange(1000, 4072);
      fixture.syncRenderedViewMetrics();

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );
      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      );

      final pastedNote = fixture.viewModel.selectedNotes
          .map(fixture.noteById)
          .single;

      expect(pastedNote.id, isNot(note.id));
      expect(
        pastedNote.offset,
        equals(
          fixture.ceilingSnappedTime(fixture.viewModel.timeRange.start.ceil()),
        ),
      );
    });

    test('shortcut paste uses next snap after visible start', () {
      final note = fixture.addNote(key: 60, offset: 96, length: 48);
      fixture.selectNotes([note.id]);
      fixture.viewModel.timeRange = TimeRange(10, 3082);
      fixture.syncRenderedViewMetrics();

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      );
      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      );

      final pastedNote = fixture.viewModel.selectedNotes
          .map(fixture.noteById)
          .single;

      expect(pastedNote.id, isNot(note.id));
      expect(
        pastedNote.offset,
        equals(
          fixture.ceilingSnappedTime(fixture.viewModel.timeRange.start.ceil()),
        ),
      );
    });

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

    test('shortcut snap nudge moves selected notes in time and undoes', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      final noteC = fixture.addNote(key: 67, offset: 288, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      final snapSize = fixture.snapSizeAt(noteA.offset);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight),
      );

      expect(fixture.noteById(noteA.id).offset, equals(96 + snapSize));
      expect(fixture.noteById(noteB.id).offset, equals(192 + snapSize));
      expect(fixture.noteById(noteC.id).offset, equals(288));
      expect(fixture.noteById(noteA.id).key, equals(60));
      expect(fixture.noteById(noteB.id).key, equals(64));
      fixture.expectSelection([noteA.id, noteB.id]);

      fixture.project.undo();
      expect(fixture.noteById(noteA.id).offset, equals(96));
      expect(fixture.noteById(noteB.id).offset, equals(192));

      fixture.project.redo();
      expect(fixture.noteById(noteA.id).offset, equals(96 + snapSize));
      expect(fixture.noteById(noteB.id).offset, equals(192 + snapSize));
    });

    test('shortcut snap nudge clamps selected notes at pattern start', () {
      final noteA = fixture.addNote(key: 60, offset: 20, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 80, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft),
      );

      expect(fixture.noteById(noteA.id).offset, equals(0));
      expect(fixture.noteById(noteB.id).offset, equals(60));
    });

    test('shortcut bar nudge moves selected notes by one default bar', () {
      final noteA = fixture.addNote(key: 60, offset: 96, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 192, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      final barLength = getBarLength(
        fixture.project.sequence.ticksPerQuarter,
        fixture.project.sequence.defaultTimeSignature,
      );

      fixture.controller.onShortcut(
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.arrowRight,
        ),
      );

      expect(fixture.noteById(noteA.id).offset, equals(96 + barLength));
      expect(fixture.noteById(noteB.id).offset, equals(192 + barLength));

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft),
      );

      expect(fixture.noteById(noteA.id).offset, equals(96));
      expect(fixture.noteById(noteB.id).offset, equals(192));
    });

    test('shortcut bar nudge uses the active time signature', () {
      fixture.pattern.timeSignatureChanges.add(
        TimeSignatureChangeModel(
          idAllocator: testIdAllocator(),
          offset: 384,
          timeSignature: TimeSignatureModel(3, 4),
        ),
      );
      final noteA = fixture.addNote(key: 60, offset: 384, length: 48);
      final noteB = fixture.addNote(key: 64, offset: 480, length: 48);
      fixture.selectNotes([noteA.id, noteB.id]);

      fixture.controller.onShortcut(
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.arrowRight,
        ),
      );

      expect(fixture.noteById(noteA.id).offset, equals(672));
      expect(fixture.noteById(noteB.id).offset, equals(768));

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft),
      );

      expect(fixture.noteById(noteA.id).offset, equals(384));
      expect(fixture.noteById(noteB.id).offset, equals(480));
    });

    test(
      'shortcut bar nudge left uses the previous time signature at a change',
      () {
        fixture.pattern.timeSignatureChanges.add(
          TimeSignatureChangeModel(
            idAllocator: testIdAllocator(),
            offset: 384,
            timeSignature: TimeSignatureModel(3, 4),
          ),
        );
        final note = fixture.addNote(key: 60, offset: 384, length: 48);
        fixture.selectNotes([note.id]);

        fixture.controller.onShortcut(
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.arrowLeft,
          ),
        );

        expect(fixture.noteById(note.id).offset, equals(0));
      },
    );
  });
}
