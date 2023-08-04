/*
  Copyright (C) 2023 Joshua Wade

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

import 'dart:ui';

import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/commands/pattern_note_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';

import '../shared/helpers/types.dart';

// Pixel range where mouse events will affect attributes
const attributeEditableSize = 80;

class AttributeEditorPointerEvent {
  final double offset;
  final double normalizedY;
  final Size viewSize;

  const AttributeEditorPointerEvent({
    required this.offset,
    required this.normalizedY,
    required this.viewSize,
  });
}

class AttributeEditorController {
  PianoRollViewModel viewModel;
  final oldValues = <ID, int>{};
  final newValues = <ID, int>{};

  AttributeEditorController({required this.viewModel});

  void pointerDown(AttributeEditorPointerEvent event) {
    pointerMove(event);
  }

  void pointerMove(AttributeEditorPointerEvent event) {
    // This would all be faster if the note list was sorted, because we could
    // binary search. I don't want to assume that it's worth it though since it
    // requires overhead elsewhere, but I'm leaving this note in case someone
    // decides it's worth looking into later.

    final store = AnthemStore.instance;
    final project = store.projects[store.activeProjectID]!;
    final pattern = project.song.patterns[project.song.activePatternID];

    if (pattern == null) return;

    final notes = pattern.notes[project.activeInstrumentID];

    if (notes == null || notes.isEmpty) return;

    final hasSelectedNotes = viewModel.selectedNotes.isNotEmpty;

    Time closestOffsetBefore = notes.first.offset;
    Time closestOffsetAfter = notes.first.offset;

    for (final note in notes) {
      if (hasSelectedNotes && !viewModel.selectedNotes.contains(note.id)) {
        continue;
      }

      if (note.offset < event.offset) {
        if ((note.offset - event.offset).abs() <
            (closestOffsetBefore - event.offset).abs()) {
          closestOffsetBefore = note.offset;
        }
      } else {
        if ((note.offset - event.offset).abs() <
            (closestOffsetAfter - event.offset).abs()) {
          closestOffsetAfter = note.offset;
        }
      }
    }

    final closestOffsetBeforePixels = timeToPixels(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: event.viewSize.width,
      time: closestOffsetBefore.toDouble(),
    );

    final closestOffsetAfterPixels = timeToPixels(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: event.viewSize.width,
      time: closestOffsetAfter.toDouble(),
    );

    final pointerTimePixels = timeToPixels(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: event.viewSize.width,
      time: event.offset,
    );

    var targetOffset = closestOffsetBefore;

    if ((closestOffsetBeforePixels - pointerTimePixels).abs() >
        attributeEditableSize / 2) {
      if ((closestOffsetAfterPixels - pointerTimePixels).abs() >
          attributeEditableSize / 2) {
        return;
      }

      targetOffset = closestOffsetAfter;
    }

    final affectedNotes = (hasSelectedNotes
            ? notes.where((note) => viewModel.selectedNotes.contains(note.id))
            : notes)
        .where((note) => note.offset == targetOffset);

    late final int bottom;
    late final int top;

    switch (viewModel.activeNoteAttribute) {
      case ActiveNoteAttribute.velocity:
        bottom = ActiveNoteAttribute.velocity.bottom;
        top = ActiveNoteAttribute.velocity.top;
        break;
      case ActiveNoteAttribute.pan:
        bottom = ActiveNoteAttribute.pan.bottom;
        top = ActiveNoteAttribute.pan.top;
        break;
    }

    final newValue = ((top - bottom) * event.normalizedY + bottom).round();

    for (final note in affectedNotes) {
      switch (viewModel.activeNoteAttribute) {
        case ActiveNoteAttribute.velocity:
          oldValues[note.id] ??= note.velocity;
          newValues[note.id] = newValue;
          viewModel.cursorNoteVelocity = newValue;
          note.velocity = newValue;
          break;
        case ActiveNoteAttribute.pan:
          oldValues[note.id] ??= note.pan;
          newValues[note.id] = newValue;
          viewModel.cursorNotePan = newValue;
          note.pan = newValue;
          break;
      }
    }
  }

  void pointerUp(AttributeEditorPointerEvent event) {
    if (oldValues.isEmpty && newValues.isEmpty) return;

    final store = AnthemStore.instance;
    final project = store.projects[store.activeProjectID]!;
    final pattern = project.song.patterns[project.song.activePatternID];

    if (pattern == null) return;
    if (project.activeInstrumentID == null) return;

    late NoteAttribute attribute;

    switch (viewModel.activeNoteAttribute) {
      case ActiveNoteAttribute.velocity:
        attribute = NoteAttribute.velocity;
        break;
      case ActiveNoteAttribute.pan:
        attribute = NoteAttribute.pan;
        break;
    }

    final commands = oldValues.keys
        .map((noteID) => SetNoteAttributeCommand(
              project: project,
              patternID: pattern.id,
              generatorID: project.activeInstrumentID!,
              noteID: noteID,
              attribute: attribute,
              oldValue: oldValues[noteID]!,
              newValue: newValues[noteID]!,
            ))
        .toList();

    final journalPageCommand = JournalPageCommand(project, commands);

    project.push(journalPageCommand);

    oldValues.clear();
    newValues.clear();
  }
}
