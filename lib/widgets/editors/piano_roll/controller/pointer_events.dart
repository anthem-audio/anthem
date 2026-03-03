/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;

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
}

mixin _PianoRollPointerEventsMixin on _PianoRollController {
  // Fields for event handling

  var _eventHandlingState = EventHandlingState.idle;

  /// Data for note moves
  PianoRollMoveNotesSessionData? _noteMoveActionData;

  /// Data for note resize
  PianoRollResizeNotesSessionData? _noteResizeActionData;

  void leftPointerDown(PianoRollPointerDownEvent event) {
    final pattern = requireActivePattern();
    final notes = pattern.notes.nonObservableInner;

    if (event.keyboardModifiers.ctrl || viewModel.tool == EditorTool.select) {
      throw StateError(
        'Selection-box gestures are handled by the piano-roll state machine.',
      );
    }

    if (event.isResize && viewModel.tool == EditorTool.pencil) {
      if (event.noteUnderCursor == null) {
        throw ArgumentError("Resize event didn't provide a noteUnderCursor");
      }

      final pressedNote = requireActivePatternNote(event.noteUnderCursor!);

      viewModel.pressedNote = event.noteUnderCursor;

      late int smallestStartLength;
      late String smallestNoteId;
      late Map<String, int> startLengths;

      if (viewModel.selectedNotes.nonObservableInner.contains(pressedNote.id)) {
        _eventHandlingState = EventHandlingState.resizingSelection;

        final relevantNotes = notes.where(
          (note) =>
              viewModel.selectedNotes.nonObservableInner.contains(note.id),
        );
        var smallestNote = relevantNotes.first;
        for (final note in relevantNotes) {
          if (note.length < smallestNote.length) smallestNote = note;
        }

        smallestStartLength = smallestNote.length;
        smallestNoteId = smallestNote.id;
        startLengths = Map.fromEntries(
          relevantNotes.map((note) => MapEntry(note.id, note.length)),
        );
      } else {
        _eventHandlingState = EventHandlingState.resizingSingleNote;
        viewModel.selectedNotes.clear();

        startLengths = {pressedNote.id: pressedNote.length};
        smallestStartLength = pressedNote.length;
        smallestNoteId = pressedNote.id;
      }

      setCursorNoteParameters(pressedNote);

      _noteResizeActionData = PianoRollResizeNotesSessionData(
        pointerStartOffset: event.offset,
        pressedNote: pressedNote,
        startLengths: startLengths,
        smallestStartLength: smallestStartLength,
        smallestNote: smallestNoteId,
      );

      return;
    }

    void setMoveNoteInfo(NoteModel noteUnderCursor) {
      final startTimes = <Id, Time>{noteUnderCursor.id: noteUnderCursor.offset};
      final startKeys = <Id, int>{noteUnderCursor.id: noteUnderCursor.key};

      // If we're moving a selection, record the start times
      for (final note in notes.where(
        (note) => viewModel.selectedNotes.nonObservableInner.contains(note.id),
      )) {
        startTimes[note.id] = note.offset;
        startKeys[note.id] = note.key;
      }

      final startOfFirstNote =
          _eventHandlingState == EventHandlingState.movingSelection
          ? notes.fold<int>(
              maxSafeIntWeb,
              (previousValue, element) =>
                  viewModel.selectedNotes.nonObservableInner.contains(
                    element.id,
                  )
                  ? min(previousValue, element.offset)
                  : previousValue,
            )
          : noteUnderCursor.offset;
      final keyOfTopNote =
          _eventHandlingState == EventHandlingState.movingSelection
          ? notes.fold<int>(
              0,
              (previousValue, element) =>
                  viewModel.selectedNotes.nonObservableInner.contains(
                    element.id,
                  )
                  ? max(previousValue, element.key)
                  : previousValue,
            )
          : noteUnderCursor.key;
      final keyOfBottomNote =
          _eventHandlingState == EventHandlingState.movingSelection
          ? notes.fold<int>(
              maxSafeIntWeb,
              (previousValue, element) =>
                  viewModel.selectedNotes.nonObservableInner.contains(
                    element.id,
                  )
                  ? min(previousValue, element.key)
                  : previousValue,
            )
          : noteUnderCursor.key;

      _noteMoveActionData = PianoRollMoveNotesSessionData(
        noteUnderCursor: noteUnderCursor,
        timeOffset: event.offset - noteUnderCursor.offset,
        noteOffset: 0.5,
        startTimes: startTimes,
        startKeys: startKeys,
        startOfFirstNote: startOfFirstNote,
        keyOfTopNote: keyOfTopNote,
        keyOfBottomNote: keyOfBottomNote,
      );

      liveNotes.addNote(
        key: noteUnderCursor.key,
        velocity: noteUnderCursor.velocity,
        pan: noteUnderCursor.pan,
      );
    }

    if (event.noteUnderCursor != null) {
      var pressedNote = requireActivePatternNote(event.noteUnderCursor!);

      if (viewModel.selectedNotes.nonObservableInner.contains(
        event.noteUnderCursor,
      )) {
        _eventHandlingState = EventHandlingState.movingSelection;

        if (event.keyboardModifiers.shift) {
          project.startUndoGroup();

          final newSelectedNotes = ObservableSet<Id>();

          for (final note
              in notes
                  .where(
                    (note) => viewModel.selectedNotes.nonObservableInner
                        .contains(note.id),
                  )
                  .toList()) {
            final newNote = NoteModel.fromNoteModel(note);

            project.execute(
              AddNoteCommand(patternID: pattern.id, note: newNote),
            );

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

          project.execute(AddNoteCommand(patternID: pattern.id, note: newNote));
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

    final targetTime = event.keyboardModifiers.alt
        ? eventTime
        : snapTimeInActivePattern(
            rawTime: eventTime,
            viewWidthInPixels: event.pianoRollSize.width,
          );

    project.startUndoGroup();

    final note = addNoteToActivePattern(
      key: event.key.floor(),
      velocity: viewModel.cursorNoteVelocity,
      length: viewModel.cursorNoteLength,
      offset: targetTime,
      pan: viewModel.cursorNotePan,
    );

    setMoveNoteInfo(note);

    viewModel.pressedNote = note.id;
  }

  void legacyPointerDown(PianoRollPointerDownEvent event) {
    if (project.sequence.activePatternID == null) {
      return;
    }

    if (event.pointerEvent.buttons & kPrimaryMouseButton ==
            kPrimaryMouseButton &&
        viewModel.tool != EditorTool.eraser) {
      leftPointerDown(event);
    } else if (event.pointerEvent.buttons & kSecondaryMouseButton ==
            kSecondaryMouseButton ||
        viewModel.tool == EditorTool.eraser) {
      throw StateError(
        'Erase gestures are handled by the piano-roll state machine.',
      );
    }
  }

  void legacyPointerMove(PianoRollPointerMoveEvent event) {
    switch (_eventHandlingState) {
      case EventHandlingState.idle:
        break;
      case EventHandlingState.movingSingleNote:
      case EventHandlingState.movingSelection:
        final isSelectionMove =
            _eventHandlingState == EventHandlingState.movingSelection;

        final key = event.key - _noteMoveActionData!.noteOffset;
        final offset = event.offset - _noteMoveActionData!.timeOffset;

        final pattern = requireActivePattern();

        final notes = isSelectionMove
            ? pattern.notes
                  .where(
                    (note) => viewModel.selectedNotes.nonObservableInner
                        .contains(note.id),
                  )
                  .toList()
            : [_noteMoveActionData!.noteUnderCursor];

        var snappedOffset = offset.floor();

        if (!event.keyboardModifiers.alt) {
          snappedOffset = snapTimeInActivePattern(
            rawTime: offset.floor(),
            viewWidthInPixels: event.pianoRollSize.width,
            round: true,
            startTime: _noteMoveActionData!
                .startTimes[_noteMoveActionData!.noteUnderCursor.id]!,
          );
        }

        var timeOffsetFromEventStart =
            snappedOffset -
            _noteMoveActionData!.startTimes[_noteMoveActionData!
                .noteUnderCursor
                .id]!;
        var keyOffsetFromEventStart =
            key.round() -
            _noteMoveActionData!.startKeys[_noteMoveActionData!
                .noteUnderCursor
                .id]!;

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
          note.key =
              _noteMoveActionData!.startKeys[note.id]! +
              (shift ? 0 : keyOffsetFromEventStart);
          note.offset =
              _noteMoveActionData!.startTimes[note.id]! +
              (!shift && ctrl ? 0 : timeOffsetFromEventStart);
        }

        // Update the live note
        final noteUnderCursor = _noteMoveActionData!.noteUnderCursor;
        if (!liveNotes.hasNoteForKey(noteUnderCursor.key)) {
          liveNotes.removeAll();
          liveNotes.addNote(
            key: noteUnderCursor.key,
            velocity: noteUnderCursor.velocity,
            pan: noteUnderCursor.pan,
          );
        }

        break;
      case EventHandlingState.resizingSingleNote:
      case EventHandlingState.resizingSelection:
        final pattern = requireActivePattern();
        final notes = pattern.notes;

        var snappedOriginalTime = _noteResizeActionData!.pointerStartOffset
            .floor();
        var snappedEventTime = event.offset.floor();

        final divisionChanges = divisionChangesForPatternView(
          viewWidthInPixels: event.pianoRollSize.width,
        );

        if (!event.keyboardModifiers.alt) {
          snappedOriginalTime = snapTimeInActivePattern(
            rawTime: _noteResizeActionData!.pointerStartOffset.floor(),
            viewWidthInPixels: event.pianoRollSize.width,
            round: true,
          );

          snappedEventTime = snapTimeInActivePattern(
            rawTime: event.offset.floor(),
            viewWidthInPixels: event.pianoRollSize.width,
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
          int snapCount =
              ((snapAtSmallestNoteStart -
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

        for (final note in notes.where(
          (note) => _noteResizeActionData!.startLengths.containsKey(note.id),
        )) {
          note.length = _noteResizeActionData!.startLengths[note.id]! + diff;
        }

        if (_eventHandlingState == EventHandlingState.resizingSingleNote ||
            _eventHandlingState == EventHandlingState.resizingSelection) {
          setCursorNoteParameters(_noteResizeActionData!.pressedNote);
        }

        break;
    }
  }

  void legacyPointerUp(PianoRollPointerUpEvent event) {
    if (_eventHandlingState == EventHandlingState.movingSingleNote ||
        _eventHandlingState == EventHandlingState.movingSelection) {
      final pattern = requireActivePattern();
      final notes = pattern.notes;

      final isSingleNote =
          _eventHandlingState == EventHandlingState.movingSingleNote;

      final relevantNotes = isSingleNote
          ? [_noteMoveActionData!.noteUnderCursor]
          : notes
                .where(
                  (note) => viewModel.selectedNotes.nonObservableInner.contains(
                    note.id,
                  ),
                )
                .toList();

      final command = MoveNotesCommand(
        patternID: pattern.id,
        noteMoves: relevantNotes.map((note) {
          return (
            noteID: note.id,
            oldOffset: _noteMoveActionData!.startTimes[note.id]!,
            newOffset: note.offset,
            oldKey: _noteMoveActionData!.startKeys[note.id]!,
            newKey: note.key,
          );
        }).toList(),
      );

      project.push(command);
    } else if (_eventHandlingState == EventHandlingState.resizingSingleNote ||
        _eventHandlingState == EventHandlingState.resizingSelection) {
      final diff =
          _noteResizeActionData!.pressedNote.length -
          _noteResizeActionData!.startLengths[_noteResizeActionData!
              .pressedNote
              .id]!;

      final command = ResizeNotesCommand(
        patternID: requireActivePattern().id,
        noteResizes: _noteResizeActionData!.startLengths.entries.map((entry) {
          return (
            noteID: entry.key,
            oldLength: entry.value,
            newLength: entry.value + diff,
          );
        }).toList(),
      );

      project.push(command);
    }

    // No matter what, we need to reset the playing notes
    liveNotes.removeAll();

    project.commitUndoGroup();

    viewModel.pressedNote = null;

    _noteMoveActionData = null;
    _noteResizeActionData = null;

    _eventHandlingState = EventHandlingState.idle;
  }
}
