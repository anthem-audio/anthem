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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// These are the possible states that the piano roll can have during event
/// handing. The current state tells the controller how to handle incoming
/// pointer events.
enum EventHandlingState {
  /// Nothing is happening right now.
  idle,

  /// A single note is being moved.
  movingSingleNote,

  /// A selection of notes are being moved.
  movingSelection,

  /// An additive selection box is being drawn. Notes under this box will be
  /// added to the current selection.
  creatingAdditiveSelectionBox,

  /// A subtractive selection box is being drawn. Notes under this box will be
  /// removed from the current selection if they are selected.
  creatingSubtractiveSelectionBox,

  /// Notes under the cursor are being deleted.
  deleting,
}

class PianoRollController {
  final ProjectModel project;
  final PianoRollViewModel viewModel;

  // Fields for event handling
  // Would be nice to replace some of these groups with records when records
  // are stabilized in Dart 3

  EventHandlingState _eventHandlingState = EventHandlingState.idle;

  // Data for single note move state
  NoteModel? _singleNoteMoveNote;
  double?
      _singleNoteMoveTimeOffset; // difference between the start of the note and the cursor X, in time
  double?
      _singleNoteMoveNoteOffset; // difference between the start of the note and the cursor Y, in notes
  Time? _singleNoteMoveStartTime;
  int? _singleNoteMoveStartKey;

  // Data for deleting state
  /// We ignore notes under the cursor, except the topmost one, until the user
  /// moves the mouse off the note and back on. This means that the user
  /// doesn't right click to delete an overlapping note, accidentally move the
  /// mouse by one pixel, and delete additional notes.
  Set<NoteModel>? _deleteNotesToTemporarilyIgnore;
  Set<NoteModel>? _deleteNotesDeleted;
  Point? _deleteMostRecentPoint;

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

