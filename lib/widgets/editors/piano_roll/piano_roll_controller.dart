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
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_events.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll_view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:mobx/mobx.dart';

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

  // Data for note moves
  NoteModel? _noteMoveNoteUnderCursor;
  double?
      _noteMoveTimeOffset; // difference between the start of the pressed note and the cursor X, in time
  double?
      _noteMoveNoteOffset; // difference between the start of the pressed note and the cursor Y, in notes
  Map<ID, Time>? _noteMoveStartTimes;
  Map<ID, int>? _noteMoveStartKeys;
  Time?
      _noteMoveStartOfFirstNote; // Start offset of the earliest note. Used to ensure none of the notes are moved to before the start of the pattern.
  int? _noteMoveKeyOfTopNote;
  int? _noteMoveKeyOfBottomNote;

  // Data for deleting state
  /// We ignore notes under the cursor, except the topmost one, until the user
  /// moves the mouse off the note and back on. This means that the user
  /// doesn't right click to delete an overlapping note, accidentally move the
  /// mouse by one pixel, and delete additional notes.
  Set<NoteModel>? _deleteNotesToTemporarilyIgnore;
  Set<NoteModel>? _deleteNotesDeleted;
  Point? _deleteMostRecentPoint;

  // Data for selection box
  Point<double>? _selectionBoxStart;
  Set<ID>? _selectionBoxOriginalSelection;

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

    if (event.keyboardModifiers.ctrl) {
      if (event.keyboardModifiers.shift &&
          event.noteUnderCursor != null &&
          viewModel.selectedNotes.contains(event.noteUnderCursor)) {
        _eventHandlingState =
            EventHandlingState.creatingSubtractiveSelectionBox;
      } else {
        _eventHandlingState = EventHandlingState.creatingAdditiveSelectionBox;
      }

      if (!event.keyboardModifiers.shift) {
        viewModel.selectedNotes.clear();
      }

      _selectionBoxStart = Point(event.offset, event.key);
      _selectionBoxOriginalSelection =
          viewModel.selectedNotes.nonObservableInner;

      return;
    }

    final notes = pattern.notes[project.activeGeneratorID] ?? <NoteModel>[];

    void setMoveNoteInfo(NoteModel noteUnderCursor) {
      _noteMoveNoteUnderCursor = noteUnderCursor;
      _noteMoveTimeOffset = event.offset - noteUnderCursor.offset;
      _noteMoveNoteOffset = 0.5;
      _noteMoveStartTimes = {noteUnderCursor.id: noteUnderCursor.offset};
      _noteMoveStartKeys = {noteUnderCursor.id: noteUnderCursor.key};

      // If we're moving a selection, record the start times
      for (final note
          in notes.where((note) => viewModel.selectedNotes.contains(note.id))) {
        _noteMoveStartTimes![note.id] = note.offset;
        _noteMoveStartKeys![note.id] = note.key;
      }

      if (_eventHandlingState == EventHandlingState.movingSelection) {
        _noteMoveStartOfFirstNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.contains(element.id)
                  ? min(previousValue, element.offset)
                  : previousValue,
        );
        _noteMoveKeyOfTopNote = notes.fold<int>(
          0,
          (previousValue, element) =>
              viewModel.selectedNotes.contains(element.id)
                  ? max(previousValue, element.key)
                  : previousValue,
        );
        _noteMoveKeyOfBottomNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.contains(element.id)
                  ? min(previousValue, element.key)
                  : previousValue,
        );
      } else {
        _noteMoveStartOfFirstNote = noteUnderCursor.offset;
        _noteMoveKeyOfTopNote = noteUnderCursor.key;
        _noteMoveKeyOfBottomNote = noteUnderCursor.key;
      }
    }

    if (event.noteUnderCursor != null) {
      if (viewModel.selectedNotes.contains(event.noteUnderCursor)) {
        _eventHandlingState = EventHandlingState.movingSelection;
      } else {
        _eventHandlingState = EventHandlingState.movingSingleNote;
        viewModel.selectedNotes.clear();
      }

      final note =
          notes.firstWhere((element) => element.id == event.noteUnderCursor);

      viewModel.pressedNote = note.id;

      setMoveNoteInfo(note);

      return;
    }

    _eventHandlingState = EventHandlingState.movingSingleNote;
    viewModel.selectedNotes.clear();

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

    setMoveNoteInfo(note);

    viewModel.pressedNote = note.id;
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
    switch (_eventHandlingState) {
      case EventHandlingState.idle:
        break;
      case EventHandlingState.movingSingleNote:
      case EventHandlingState.movingSelection:
        final isSelectionMove =
            _eventHandlingState == EventHandlingState.movingSelection;

        final key = event.key - _noteMoveNoteOffset!;
        final offset = event.offset - _noteMoveTimeOffset!;

        final pattern = project.song.patterns[project.song.activePatternID]!;

        final notes = isSelectionMove
            ? pattern.notes[project.activeGeneratorID]!
                .where((note) => viewModel.selectedNotes.contains(note.id))
                .toList()
            : [_noteMoveNoteUnderCursor!];

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

        final snappedOffset = getSnappedTime(
          rawTime: offset.floor(),
          divisionChanges: divisionChanges,
          roundUp: true,
        );

        var timeOffsetFromStart =
            snappedOffset - _noteMoveStartTimes![_noteMoveNoteUnderCursor!.id]!;
        var keyOffsetFromStart =
            key.round() - _noteMoveStartKeys![_noteMoveNoteUnderCursor!.id]!;

        // Prevent the leftmost key from going earlier than the start of the pattern
        if (_noteMoveStartOfFirstNote! + timeOffsetFromStart < 0) {
          timeOffsetFromStart = -_noteMoveStartOfFirstNote!;
        }

        // Prevent the top key from going above the highest allowed note
        if (_noteMoveKeyOfTopNote! + keyOffsetFromStart > maxKeyValue) {
          keyOffsetFromStart = maxKeyValue.round() - _noteMoveKeyOfTopNote!;
        }

        // Prevent the bottom key from going below the lowest allowed note
        if (_noteMoveKeyOfBottomNote! + keyOffsetFromStart < minKeyValue) {
          keyOffsetFromStart = minKeyValue.round() - _noteMoveKeyOfBottomNote!;
        }

        for (final note in notes) {
          final shift = event.keyboardModifiers.shift;
          final ctrl = event.keyboardModifiers.ctrl;
          note.key =
              _noteMoveStartKeys![note.id]! + (shift ? 0 : keyOffsetFromStart);
          note.offset = _noteMoveStartTimes![note.id]! +
              (!shift && ctrl ? 0 : timeOffsetFromStart);
        }

        break;
      case EventHandlingState.creatingAdditiveSelectionBox:
      case EventHandlingState.creatingSubtractiveSelectionBox:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        final isSubtractive = _eventHandlingState ==
            EventHandlingState.creatingSubtractiveSelectionBox;

        viewModel.selectionBox = Rectangle.fromPoints(
          _selectionBoxStart!,
          Point(event.offset, event.key),
        );

        final notesInSelection = notes
            .where(
              (note) => rectanglesIntersect(
                viewModel.selectionBox!,
                Rectangle(note.offset, note.key, note.length, 1),
              ),
            )
            .map((note) => note.id)
            .toSet();

        if (isSubtractive) {
          viewModel.selectedNotes = ObservableSet.of(
            _selectionBoxOriginalSelection!.difference(notesInSelection),
          );
        } else {
          viewModel.selectedNotes = ObservableSet.of(
            _selectionBoxOriginalSelection!.union(notesInSelection),
          );
        }

        break;
      case EventHandlingState.deleting:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        final thisPoint = Point(event.offset, event.key);

        // We make a line between the previous event point and this point, and
        // we delete all notes that intersect that line
        final notesUnderCursorPath = notes
            .where(
              (note) =>
                  // Discard if bounding boxes don't intersect
                  rectanglesIntersect(
                    Rectangle.fromPoints(
                      Point(
                        _deleteMostRecentPoint!.x,
                        _deleteMostRecentPoint!.y,
                      ),
                      Point(
                        thisPoint.x,
                        thisPoint.y,
                      ),
                    ),
                    Rectangle.fromPoints(
                      Point(note.offset, note.key),
                      Point(note.offset + note.length, note.key + 1),
                    ),
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

        break;
    }
  }

  void pointerUp(PianoRollPointerUpEvent event) {
    if (_eventHandlingState == EventHandlingState.movingSingleNote ||
        _eventHandlingState == EventHandlingState.movingSelection) {
      final pattern = project.song.patterns[project.song.activePatternID]!;
      final notes = pattern.notes[project.activeGeneratorID]!;

      final isSingleNote =
          _eventHandlingState == EventHandlingState.movingSingleNote;

      final relevantNotes = isSingleNote
          ? [_noteMoveNoteUnderCursor!]
          : notes
              .where((note) => viewModel.selectedNotes.contains(note.id))
              .toList();

      final commands = relevantNotes.map((note) {
        // We already moved this note to its target position. Now, we create a
        // command to move it from its original position to the target position,
        // which will be used for undo/redo.
        return MoveNoteCommand(
          project: project,
          patternID: pattern.id,
          generatorID: project.activeGeneratorID!,
          noteID: note.id,
          oldKey: _noteMoveStartKeys![note.id]!,
          newKey: note.key,
          oldOffset: _noteMoveStartTimes![note.id]!,
          newOffset: note.offset,
        );
      });

      final command = JournalPageCommand(project, commands.toList());

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
    } else if (_eventHandlingState ==
            EventHandlingState.creatingAdditiveSelectionBox ||
        _eventHandlingState ==
            EventHandlingState.creatingSubtractiveSelectionBox) {
      viewModel.selectionBox = null;
    }

    project.commitJournalPage();

    viewModel.pressedNote = null;

    _noteMoveNoteUnderCursor = null;
    _noteMoveNoteOffset = null;
    _noteMoveTimeOffset = null;
    _noteMoveStartTimes = null;
    _noteMoveStartKeys = null;

    _deleteNotesToTemporarilyIgnore = null;
    _deleteNotesDeleted = null;
    _deleteMostRecentPoint = null;

    _selectionBoxStart = null;
    _selectionBoxOriginalSelection = null;

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
}
