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

part of 'piano_roll_controller.dart';

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

  /// A single note is being resized.
  resizingSingleNote,

  /// A selection of notes are being resized.
  resizingSelection,

  /// An additive selection box is being drawn. Notes under this box will be
  /// added to the current selection.
  creatingAdditiveSelectionBox,

  /// A subtractive selection box is being drawn. Notes under this box will be
  /// removed from the current selection if they are selected.
  creatingSubtractiveSelectionBox,

  /// Notes under the cursor are being deleted.
  deleting,
}

class _DeleteActionData {
  /// We ignore notes under the cursor, except the topmost one, until the user
  /// moves the mouse off the note and back on. This means that the user
  /// doesn't right click to delete an overlapping note, accidentally move the
  /// mouse by one pixel, and delete additional notes.
  Set<NoteModel> notesToTemporarilyIgnore;
  Set<NoteModel> notesDeleted;
  Point mostRecentPoint;

  _DeleteActionData({
    required this.notesToTemporarilyIgnore,
    required this.notesDeleted,
    required this.mostRecentPoint,
  });
}

class _SelectionBoxActionData {
  Point<double> start;
  Set<ID> originalSelection;

  _SelectionBoxActionData({
    required this.start,
    required this.originalSelection,
  });
}

class _NoteResizeActionData {
  double pointerStartOffset;
  Map<ID, Time> startLengths;
  Time smallestStartLength;
  ID smallestNote;
  NoteModel pressedNote;

  _NoteResizeActionData({
    required this.pointerStartOffset,
    required this.startLengths,
    required this.smallestStartLength,
    required this.smallestNote,
    required this.pressedNote,
  });
}

class _NoteMoveActionData {
  NoteModel noteUnderCursor;
  double
      timeOffset; // difference between the start of the pressed note and the cursor X, in time
  double
      noteOffset; // difference between the start of the pressed note and the cursor Y, in notes
  Map<ID, Time> startTimes;
  Map<ID, int> startKeys;
  Time
      startOfFirstNote; // Start offset of the earliest note. Used to ensure none of the notes are moved to before the start of the pattern.
  int keyOfTopNote;
  int keyOfBottomNote;

  _NoteMoveActionData({
    required this.noteUnderCursor,
    required this.timeOffset,
    required this.noteOffset,
    required this.startTimes,
    required this.startKeys,
    required this.startOfFirstNote,
    required this.keyOfTopNote,
    required this.keyOfBottomNote,
  });
}

