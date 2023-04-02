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

  /// A single note is being moved.
  resizingSingleNote,

  /// A selection of notes are being moved.
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

mixin _PianoRollPointerEventsMixin on _PianoRollController {
  // Fields for event handling
  // Would be nice to replace some of these groups with records when records
  // are stabilized in Dart 3

  var _eventHandlingState = EventHandlingState.idle;

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

  double? _noteResizePointerStartOffset;
  Map<ID, Time>? _noteResizeStartLengths;
  Time? _noteResizeSmallestStartLength;
  ID? _noteResizeSmallestNoteAtStart;
  NoteModel? _noteResizePressedNote;

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

  void leftPointerDown(PianoRollPointerDownEvent event) {
    final pattern = project.song.patterns[project.song.activePatternID]!;
    final notes =
        pattern.notes[project.activeGeneratorID]?.nonObservableInner ??
            <NoteModel>[];

    if (event.keyboardModifiers.ctrl ||
        viewModel.selectedTool == EditorTool.select) {
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

      _selectionBoxStart = Point(event.offset, event.key);
      _selectionBoxOriginalSelection =
          viewModel.selectedNotes.nonObservableInner;

      return;
    }

    if (event.isResize && viewModel.selectedTool == EditorTool.pencil) {
      if (event.noteUnderCursor == null) {
        throw ArgumentError("Resize event didn't provide a noteUnderCursor");
      }

      final note = notes.firstWhere((note) => note.id == event.noteUnderCursor);

      _noteResizePointerStartOffset = event.offset;
      viewModel.pressedNote = event.noteUnderCursor;
      _noteResizePressedNote = note;

      if (viewModel.selectedNotes.nonObservableInner.contains(note.id)) {
        _eventHandlingState = EventHandlingState.resizingSelection;

        final relevantNotes = notes.where((note) =>
            viewModel.selectedNotes.nonObservableInner.contains(note.id));
        var smallestNote = relevantNotes.first;
        for (final note in relevantNotes) {
          if (note.length < smallestNote.length) smallestNote = note;
        }

        _noteResizeSmallestStartLength = smallestNote.length;
        _noteResizeSmallestNoteAtStart = smallestNote.id;
        _noteResizeStartLengths = Map.fromEntries(
            relevantNotes.map((note) => MapEntry(note.id, note.length)));
      } else {
        _eventHandlingState = EventHandlingState.resizingSingleNote;
        viewModel.selectedNotes.clear();

        _noteResizeStartLengths = {note.id: note.length};
        _noteResizeSmallestStartLength = note.length;
        _noteResizeSmallestNoteAtStart = note.id;
      }

      setCursorNoteParameters(note);

      return;
    }

    void setMoveNoteInfo(NoteModel noteUnderCursor) {
      _noteMoveNoteUnderCursor = noteUnderCursor;
      _noteMoveTimeOffset = event.offset - noteUnderCursor.offset;
      _noteMoveNoteOffset = 0.5;
      _noteMoveStartTimes = {noteUnderCursor.id: noteUnderCursor.offset};
      _noteMoveStartKeys = {noteUnderCursor.id: noteUnderCursor.key};

      // If we're moving a selection, record the start times
      for (final note in notes.where((note) =>
          viewModel.selectedNotes.nonObservableInner.contains(note.id))) {
        _noteMoveStartTimes![note.id] = note.offset;
        _noteMoveStartKeys![note.id] = note.key;
      }

      if (_eventHandlingState == EventHandlingState.movingSelection) {
        _noteMoveStartOfFirstNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? min(previousValue, element.offset)
                  : previousValue,
        );
        _noteMoveKeyOfTopNote = notes.fold<int>(
          0,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? max(previousValue, element.key)
                  : previousValue,
        );
        _noteMoveKeyOfBottomNote = notes.fold<int>(
          0x7FFFFFFFFFFFFFFF,
          (previousValue, element) =>
              viewModel.selectedNotes.nonObservableInner.contains(element.id)
                  ? min(previousValue, element.key)
                  : previousValue,
        );
      } else {
        _noteMoveStartOfFirstNote = noteUnderCursor.offset;
        _noteMoveKeyOfTopNote = noteUnderCursor.key;
        _noteMoveKeyOfBottomNote = noteUnderCursor.key;
      }

      setCursorNoteParameters(noteUnderCursor);
    }

    if (event.noteUnderCursor != null) {
      var pressedNote =
          notes.firstWhere((element) => element.id == event.noteUnderCursor);

      if (viewModel.selectedNotes.nonObservableInner
          .contains(event.noteUnderCursor)) {
        _eventHandlingState = EventHandlingState.movingSelection;

        if (event.keyboardModifiers.shift) {
          project.startJournalPage();

          final newSelectedNotes = ObservableSet<String>();

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
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
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

    _deleteMostRecentPoint = Point(event.offset, event.key);

    project.startJournalPage();

    final pattern = project.song.patterns[project.song.activePatternID]!;
    final notes = pattern.notes[project.activeGeneratorID]!;

    _deleteNotesDeleted = {};
    _deleteNotesToTemporarilyIgnore = {};

    if (event.noteUnderCursor != null) {
      notes.removeWhere((note) {
        final remove = note.id == event.noteUnderCursor &&
            // Ignore events that come from the resize handle but aren't over
            // the note.
            note.offset + note.length > event.offset;

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
            kPrimaryMouseButton &&
        viewModel.selectedTool != EditorTool.eraser) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryMouseButton ==
            kSecondaryMouseButton ||
        viewModel.selectedTool == EditorTool.eraser) {
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
                .where((note) => viewModel.selectedNotes.nonObservableInner
                    .contains(note.id))
                .toList()
            : [_noteMoveNoteUnderCursor!];

        var snappedOffset = offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.pianoRollSize.width,
          snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
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
            startTime: _noteMoveStartTimes![_noteMoveNoteUnderCursor!.id]!,
          );
        }

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
      case EventHandlingState.resizingSingleNote:
      case EventHandlingState.resizingSelection:
        final pattern = project.song.patterns[project.song.activePatternID]!;
        final notes = pattern.notes[project.activeGeneratorID]!;

        var snappedOriginalTime = _noteResizePointerStartOffset!.floor();
        var snappedEventTime = event.offset.floor();

        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.pianoRollSize.width,
          snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: pattern.timeSignatureChanges,
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOriginalTime = getSnappedTime(
            rawTime: _noteResizePointerStartOffset!.floor(),
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

        final offsetOfSmallestNoteAtStart =
            _noteResizeStartLengths![_noteResizeSmallestNoteAtStart]!;

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
            _noteResizeSmallestStartLength! + diff < snapAtSmallestNoteStart) {
          int snapCount = ((snapAtSmallestNoteStart -
                      (_noteResizeSmallestStartLength! + diff)) /
                  snapAtSmallestNoteStart)
              .ceil();
          diff = diff + snapCount * snapAtSmallestNoteStart;
        }

        // If snapping is disabled, make sure the notes all have a length of at
        // least 1.
        if (event.keyboardModifiers.alt) {
          final newSmallestNoteSize = _noteResizeSmallestStartLength! + diff;
          if (newSmallestNoteSize < 1) {
            diff += 1 - newSmallestNoteSize;
          }
        }

        for (final note in notes
            .where((note) => _noteResizeStartLengths!.containsKey(note.id))) {
          note.length = _noteResizeStartLengths![note.id]! + diff;
        }

        setCursorNoteParameters(_noteResizePressedNote!);

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
          oldValue: _noteMoveStartTimes![note.id]!,
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
          oldValue: _noteMoveStartKeys![note.id]!,
          newValue: note.key,
        );
      });

      final command = JournalPageCommand(
          project, offsetCommands.followedBy(keyCommands).toList());

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
    } else if (_eventHandlingState == EventHandlingState.resizingSingleNote ||
        _eventHandlingState == EventHandlingState.resizingSelection) {
      final diff = _noteResizePressedNote!.length -
          _noteResizeStartLengths![_noteResizePressedNote!.id]!;

      final commands = _noteResizeStartLengths!.entries.map((entry) {
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

    _noteResizePointerStartOffset = null;
    _noteResizeStartLengths = null;
    _noteResizeSmallestStartLength = null;
    _noteResizeSmallestNoteAtStart = null;
    _noteResizePressedNote = null;

    _eventHandlingState = EventHandlingState.idle;
  }
}