  NoteModel addNote({
    required int key,
    required int velocity,
    required int length,
    required int offset,
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
    );

    project.execute(AddNoteCommand(
      project: project,
      patternID: project.song.activePatternID!,
      generatorID: project.activeGeneratorID!,
      note: note,
    ));

    return note;
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

  void leftPointerDown(PianoRollPointerDownEvent event) {
    final pattern = project.song.patterns[project.song.activePatternID]!;

    void setSingleMoveNoteInfo(NoteModel note) {
      _singleNoteMoveNote = note;
      _singleNoteMoveTimeOffset = event.offset - note.offset;
      _singleNoteMoveNoteOffset = 0.5;
      _singleNoteMoveStartTime = note.offset;
      _singleNoteMoveStartKey = note.key;
    }

    if (event.noteUnderCursor != null) {
      _eventHandlingState = EventHandlingState.movingSingleNote;

      final note = pattern.notes[project.activeGeneratorID]!
          .firstWhere((element) => element.id == event.noteUnderCursor);

      setSingleMoveNoteInfo(note);

      return;
    }

    _eventHandlingState = EventHandlingState.movingSingleNote;

    final eventTime = event.offset.floor();
    if (eventTime < 0) return;

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

    project.startJournalPage();

    final note = addNote(
      key: event.key.floor(),
      velocity: 128,
      length: 96,
      offset: targetTime,
    );

    setSingleMoveNoteInfo(note);
  }

  void rightPointerDown(PianoRollPointerDownEvent event) {
    _eventHandlingState = EventHandlingState.deleting;

    _deleteMostRecentPoint = Point(event.offset, event.key);

    project.startJournalPage();

    final pattern = project.song.patterns[project.song.activePatternID]!;
    final notes = pattern.notes[project.activeGeneratorID]!;

    _deleteNotesDeleted = {};
    _deleteNotesToTemporarilyIgnore = {};

    if (event.noteUnderCursor != null) {
      notes.removeWhere((note) {
        final remove = note.id == event.noteUnderCursor;
        if (remove) _deleteNotesDeleted!.add(note);
        return remove;
      });

      _deleteNotesToTemporarilyIgnore =
          _getNotesUnderCursor(notes, event.key, event.offset).toSet();
    }
  }

  void pointerDown(PianoRollPointerDownEvent event) {
    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null) return;

    if (event.pointerEvent.buttons & kPrimaryMouseButton ==
        kPrimaryMouseButton) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryButton ==
        kSecondaryMouseButton) {
      rightPointerDown(event);
    }
  }

  void pointerMove(PianoRollPointerMoveEvent event) {
    if (_eventHandlingState == EventHandlingState.movingSingleNote) {
      final key = event.key - _singleNoteMoveNoteOffset!;
      final offset = event.offset - _singleNoteMoveTimeOffset!;

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
        rawTime: offset.floor(),
        divisionChanges: divisionChanges,
      );

      _singleNoteMoveNote!.key =
          clampDouble(key, minKeyValue, maxKeyValue).round();
      _singleNoteMoveNote!.offset = max(targetTime, 0);
    } else if (_eventHandlingState == EventHandlingState.deleting) {
      final pattern = project.song.patterns[project.song.activePatternID]!;
      final notes = pattern.notes[project.activeGeneratorID]!;

      final thisPoint = Point(event.offset, event.key);

      final notesUnderCursorPath = notes
          .where(
            (note) =>
                // Discard if bounding boxes don't intersect
                boxesIntersect(
                  Point(
                    min(_deleteMostRecentPoint!.x, thisPoint.x),
                    min(_deleteMostRecentPoint!.y, thisPoint.y),
                  ),
                  Point(
                    max(_deleteMostRecentPoint!.x, thisPoint.x),
                    max(_deleteMostRecentPoint!.y, thisPoint.y),
                  ),
                  Point(note.offset, note.key),
                  Point(note.offset + note.length, note.key + 1),
                ) &&
                // Calculate if path segment intersects note
                lineIntersectsBox(
                  _deleteMostRecentPoint!,
                  thisPoint,
                  Point(note.offset, note.key),
                  Point(note.offset + note.length, note.key + 1),
                ),
          )
          .toList();

      final notesToRemove = <NoteModel>[];

      for (final note in _deleteNotesToTemporarilyIgnore!) {
        if (!notesUnderCursorPath.contains(note)) {
          notesToRemove.add(note);
        }
      }

      for (final note in notesToRemove) {
        _deleteNotesToTemporarilyIgnore!.remove(note);
      }

      for (final note in notesUnderCursorPath) {
        if (_deleteNotesToTemporarilyIgnore!.contains(note)) {
          continue;
        } else {
          notes.remove(note);
          _deleteNotesDeleted!.add(note);
        }
      }

      _deleteMostRecentPoint = thisPoint;
    }
  }

  void pointerUp(PianoRollPointerUpEvent event) {
    if (_eventHandlingState == EventHandlingState.movingSingleNote) {
      // We already moved this note to its target position. Now, we create a
      // command to move it from its original position to the target position,
      // which will be used for undo/redo.
      final command = MoveNoteCommand(
        project: project,
        patternID: project.song.activePatternID!,
        generatorID: project.activeGeneratorID!,
        noteID: _singleNoteMoveNote!.id,
        oldKey: _singleNoteMoveStartKey!,
        newKey: _singleNoteMoveNote!.key,
        oldOffset: _singleNoteMoveStartTime!,
        newOffset: _singleNoteMoveNote!.offset,
      );

      // Push the command, but don't execute it, since the note is already
      // moved
      project.push(command);
    } else if (_eventHandlingState == EventHandlingState.deleting) {
      for (final note in _deleteNotesDeleted!) {
        final command = DeleteNoteCommand(
          project: project,
          patternID: project.song.activePatternID!,
          generatorID: project.activeGeneratorID!,
          note: note,
        );

        project.push(command);
      }
    }

    project.commitJournalPage();

    _singleNoteMoveNote = null;
    _singleNoteMoveNoteOffset = null;
    _singleNoteMoveTimeOffset = null;

    _deleteNotesToTemporarilyIgnore = null;
    _deleteNotesDeleted = null;
    _deleteMostRecentPoint = null;

    _eventHandlingState = EventHandlingState.idle;
  }

  // Helper functions

  List<NoteModel> _getNotesUnderCursor(
      List<NoteModel> notes, double key, double offset) {
    final keyFloor = key.floor();

    return notes.where((note) {
      return offset >= note.offset &&
          offset < note.offset + note.length &&
          keyFloor == note.key;
    }).toList();
  }

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
