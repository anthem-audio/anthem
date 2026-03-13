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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProjectEntityIdAllocator testIdAllocator([Id Function()? allocateId]) {
    return ProjectEntityIdAllocator.test(allocateId ?? getId);
  }

  PianoRollViewModel createViewModel() {
    return PianoRollViewModel(
      keyHeight: 14,
      keyValueAtTop: 63.95,
      timeView: TimeRange(0, 3072),
    );
  }

  PatternModel createPattern(Iterable<NoteModel> notes) {
    final pattern = PatternModel(
      idAllocator: testIdAllocator(),
      name: 'Pattern',
    );
    for (final note in notes) {
      pattern.notes[note.id] = note;
    }
    return pattern;
  }

  NoteModel createPreviewNote({
    required String id,
    required int key,
    required double velocity,
    required int length,
    required int offset,
    required double pan,
  }) {
    return NoteModel(
      idAllocator: testIdAllocator(() => id),
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );
  }

  group('PianoRollViewModel note resolution', () {
    test('applies note overrides to real notes', () {
      final viewModel = createViewModel();
      final note = NoteModel(
        idAllocator: testIdAllocator(),
        key: 60,
        velocity: 0.75,
        length: 96,
        offset: 120,
        pan: 0.1,
      );
      final pattern = createPattern([note]);

      viewModel.selectedNotes.add(note.id);
      viewModel.pressedNote = note.id;
      viewModel.hoveredNote = note.id;
      pattern.setNoteOverride(
        noteId: note.id,
        key: 62,
        velocity: 0.5,
        length: 144,
        offset: 160,
        pan: -0.25,
      );

      final resolved = pattern.resolveNote(note);

      expect(
        viewModel.renderedRefFor(resolved),
        equals(PianoRollRenderedNoteRef.real(note.id)),
      );
      expect(resolved.key, equals(62));
      expect(resolved.velocity, equals(0.5));
      expect(resolved.length, equals(144));
      expect(resolved.offset, equals(160));
      expect(resolved.pan, equals(-0.25));
      expect(viewModel.isNoteSelected(resolved), isTrue);
      expect(viewModel.isNotePressed(resolved), isTrue);
      expect(viewModel.isNoteHovered(resolved), isTrue);
    });

    test(
      'resolves real notes first, then overridden notes, then transient notes',
      () {
        final viewModel = createViewModel();
        final plainNote = NoteModel(
          idAllocator: testIdAllocator(),
          key: 60,
          velocity: 0.75,
          length: 96,
          offset: 120,
          pan: 0,
        );
        final overriddenNote = NoteModel(
          idAllocator: testIdAllocator(),
          key: 64,
          velocity: 0.75,
          length: 96,
          offset: 240,
          pan: 0,
        );
        final pattern = createPattern([plainNote, overriddenNote]);
        const transientNoteId = 'transient-note';

        pattern.setNoteOverride(noteId: overriddenNote.id, offset: 300);
        pattern.addPreviewNote(
          createPreviewNote(
            id: transientNoteId,
            key: 67,
            velocity: 0.5,
            length: 72,
            offset: 360,
            pan: -0.1,
          ),
        );
        viewModel.selectedNotes.add(transientNoteId);

        final resolvedNotes = viewModel.resolveRenderedNotes(pattern);

        expect(
          resolvedNotes.map(viewModel.renderedRefFor).toList(growable: false),
          equals([
            PianoRollRenderedNoteRef.real(plainNote.id),
            PianoRollRenderedNoteRef.real(overriddenNote.id),
            const PianoRollRenderedNoteRef.transient(transientNoteId),
          ]),
        );
        expect(viewModel.renderedRefFor(resolvedNotes[2]).realNoteId, isNull);
        expect(viewModel.isNoteSelected(resolvedNotes[2]), isTrue);
      },
    );

    test('resolveRenderedNoteByRef returns real and transient notes', () {
      final viewModel = createViewModel();
      final realNote = NoteModel(
        idAllocator: testIdAllocator(),
        key: 60,
        velocity: 0.75,
        length: 96,
        offset: 120,
        pan: 0,
      );
      final pattern = createPattern([realNote]);
      const transientNoteId = 'transient-note';

      pattern.addPreviewNote(
        createPreviewNote(
          id: transientNoteId,
          key: 67,
          velocity: 0.5,
          length: 72,
          offset: 360,
          pan: -0.1,
        ),
      );

      final resolvedReal = viewModel.resolveRenderedNoteByRef(
        pattern: pattern,
        ref: PianoRollRenderedNoteRef.real(realNote.id),
      );
      final resolvedTransient = viewModel.resolveRenderedNoteByRef(
        pattern: pattern,
        ref: const PianoRollRenderedNoteRef.transient(transientNoteId),
      );

      expect(resolvedReal, isNotNull);
      expect(
        viewModel.renderedRefFor(resolvedReal!).realNoteId,
        equals(realNote.id),
      );
      expect(resolvedTransient, isNotNull);
      expect(viewModel.renderedRefFor(resolvedTransient!).realNoteId, isNull);
      expect(resolvedTransient.key, equals(67));
    });

    test(
      'resolvePressedRenderedNote resolves preview notes from the unified pressed ID',
      () {
        final viewModel = createViewModel();
        final pattern = createPattern(const []);
        const transientNoteId = 'transient-note';

        pattern.addPreviewNote(
          createPreviewNote(
            id: transientNoteId,
            key: 72,
            velocity: 0.5,
            length: 72,
            offset: 360,
            pan: -0.1,
          ),
        );
        viewModel.pressedNote = transientNoteId;

        final pressedNote = viewModel.resolvePressedRenderedNote(pattern);

        expect(pressedNote, isNotNull);
        expect(
          viewModel.renderedRefFor(pressedNote!),
          const PianoRollRenderedNoteRef.transient(transientNoteId),
        );
        expect(pressedNote.key, equals(72));
      },
    );

    test('clearTransientPreviewState clears transient interaction state', () {
      final viewModel = createViewModel();
      const transientNoteId = 'preview-note';
      const selectedNoteId = 'selected-note';

      viewModel.selectedNotes.add(selectedNoteId);
      viewModel.pressedNote = transientNoteId;
      viewModel.hoveredNote = transientNoteId;

      viewModel.clearTransientPreviewState();

      expect(viewModel.selectedNotes, contains(selectedNoteId));
      expect(viewModel.pressedNote, isNull);
      expect(viewModel.hoveredNote, isNull);
    });
  });
}
