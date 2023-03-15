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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';

class PianoRollController {
  final ProjectModel project;
  final PianoRollViewModel viewModel;

  PianoRollController({
    required this.project,
    required this.viewModel,
  });

  NoteModel? _getNote(ID? instrumentID, ID noteID) {
    final pattern = project.song.patterns[project.song.activePatternID];
    final noteList = pattern?.notes[instrumentID];
    NoteModel? note;
    try {
      note = noteList?.firstWhere((note) => note.id == noteID);
    } catch (ex) {
      note = null;
    }
    return note;
  }

  void addNote({
    required int key,
    required int velocity,
    required int length,
    required int offset,
  }) {
    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null) {
      return;
    }

    project.execute(AddNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      note: NoteModel(
        key: key,
        velocity: velocity,
        length: length,
        offset: offset,
      ),
    ));
  }

  void resizeNote({
    required ID noteID,
    required int length,
  }) {
    final note = _getNote(project.activeGeneratorID, noteID);

    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null ||
        note == null) {
      return;
    }

    return project.execute(ResizeNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      noteID: noteID,
      oldLength: note.length,
      newLength: length,
    ));
  }

  void removeNote({required ID noteID}) {
    final note = _getNote(project.activeGeneratorID, noteID);

    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null ||
        note == null) {
      return;
    }

    project.execute(DeleteNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      note: note,
    ));
  }

  void moveNote({
    required ID noteID,
    required int key,
    required int offset,
  }) {
    final note = _getNote(project.activeGeneratorID, noteID);

    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null ||
        note == null) {
      return;
    }

    return project.execute(MoveNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      noteID: noteID,
      oldKey: note.key,
      newKey: key,
      oldOffset: note.offset,
      newOffset: offset,
    ));
  }

  void addTimeSignatureChange({
    required TimeSignatureModel timeSignature,
    required Time offset,
    bool snap = true,
    required TimeRange
        timeView, // TODO: store this in the view model and get it form there
    required double pianoRollWidth,
  }) {
    if (project.song.activePatternID == null) return;

    var snappedOffset = offset;

    if (snap) {
      final pattern = project.song.patterns[project.song.activePatternID]!;

      final divisionChanges = getDivisionChanges(
        viewWidthInPixels: pianoRollWidth,
        // TODO: this constant was copied from the minor division changes
        // getter in piano_roll_grid.dart
        minPixelsPerSection: 8,
        snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
        defaultTimeSignature: project.song.defaultTimeSignature,
        timeSignatureChanges: pattern.timeSignatureChanges,
        ticksPerQuarter: project.song.ticksPerQuarter,
        timeViewStart: timeView.start,
        timeViewEnd: timeView.end,
      );

      snappedOffset = getSnappedTime(
        rawTime: offset.floor(),
        divisionChanges: divisionChanges,
        roundUp: true,
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

  void pointerDown(PianoRollPointerDownEvent event) {
    if (project.song.activePatternID == null) return;

    final eventTime = event.time.floor();
    if (eventTime < 0) return;

    final pattern = project.song.patterns[project.song.activePatternID]!;

    final divisionChanges = getDivisionChanges(
      viewWidthInPixels: event.pianoRollSize.width,
      // TODO: this constant was copied from the minor division changes
      // getter in piano_roll_grid.dart
      minPixelsPerSection: 8,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      defaultTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: pattern.timeSignatureChanges,
      ticksPerQuarter: project.song.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );

    int targetTime = getSnappedTime(
      rawTime: eventTime,
      divisionChanges: divisionChanges,
    );

    // projectCubit.journalStartEntry();
    addNote(
      key: event.note.floor(),
      velocity: 128,
      length: 96,
      offset: targetTime,
    );
  }

  void pointerMove(PianoRollPointerMoveEvent event) {}

  void pointerUp(PianoRollPointerUpEvent event) {}

  // OLD COMMENTARY:
  // Used to affect the notes in the view model without changing the main
  // model. This is used for in-progress operations. For example, if the user
  // selects a group of notes, presses mouse down, and moves the notes around,
  // mutateLocalNotes() is called. On mouse up, moveNote is called above. This
  // is useful because moveNote pushes a command to the undo/redo queue,
  // whereas this does not.
  //
  // It might be possible to handle this at the app model level. This would
  // have the advantage of allowing in-progress updates to affect other things
  // like clip renderers and property panels, but I haven't thought of a way to
  // generalize a fix for the undo/redo issue. We can use journal pages, but we
  // also don't want pages to contain every in-progress action the user
  // performed (i.e. if the user moves the notes around a lot before releasing
  // the mouse, we still want a journal page that just moves the notes from the
  // start position to the end position). It's possible to fix this on a case-
  // by-case basis but I think that would result in messier code.
  //
  // Until we can come up with a solution to the above, I think it's best to
  // keep this solution of mutating the local view model until we're ready to
  // commit.
  //
  // UPDATE:
  // It's 1:30AM and I'm not 100%, but here goes.
  //
  // This won't work anymore since we removed cubits and added MobX. I still
  // don't know what solution I want. The first that comes to mind is to have
  // the command store all notes before and after the edit. This almost
  // certainly won't be a huge amount. Seems fine, probably?

  // void mutateLocalNotes(
  //     {required int? instrumentID,
  //     required Function(List<LocalNote> notes) mutator}) {
  //   if (state.patternID == null || instrumentID == null) {
  //     return;
  //   }

  //   final pattern = project.song.patterns[state.patternID]!;

  //   final newNotes = [...state.notes];

  //   mutator(newNotes);

  //   emit(state.copyWith(
  //     notes: newNotes,
  //     lastContent: pattern.getWidth(
  //       barMultiple: 4,
  //       minPaddingInBarMultiples: 4,
  //     ),
  //   ));
  // }
}
