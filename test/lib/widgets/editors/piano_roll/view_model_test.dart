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

import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PianoRollViewModel createViewModel() {
    return PianoRollViewModel(
      keyHeight: 14,
      keyValueAtTop: 63.95,
      timeView: TimeRange(0, 3072),
    );
  }

  group('PianoRollViewModel note resolution', () {
    test('applies note overrides to real notes', () {
      final viewModel = createViewModel();
      final note = NoteModel(
        key: 60,
        velocity: 0.75,
        length: 96,
        offset: 120,
        pan: 0.1,
      );

      viewModel.selectedNotes.add(note.id);
      viewModel.pressedNote = note.id;
      viewModel.hoveredNote = note.id;
      viewModel.noteOverrides[note.id] = const PianoRollNoteOverride(
        key: 62,
        velocity: 0.5,
        length: 144,
        offset: 160,
        pan: -0.25,
      );

      final resolved = viewModel.resolveRenderedRealNote(note);

      expect(resolved.ref, equals(PianoRollRenderedNoteRef.real(note.id)));
      expect(resolved.key, equals(62));
      expect(resolved.velocity, equals(0.5));
      expect(resolved.length, equals(144));
      expect(resolved.offset, equals(160));
      expect(resolved.pan, equals(-0.25));
      expect(resolved.isSelected, isTrue);
      expect(resolved.isPressed, isTrue);
      expect(resolved.isHovered, isTrue);
      expect(resolved.hasOverride, isTrue);
    });

    test(
      'resolves real notes first, then overridden notes, then transient notes',
      () {
        final viewModel = createViewModel();
        final plainNote = NoteModel(
          key: 60,
          velocity: 0.75,
          length: 96,
          offset: 120,
          pan: 0,
        );
        final overriddenNote = NoteModel(
          key: 64,
          velocity: 0.75,
          length: 96,
          offset: 240,
          pan: 0,
        );
        const transientNoteId = 'transient-note';

        viewModel.noteOverrides[overriddenNote.id] =
            const PianoRollNoteOverride(offset: 300);
        viewModel.transientNotes[transientNoteId] =
            const PianoRollTransientNote(
              id: transientNoteId,
              key: 67,
              velocity: 0.5,
              length: 72,
              offset: 360,
              pan: -0.1,
            );
        viewModel.selectedTransientNotes.add(transientNoteId);

        final resolvedNotes = viewModel.resolveRenderedNotes([
          plainNote,
          overriddenNote,
        ]);

        expect(
          resolvedNotes.map((note) => note.ref).toList(growable: false),
          equals([
            PianoRollRenderedNoteRef.real(plainNote.id),
            PianoRollRenderedNoteRef.real(overriddenNote.id),
            const PianoRollRenderedNoteRef.transient(transientNoteId),
          ]),
        );
        expect(resolvedNotes[0].hasOverride, isFalse);
        expect(resolvedNotes[1].hasOverride, isTrue);
        expect(resolvedNotes[2].ref.realNoteId, isNull);
        expect(resolvedNotes[2].isSelected, isTrue);
      },
    );

    test('resolveRenderedNoteByRef returns real and transient notes', () {
      final viewModel = createViewModel();
      final realNote = NoteModel(
        key: 60,
        velocity: 0.75,
        length: 96,
        offset: 120,
        pan: 0,
      );
      const transientNoteId = 'transient-note';

      viewModel.transientNotes[transientNoteId] = const PianoRollTransientNote(
        id: transientNoteId,
        key: 67,
        velocity: 0.5,
        length: 72,
        offset: 360,
        pan: -0.1,
      );

      final resolvedReal = viewModel.resolveRenderedNoteByRef(
        realNotes: [realNote],
        ref: PianoRollRenderedNoteRef.real(realNote.id),
      );
      final resolvedTransient = viewModel.resolveRenderedNoteByRef(
        realNotes: [realNote],
        ref: const PianoRollRenderedNoteRef.transient(transientNoteId),
      );

      expect(resolvedReal, isNotNull);
      expect(resolvedReal!.ref.realNoteId, equals(realNote.id));
      expect(resolvedTransient, isNotNull);
      expect(resolvedTransient!.ref.realNoteId, isNull);
      expect(resolvedTransient.key, equals(67));
    });

    test(
      'resolvePressedRenderedNote prefers transient notes before real notes',
      () {
        final viewModel = createViewModel();
        final realNote = NoteModel(
          key: 60,
          velocity: 0.75,
          length: 96,
          offset: 120,
          pan: 0,
        );
        const transientNoteId = 'transient-note';

        viewModel.pressedNote = realNote.id;
        viewModel.transientNotes[transientNoteId] =
            const PianoRollTransientNote(
              id: transientNoteId,
              key: 72,
              velocity: 0.5,
              length: 72,
              offset: 360,
              pan: -0.1,
            );
        viewModel.pressedTransientNote = transientNoteId;

        final pressedNote = viewModel.resolvePressedRenderedNote([realNote]);

        expect(pressedNote, isNotNull);
        expect(
          pressedNote!.ref,
          const PianoRollRenderedNoteRef.transient(transientNoteId),
        );
        expect(pressedNote.key, equals(72));
      },
    );

    test('clearTransientPreviewState clears transient notes and overrides', () {
      final viewModel = createViewModel();
      final realNote = NoteModel(
        key: 60,
        velocity: 0.75,
        length: 96,
        offset: 120,
        pan: 0,
      );
      const transientNoteId = 'transient-note';

      viewModel.noteOverrides[realNote.id] = const PianoRollNoteOverride(
        offset: 180,
      );
      viewModel.transientNotes[transientNoteId] = const PianoRollTransientNote(
        id: transientNoteId,
        key: 67,
        velocity: 0.5,
        length: 72,
        offset: 360,
        pan: -0.1,
      );
      viewModel.selectedTransientNotes.add(transientNoteId);
      viewModel.pressedTransientNote = transientNoteId;
      viewModel.hoveredTransientNote = transientNoteId;

      viewModel.clearTransientPreviewState();

      expect(viewModel.noteOverrides, isEmpty);
      expect(viewModel.transientNotes, isEmpty);
      expect(viewModel.selectedTransientNotes, isEmpty);
      expect(viewModel.pressedTransientNote, isNull);
      expect(viewModel.hoveredTransientNote, isNull);
    });
  });
}