mixin _PianoRollPointerEventsMixin on _PianoRollController {
  // Fields for event handling

  var _eventHandlingState = EventHandlingState.idle;

  // Data for note moves
  _NoteMoveActionData? _noteMoveActionData;

  // Data for note resize
  _NoteResizeActionData? _noteResizeActionData;

  // Data for deleting notes
  _DeleteActionData? _deleteActionData;

  // Data for selection box
  _SelectionBoxActionData? _selectionBoxActionData;

  void leftPointerDown(PianoRollPointerDownEvent event) {
    final pattern = project.song.patterns[project.song.activePatternID]!;
    final notes =
        pattern.notes[project.activeGeneratorID]?.nonObservableInner ??
            <NoteModel>[];

    if (event.keyboardModifiers.ctrl || viewModel.tool == EditorTool.select) {
      if (event.keyboardModifiers.shift &&
          event.noteUnderCursor != null &&
          viewModel.selectedNotes.nonObservableInner
              .contains(event.noteUnderCursor)) {
        _eventHandlingState =
            EventHandlingState.creatingSubtractiveSelectionBox;
      } else {
        _eventHandlingState = EventHandlingState.creatingAdditiveSelectionBox;
      }

      if (!event.keyboardModifiers.shift) {
        viewModel.selectedNotes.clear();
      }

      _selectionBoxActionData = _SelectionBoxActionData(
        start: Point(event.offset, event.key),
        originalSelection: viewModel.selectedNotes.nonObservableInner,
      );

      return;
    }

    if (event.isResize && viewModel.tool == EditorTool.pencil) {
      if (event.noteUnderCursor == null) {
        throw ArgumentError("Resize event didn't provide a noteUnderCursor");
      }

      final pressedNote =
          notes.firstWhere((note) => note.id == event.noteUnderCursor);

      viewModel.pressedNote = event.noteUnderCursor;

      late int smallestStartLength;
      late String smallestNoteId;
      late Map<String, int> startLengths;

      if (viewModel.selectedNotes.nonObservableInner.contains(pressedNote.id)) {
        _eventHandlingState = EventHandlingState.resizingSelection;

        final relevantNotes = notes.where((note) =>
            viewModel.selectedNotes.nonObservableInner.contains(note.id));
        var smallestNote = relevantNotes.first;
        for (final note in relevantNotes) {
          if (note.length < smallestNote.length) smallestNote = note;
        }

        smallestStartLength = smallestNote.length;
        smallestNoteId = smallestNote.id;
        startLengths = Map.fromEntries(
            relevantNotes.map((note) => MapEntry(note.id, note.length)));
      } else {
        _eventHandlingState = EventHandlingState.resizingSingleNote;
        viewModel.selectedNotes.clear();

        startLengths = {pressedNote.id: pressedNote.length};
        smallestStartLength = pressedNote.length;
        smallestNoteId = pressedNote.id;

        setCursorNoteParameters(pressedNote);
      }

      _noteResizeActionData = _NoteResizeActionData(
        pointerStartOffset: event.offset,
        pressedNote: pressedNote,
        startLengths: startLengths,
        smallestStartLength: smallestStartLength,
        smallestNote: smallestNoteId,
      );

      return;
    }

    void setMoveNoteInfo(NoteModel noteUnderCursor) {
      _noteMoveActionData = _NoteMoveActionData(
        noteUnderCursor: noteUnderCursor,
        timeOffset: event.offset - noteUnderCursor.offset,
        noteOffset: 0.5,
        startTimes: {noteUnderCursor.id: noteUnderCursor.offset},
        startKeys: {noteUnderCursor.id: noteUnderCursor.key},
        startOfFirstNote: -1,
        keyOfTopNote: -1,
        keyOfBottomNote: -1,
      );

      // If we're moving a selection, record the start times
      for (final note in notes.where((note) =>
          viewModel.selectedNotes.nonObservableInner.contains(note.id))) {
        _noteMoveActionData!.startTimes[note.id] = note.offset;
        _noteMoveActionData!.startKeys[note.id] = note.key;
      }

      if (_eventHandlingState == EventHandlingState.movingSelection) {
        _noteMoveActionData!.startOfFirstNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? min(previousValue, element.offset)
                  : previousValue,
        );
        _noteMoveActionData!.keyOfTopNote = notes.fold<int>(
          0,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? max(previousValue, element.key)
                  : previousValue,
        );
        _noteMoveActionData!.keyOfBottomNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? min(previousValue, element.key)
                  : previousValue,
        );
      } else {
        _noteMoveActionData!.startOfFirstNote = noteUnderCursor.offset;
        _noteMoveActionData!.keyOfTopNote = noteUnderCursor.key;
        _noteMoveActionData!.keyOfBottomNote = noteUnderCursor.key;
      }
    }

    if (event.noteUnderCursor != null) {
      var pressedNote =
          notes.firstWhere((element) => element.id == event.noteUnderCursor);

      if (viewModel.selectedNotes.nonObservableInner
          .contains(event.noteUnderCursor)) {
        _eventHandlingState = EventHandlingState.movingSelection;

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

          final newSelectedNotes = ObservableSet<ID>();

          for (final note in notes
              .where((note) =>
                  viewModel.selectedNotes.nonObservableInner.contains(note.id))
              .toList()) {
            final newNote = NoteModel.fromNoteModel(note);

            project.execute(AddNoteCommand(
              project: project,
              patternID: project.song.activePatternID!,
              generatorID: project.activeGeneratorID!,
              note: newNote,
            ));

            newSelectedNotes.add(newNote.id);

            if (note.id == event.noteUnderCursor) {
              pressedNote = newNote;
            }
          }

          viewModel.selectedNotes = newSelectedNotes;
        }
      } else {
        _eventHandlingState = EventHandlingState.movingSingleNote;
        viewModel.selectedNotes.clear();

        if (event.keyboardModifiers.shift) {
          final newNote = NoteModel.fromNoteModel(pressedNote);

          project.execute(AddNoteCommand(
            project: project,
            patternID: project.song.activePatternID!,
            generatorID: project.activeGeneratorID!,
            note: newNote,
          ));
        }

        setCursorNoteParameters(pressedNote);
      }

      viewModel.pressedNote = pressedNote.id;

      setMoveNoteInfo(pressedNote);

      return;
    }

    _eventHandlingState = EventHandlingState.movingSingleNote;
    viewModel.selectedNotes.clear();

    final eventTime = event.offset.floor();
    if (eventTime < 0) return;

    final divisionChanges = getDivisionChanges(
      viewWidthInPixels: event.pianoRollSize.width,
      snap: AutoSnap(),
      defaultTimeSignature: project.song.defaultTimeSignature,
      timeSignatureChanges: pattern.timeSignatureChanges,
      ticksPerQuarter: project.song.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );

    final targetTime = event.keyboardModifiers.alt
        ? eventTime
        : getSnappedTime(
            rawTime: eventTime,
            divisionChanges: divisionChanges,
          );

    project.startJournalPage();

    final note = _addNote(
      key: event.key.floor(),
      velocity: viewModel.cursorNoteVelocity,
      length: viewModel.cursorNoteLength,
      offset: targetTime,
      pan: viewModel.cursorNotePan,
    );

    setMoveNoteInfo(note);

    viewModel.pressedNote = note.id;
  }

  void rightPointerDown(PianoRollPointerDownEvent event) {
    _eventHandlingState = EventHandlingState.deleting;

    project.startJournalPage();

    final pattern = project.song.patterns[project.song.activePatternID]!;
    final notes = pattern.notes[project.activeGeneratorID]!;

    _deleteActionData = _DeleteActionData(
      mostRecentPoint: Point(event.offset, event.key),
      notesDeleted: {},
      notesToTemporarilyIgnore: {},
    );

    if (event.noteUnderCursor != null) {
      notes.removeWhere((note) {
        final remove = note.id == event.noteUnderCursor &&
            // Ignore events that come from the resize handle but aren't over
            // the note.
            note.offset + note.length > event.offset;

        if (remove) {
          _deleteActionData!.notesDeleted.add(note);
          viewModel.selectedNotes.remove(note.id);
        }
        return remove;
      });

      _deleteActionData!.notesToTemporarilyIgnore =
          _getNotesUnderCursor(notes, event.key, event.offset).toSet();
    }
  }

  void pointerDown(PianoRollPointerDownEvent event) {
    if (project.song.activePatternID == null ||
        project.activeGeneratorID == null) return;

    if (event.pointerEvent.buttons & kPrimaryMouseButton ==
            kPrimaryMouseButton &&
        viewModel.tool != EditorTool.eraser) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryMouseButton ==
            kSecondaryMouseButton ||
        viewModel.tool == EditorTool.eraser) {
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

        final key = event.key - _noteMoveActionData!.noteOffset;
        final offset = event.offset - _noteMoveActionData!.timeOffset;

        final pattern = project.song.patterns[project.song.activePatternID]!;

        final notes = isSelectionMove
            ? pattern.notes[project.activeGeneratorID]!
                .where((note) => viewModel.selectedNotes.nonObservableInner
                    .contains(note.id))
                .toList()
            : [_noteMoveActionData!.noteUnderCursor];

        var snappedOffset = offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.pianoRollSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: pattern.timeSignatureChanges,
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOffset = getSnappedTime(
            rawTime: offset.floor(),
            divisionChanges: divisionChanges,
            round: true,
            startTime: _noteMoveActionData!
                .startTimes[_noteMoveActionData!.noteUnderCursor.id]!,
          );
        }

        var timeOffsetFromEventStart = snappedOffset -
            _noteMoveActionData!
                .startTimes[_noteMoveActionData!.noteUnderCursor.id]!;
        var keyOffsetFromEventStart = key.round() -
            _noteMoveActionData!
                .startKeys[_noteMoveActionData!.noteUnderCursor.id]!;

        // Prevent the leftmost key from going earlier than the start of the pattern
        if (_noteMoveActionData!.startOfFirstNote + timeOffsetFromEventStart <
            0) {
          timeOffsetFromEventStart = -_noteMoveActionData!.startOfFirstNote;
        }

        // Prevent the top key from going above the highest allowed note
        if (_noteMoveActionData!.keyOfTopNote + keyOffsetFromEventStart >
            maxKeyValue) {
          keyOffsetFromEventStart =
              maxKeyValue.round() - _noteMoveActionData!.keyOfTopNote;
        }

        // Prevent the bottom key from going below the lowest allowed note
        if (_noteMoveActionData!.keyOfBottomNote + keyOffsetFromEventStart <
            minKeyValue) {
          keyOffsetFromEventStart =
              minKeyValue.round() - _noteMoveActionData!.keyOfBottomNote;
        }

        for (final note in notes) {
          final shift = event.keyboardModifiers.shift;
          final ctrl = event.keyboardModifiers.ctrl;
          note.key = _noteMoveActionData!.startKeys[note.id]! +
              (shift ? 0 : keyOffsetFromEventStart);
          note.offset = _noteMoveActionData!.startTimes[note.id]! +
              (!shift && ctrl ? 0 : timeOffsetFromEventStart);
        }

        break;
      case EventHandlingState.creatingAdditiveSelectionBox:
      case EventHandlingState.creatingSubtractiveSelectionBox:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        final isSubtractive = _eventHandlingState ==
            EventHandlingState.creatingSubtractiveSelectionBox;

        viewModel.selectionBox = Rectangle.fromPoints(
          _selectionBoxActionData!.start,
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
            _selectionBoxActionData!.originalSelection
                .difference(notesInSelection),
          );
        } else {
          viewModel.selectedNotes = ObservableSet.of(
            _selectionBoxActionData!.originalSelection.union(notesInSelection),
          );
        }

        break;
      case EventHandlingState.deleting:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        final thisPoint = Point(event.offset, event.key);

        // We make a line between the previous event point and this point, and
        // we delete all notes that intersect that line
        final notesUnderCursorPath = notes.where(
          (note) {
            final noteTopLeft = Point(note.offset, note.key);
            final noteBottomRight =
                Point(note.offset + note.length, note.key + 1);

            // Discard if bounding boxes don't intersect
            return rectanglesIntersect(
                  Rectangle.fromPoints(
                    _deleteActionData!.mostRecentPoint,
                    thisPoint,
                  ),
                  Rectangle.fromPoints(
                    noteTopLeft,
                    noteBottomRight,
                  ),
                ) &&
                // Calculate if path segment intersects note
                lineIntersectsBox(
                  _deleteActionData!.mostRecentPoint,
                  thisPoint,
                  noteTopLeft,
                  noteBottomRight,
                );
          },
        ).toList();

        final notesToRemoveFromIgnore = <NoteModel>[];

        for (final note in _deleteActionData!.notesToTemporarilyIgnore) {
          if (!notesUnderCursorPath.contains(note)) {
            notesToRemoveFromIgnore.add(note);
          }
        }

        for (final note in notesToRemoveFromIgnore) {
          _deleteActionData!.notesToTemporarilyIgnore.remove(note);
        }

        for (final note in notesUnderCursorPath) {
          if (_deleteActionData!.notesToTemporarilyIgnore.contains(note)) {
            continue;
          }

          notes.remove(note);
          _deleteActionData!.notesDeleted.add(note);
          viewModel.selectedNotes.remove(note.id);
        }

        _deleteActionData!.mostRecentPoint = thisPoint;

        break;
      case EventHandlingState.resizingSingleNote:
      case EventHandlingState.resizingSelection:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        var snappedOriginalTime =
            _noteResizeActionData!.pointerStartOffset.floor();
        var snappedEventTime = event.offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.pianoRollSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: pattern.timeSignatureChanges,
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOriginalTime = getSnappedTime(
            rawTime: _noteResizeActionData!.pointerStartOffset.floor(),
            divisionChanges: divisionChanges,
            round: true,
          );

          snappedEventTime = getSnappedTime(
            rawTime: event.offset.floor(),
            divisionChanges: divisionChanges,
            round: true,
          );
        }

        late int snapAtSmallestNoteStart;

        final offsetOfSmallestNoteAtStart = _noteResizeActionData!
            .startLengths[_noteResizeActionData!.smallestNote]!;

        for (var i = 0; i < divisionChanges.length; i++) {
          if (i < divisionChanges.length - 1 &&
              divisionChanges[i + 1].offset <= offsetOfSmallestNoteAtStart) {
            continue;
          }

          snapAtSmallestNoteStart = divisionChanges[i].divisionSnapSize;

          break;
        }

        var diff = snappedEventTime - snappedOriginalTime;

        // Make sure no notes go below the smallest snap size if snapping is
        // enabled.
        if (!event.keyboardModifiers.alt &&
            _noteResizeActionData!.smallestStartLength + diff <
                snapAtSmallestNoteStart) {
          int snapCount = ((snapAtSmallestNoteStart -
                      (_noteResizeActionData!.smallestStartLength + diff)) /
                  snapAtSmallestNoteStart)
              .ceil();
          diff = diff + snapCount * snapAtSmallestNoteStart;
        }

        // If snapping is disabled, make sure the notes all have a length of at
        // least 1.
        if (event.keyboardModifiers.alt) {
          final newSmallestNoteSize =
              _noteResizeActionData!.smallestStartLength + diff;
          if (newSmallestNoteSize < 1) {
            diff += 1 - newSmallestNoteSize;
          }
        }

        for (final note in notes.where((note) =>
            _noteResizeActionData!.startLengths.containsKey(note.id))) {
          note.length = _noteResizeActionData!.startLengths[note.id]! + diff;
        }

        if (_eventHandlingState == EventHandlingState.resizingSingleNote) {
          setCursorNoteParameters(_noteResizeActionData!.pressedNote);
        }

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
          ? [_noteMoveActionData!.noteUnderCursor]
          : notes
              .where((note) =>
                  viewModel.selectedNotes.nonObservableInner.contains(note.id))
              .toList();

      // We already moved these note to their target positions. Now, we create
      // a command to move it from its original position to the target
      // position, which will be used for undo/redo.
      final offsetCommands = relevantNotes.map((note) {
        return SetNoteAttributeCommand(
          project: project,
          patternID: pattern.id,
          generatorID: project.activeGeneratorID!,
          noteID: note.id,
          attribute: NoteAttribute.offset,
          oldValue: _noteMoveActionData!.startTimes[note.id]!,
          newValue: note.offset,
        );
      });

      final keyCommands = relevantNotes.map((note) {
        return SetNoteAttributeCommand(
          project: project,
          patternID: pattern.id,
          generatorID: project.activeGeneratorID!,
          noteID: note.id,
          attribute: NoteAttribute.key,
          oldValue: _noteMoveActionData!.startKeys[note.id]!,
          newValue: note.key,
        );
      });

      final command = JournalPageCommand(
          project, offsetCommands.followedBy(keyCommands).toList());

      project.push(command);
    } else if (_eventHandlingState == EventHandlingState.deleting) {
      // There should already be an active journal page, so we don't need to
      // collect these manually.
      for (final note in _deleteActionData!.notesDeleted) {
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
    } else if (_eventHandlingState == EventHandlingState.resizingSingleNote ||
        _eventHandlingState == EventHandlingState.resizingSelection) {
      final diff = _noteResizeActionData!.pressedNote.length -
          _noteResizeActionData!
              .startLengths[_noteResizeActionData!.pressedNote.id]!;

      final commands = _noteResizeActionData!.startLengths.entries.map((entry) {
        return SetNoteAttributeCommand(
          project: project,
          patternID: project.song.activePatternID!,
          generatorID: project.activeGeneratorID!,
          noteID: entry.key,
          attribute: NoteAttribute.length,
          oldValue: entry.value,
          newValue: entry.value + diff,
        );
      }).toList();

      final command = JournalPageCommand(project, commands);

      project.push(command);
    }

    project.commitJournalPage();

    viewModel.pressedNote = null;

    _noteMoveActionData = null;
    _deleteActionData = null;
    _selectionBoxActionData = null;
    _noteResizeActionData = null;

    _eventHandlingState = EventHandlingState.idle;
  }
}
