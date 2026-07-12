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

part of 'piano_roll_state_machine.dart';

class PianoRollResizeNotesSessionData {
  final double pointerStartOffset;
  final Map<Id, PianoRollSessionNoteState> notesById;
  final Id smallestNoteId;
  final Id pressedNoteId;
  final bool isSelectionResize;

  Iterable<Id> get noteIds => notesById.keys;

  PianoRollSessionNoteState get smallestNote => requireNote(smallestNoteId);

  PianoRollSessionNoteState get pressedNote => requireNote(pressedNoteId);

  Time get smallestOriginalLength => smallestNote.length;

  PianoRollSessionNoteState requireNote(Id noteId) {
    final note = notesById[noteId];
    if (note == null) {
      throw StateError('Session note $noteId is missing.');
    }

    return note;
  }

  PianoRollResizeNotesSessionData({
    required this.pointerStartOffset,
    required Map<Id, PianoRollSessionNoteState> notesById,
    required this.smallestNoteId,
    required this.pressedNoteId,
    required this.isSelectionResize,
  }) : notesById = Map<Id, PianoRollSessionNoteState>.unmodifiable(notesById);
}

class PianoRollResizeNotesState extends PianoRollSessionLeafState
    with PianoRollSharedNoteSessionHelpers {
  PianoRollResizeNotesSessionData? _sessionData;
  Map<Id, PianoRollResizeNotePreview>? _preview;
  CursorOverrideHandle? _cursorOverrideHandle;

  @visibleForTesting
  PianoRollResizeNotesSessionData? get sessionData => _sessionData;

  @visibleForTesting
  Map<Id, PianoRollResizeNotePreview>? get preview => _preview;

  PianoRollResizeNotesSessionData _createResizeNotesSessionData({
    required double pointerStartOffset,
    required NoteModel pressedNote,
    required Iterable<NoteModel> notesToResize,
    required bool isSelectionResize,
  }) {
    final resizingNotesById = <Id, PianoRollSessionNoteState>{
      pressedNote.id: PianoRollSessionNoteState.fromNoteModel(pressedNote),
    };
    for (final note in notesToResize) {
      resizingNotesById[note.id] = PianoRollSessionNoteState.fromNoteModel(
        note,
      );
    }

    final resizingNotes = resizingNotesById.values.toList(growable: false);
    if (resizingNotes.isEmpty) {
      throw StateError('Resize session requires at least one note.');
    }

    var smallestNote = resizingNotes.first;
    for (final noteState in resizingNotes) {
      if (noteState.length < smallestNote.length) {
        smallestNote = noteState;
      }
    }

    return PianoRollResizeNotesSessionData(
      pointerStartOffset: pointerStartOffset,
      notesById: resizingNotesById,
      smallestNoteId: smallestNote.id,
      pressedNoteId: pressedNote.id,
      isSelectionResize: isSelectionResize,
    );
  }

  Map<Id, PianoRollResizeNotePreview> _createInitialResizeNotesPreview(
    PianoRollResizeNotesSessionData sessionData,
  ) {
    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.noteIds.map((noteId) {
        return MapEntry(noteId, (
          length: sessionData.requireNote(noteId).length,
        ));
      }),
    );
  }

  Map<Id, PianoRollResizeNotePreview> _resolveResizeNotesSessionPreview({
    required double currentOffset,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    final startTime = sessionData.pointerStartOffset.floor();
    final currentTime = currentOffset.floor();
    final divisionChanges = controller.divisionChangesForPatternView(
      viewWidthInPixels: interactionState.viewSize.width,
    );

    var diff = interactionState.isAltPressed
        ? currentTime - startTime
        : getSnappedDragDelta(
            startTime: startTime,
            currentTime: currentTime,
            divisionChanges: divisionChanges,
          );
    diff = interactionState.isAltPressed
        ? _clampDeltaToValidRange(resizeDelta: diff, sessionData: sessionData)
        : _clampSnappedDeltaToValidRange(
            startTime: startTime,
            resizeDelta: diff,
            divisionChanges: divisionChanges,
            sessionData: sessionData,
          );

    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.noteIds.map((noteId) {
        final note = sessionData.requireNote(noteId);
        return MapEntry(noteId, (length: note.length + diff));
      }),
    );
  }

  int _minimumResizeDelta(PianoRollResizeNotesSessionData sessionData) {
    return 1 - sessionData.smallestOriginalLength;
  }

  int _clampSnappedDeltaToValidRange({
    required int startTime,
    required int resizeDelta,
    required List<DivisionChange> divisionChanges,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    final minDelta = _minimumResizeDelta(sessionData);
    var guardedDelta = resizeDelta;
    while (guardedDelta < minDelta) {
      final nextDelta = stepSnappedDragDeltaTowardZero(
        startTime: startTime,
        snappedDelta: guardedDelta,
        divisionChanges: divisionChanges,
      );
      if (nextDelta == guardedDelta) {
        return max(guardedDelta, minDelta);
      }
      guardedDelta = nextDelta;
    }

    return guardedDelta;
  }

  int _clampDeltaToValidRange({
    required int resizeDelta,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    return max(resizeDelta, _minimumResizeDelta(sessionData));
  }

  ResizeNotesCommand? _buildResizeNotesCommand({
    required PianoRollResizeNotesSessionData sessionData,
    required Map<Id, PianoRollResizeNotePreview> preview,
  }) {
    final noteResizes = preview.entries
        .map((entry) {
          final note = sessionData.requireNote(entry.key);
          return (
            noteID: entry.key,
            oldLength: note.length,
            newLength: entry.value.length,
          );
        })
        .where((resize) => resize.oldLength != resize.newLength)
        .toList(growable: false);

    if (noteResizes.isEmpty) {
      return null;
    }

    return ResizeNotesCommand(
      patternID: parentState.activePattern.id,
      noteResizes: noteResizes,
    );
  }

  void _applyPreview({
    required PianoRollResizeNotesSessionData sessionData,
    required Map<Id, PianoRollResizeNotePreview> preview,
  }) {
    _preview = preview;
    parentState.activePattern.clearNoteOverrides();

    for (final entry in preview.entries) {
      final noteId = entry.key;
      final previewNote = entry.value;
      if (previewNote.length == sessionData.requireNote(noteId).length) {
        continue;
      }

      parentState.activePattern.setNoteOverride(
        noteId: noteId,
        length: previewNote.length,
      );
    }

    final pressedLength = preview[sessionData.pressedNote.id]?.length;
    if (pressedLength != null) {
      viewModel.cursorNoteLength = pressedLength;
      viewModel.cursorNoteVelocity = sessionData.pressedNote.velocity;
      viewModel.cursorNotePan = sessionData.pressedNote.pan;
    }
  }

  void _initializeSession() {
    final noteId = parentState.dragStartRealNoteId;
    if (noteId == null) {
      throw ArgumentError("Resize event didn't provide a noteUnderCursor");
    }

    controller.clearPreviewState();

    final pattern = parentState.activePattern;
    final pressedNote = parentState.requireActivePatternNote(noteId);
    final isSelectionResize = viewModel.selectedNotes.nonObservableInner
        .contains(pressedNote.id);

    if (!isSelectionResize) {
      viewModel.selectedNotes.clear();
    }

    viewModel.pressedNote = pressedNote.id;
    setCursorNoteParameters(pressedNote);

    final dragStartOffset = parentState.dragStartOffset;
    if (dragStartOffset == null) {
      return;
    }

    final notesToResize = isSelectionResize
        ? viewModel.selectedNotes.nonObservableInner
              .map((noteId) => pattern.notes[noteId])
              .nonNulls
        : <NoteModel>[pressedNote];

    _sessionData = _createResizeNotesSessionData(
      pointerStartOffset: dragStartOffset,
      pressedNote: pressedNote,
      notesToResize: notesToResize,
      isSelectionResize: isSelectionResize,
    );

    final sessionData = _sessionData;
    if (sessionData == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: _createInitialResizeNotesPreview(sessionData),
    );
  }

  void _clearSession() {
    _sessionData = null;
    _preview = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate pointer session to resize notes',
      from: PianoRollPointerSessionState,
      to: PianoRollResizeNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.resizeNotes &&
          isPointerDownSignal(event),
    ),
    .new(
      name: 'Exit resize notes',
      from: PianoRollResizeNotesState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily !=
          PianoRollInteractionFamily.resizeNotes,
    ),
  ];

  PianoRollResizeNotesState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    _setResizeCursorOverride();
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    final sessionData = _sessionData;
    final currentOffset = parentState.currentOffset;
    if (sessionData == null || currentOffset == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: _resolveResizeNotesSessionPreview(
        currentOffset: currentOffset,
        sessionData: sessionData,
      ),
    );
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    final sessionData = _sessionData;
    final preview = _preview;
    if (sessionData != null && preview != null) {
      final command = _buildResizeNotesCommand(
        sessionData: sessionData,
        preview: preview,
      );
      if (command != null) {
        project.push(command, execute: true);
      }
    }

    viewModel.pressedNote = null;
    controller.clearPreviewState();
    _clearSession();
    _clearResizeCursorOverride();
  }

  @override
  void onDispose() {
    _clearResizeCursorOverride();
  }

  void _setResizeCursorOverride() {
    _cursorOverrideHandle?.close();
    _cursorOverrideHandle = ServiceRegistry.mainWindowController
        .pushCursorOverride(SystemMouseCursors.resizeLeftRight);
  }

  void _clearResizeCursorOverride() {
    _cursorOverrideHandle?.close();
    _cursorOverrideHandle = null;
  }
}
