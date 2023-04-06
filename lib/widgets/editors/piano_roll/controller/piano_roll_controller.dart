/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'dart:math';

import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'shortcuts.dart';
part 'pointer_events.dart';

class PianoRollController extends _PianoRollController
    with _PianoRollShortcutsMixin, _PianoRollPointerEventsMixin {
  @override
  PianoRollController({required project, required viewModel})
      : super(project: project, viewModel: viewModel);
}

class _PianoRollController {
  final ProjectModel project;
  final PianoRollViewModel viewModel;

  _PianoRollController({
    required this.project,
    required this.viewModel,
  });

  NoteModel _addNote({
    required int key,
    required int velocity,
    required int length,
    required int offset,
    required int pan,
  }) {
    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null) {
      throw Exception('Active pattern and/or active generator are not set');
    }

    final note = NoteModel(
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );

    project.execute(AddNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      note: note,
    ));

    return note;
  }

  /// Adds a time signature change to the pattern.
  void addTimeSignatureChange({
    required TimeSignatureModel timeSignature,
    required Time offset,
    bool snap = true,
    required double pianoRollWidth,
  }) {
    if (project.song.activePatternID == null) return;

    var snappedOffset = offset;

    if (snap) {
      final pattern = project.song.patterns[project.song.activePatternID]!;

      final divisionChanges = getDivisionChanges(
        viewWidthInPixels: pianoRollWidth,
        snap: AutoSnap(),
        defaultTimeSignature: project.song.defaultTimeSignature,
        timeSignatureChanges: pattern.timeSignatureChanges,
        ticksPerQuarter: project.song.ticksPerQuarter,
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
      );

      snappedOffset = getSnappedTime(
        rawTime: offset.floor(),
        divisionChanges: divisionChanges,
        ceil: true,
      );
    }

    project.execute(
      AddTimeSignatureChangeCommand(
        timelineKind: TimelineKind.pattern,
        project: project,
        patternID: project.song.activePatternID!,
        change: TimeSignatureChangeModel(
          offset: snappedOffset,
          timeSignature: timeSignature,
        ),
      ),
    );
  }

  /// Records the parameters of this note so the next placed note has the same
  /// parameters.
  void setCursorNoteParameters(NoteModel note) {
    viewModel.cursorNoteLength = note.length;
    viewModel.cursorNoteVelocity = note.velocity;
    viewModel.cursorNotePan = note.pan;
  }

  /// Deletes notes in the selectedNotes set from the view model.
  void deleteSelected() {
    if (viewModel.selectedNotes.isEmpty ||
        project.song.activePatternID == null ||
        project.activeGeneratorID == null) return;

    final commands = project.song.patterns[project.song.activePatternID]!
        .notes[project.activeGeneratorID]!
        .where((note) => viewModel.selectedNotes.contains(note.id))
        .map((note) {
      return DeleteNoteCommand(
        project: project,
        patternID: project.song.activePatternID!,
        generatorID: project.activeGeneratorID!,
        note: note,
      );
    }).toList();

    final command = JournalPageCommand(project, commands);

    project.execute(command);

    viewModel.selectedNotes.clear();
  }

  /// Adds all notes to the selection set in the view model.
  void selectAll() {
    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null) return;

    viewModel.selectedNotes = ObservableSet.of(
      project.song.patterns[project.song.activePatternID]!
          .notes[project.activeGeneratorID]!
          .map((note) => note.id)
          .toSet(),
    );
  }

  List<NoteModel> _getNotesUnderCursor(
      List<NoteModel> notes, double key, double offset) {
    final keyFloor = key.floor();

    return notes.where((note) {
      return offset >= note.offset &&
          offset < note.offset + note.length &&
          keyFloor == note.key;
    }).toList();
  }
}
