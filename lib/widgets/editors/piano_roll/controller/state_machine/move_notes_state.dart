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

class PianoRollMoveNotesSessionData {
  final Id anchorNoteId;

  /// Difference between the start of the pressed note and the cursor X, in
  /// time.
  final double timeOffset;

  /// Difference between the start of the pressed note and the cursor Y, in
  /// notes.
  final double noteOffset;

  final Map<Id, PianoRollSessionNoteState> notesById;

  /// Start offset of the earliest note. Used to ensure no note moves before
  /// the start of the pattern.
  final Time startOfFirstNote;
  final int keyOfTopNote;
  final int keyOfBottomNote;
  final bool didDuplicateOnPointerDown;
  final Set<Id> duplicatedNoteIds;
  final Set<Id> movingTransientNoteIds;

  PianoRollSessionNoteState get anchorNote => requireNote(anchorNoteId);

  Iterable<Id> get noteIds => notesById.keys;

  PianoRollSessionNoteState requireNote(Id noteId) {
    final note = notesById[noteId];
    if (note == null) {
      throw StateError('Session note $noteId is missing.');
    }

    return note;
  }

  PianoRollMoveNotesSessionData({
    required this.anchorNoteId,
    required this.timeOffset,
    required this.noteOffset,
    required Map<Id, PianoRollSessionNoteState> notesById,
    required this.startOfFirstNote,
    required this.keyOfTopNote,
    required this.keyOfBottomNote,
    required this.didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) : notesById = Map<Id, PianoRollSessionNoteState>.unmodifiable(notesById),
       duplicatedNoteIds = Set<Id>.unmodifiable(duplicatedNoteIds),
       movingTransientNoteIds = Set<Id>.unmodifiable(movingTransientNoteIds);
}

class PianoRollMoveNotesState extends PianoRollSessionLeafState
    with PianoRollSharedNoteSessionHelpers, PianoRollMoveSessionHelpers {
  PianoRollMoveNotesSessionData? _sessionData;
  Map<Id, PianoRollMoveNotePreview>? _preview;

  @visibleForTesting
  PianoRollMoveNotesSessionData? get sessionData => _sessionData;

  @visibleForTesting
  Map<Id, PianoRollMoveNotePreview>? get preview => _preview;

  void _applyPreview({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    _preview = preview;
    parentState.activePattern.clearNoteOverrides();

    for (final entry in preview.entries) {
      final noteId = entry.key;
      final previewNote = entry.value;

      if (sessionData.movingTransientNoteIds.contains(noteId)) {
        parentState.activePattern.updatePreviewNote(
          noteId: noteId,
          key: previewNote.key,
          offset: previewNote.offset,
        );
        continue;
      }

      final startNote = sessionData.requireNote(noteId);
      final hasKeyOverride = previewNote.key != startNote.key;
      final hasOffsetOverride = previewNote.offset != startNote.offset;
      if (!hasKeyOverride && !hasOffsetOverride) {
        continue;
      }

      parentState.activePattern.setResolvedNotePreview(
        noteId: noteId,
        key: hasKeyOverride ? previewNote.key : null,
        offset: hasOffsetOverride ? previewNote.offset : null,
      );
    }

    syncLivePreviewForMoveSession(sessionData: sessionData, preview: preview);
  }

  NoteModel _buildTransientDuplicate(
    NoteModel source, {
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) {
    final previewNote = NoteModel(
      idAllocator: controller.idAllocator,
      key: source.key,
      velocity: source.velocity,
      length: source.length,
      offset: source.offset,
      pan: source.pan,
    );
    parentState.activePattern.addPreviewNote(previewNote);
    duplicatedNoteIds.add(previewNote.id);
    movingTransientNoteIds.add(previewNote.id);
    return previewNote;
  }

  ({
    NoteModel sessionPressedNote,
    List<NoteModel> notesToMove,
    bool didDuplicateOnPointerDown,
  })
  _beginSelectionMove({
    required NoteModel pressedNote,
    required Iterable<NoteModel> selectedNotes,
    required bool shiftPressed,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) {
    if (!shiftPressed) {
      viewModel.pressedNote = pressedNote.id;
      return (
        sessionPressedNote: pressedNote,
        notesToMove: selectedNotes.toList(growable: false),
        didDuplicateOnPointerDown: false,
      );
    }

    final newSelectedNotes = <Id>{};
    final transientNotesToMove = <NoteModel>[];
    var sessionPressedNote = pressedNote;

    for (final note in selectedNotes) {
      final previewNote = _buildTransientDuplicate(
        note,
        duplicatedNoteIds: duplicatedNoteIds,
        movingTransientNoteIds: movingTransientNoteIds,
      );

      newSelectedNotes.add(previewNote.id);
      transientNotesToMove.add(previewNote);

      if (note.id == pressedNote.id) {
        sessionPressedNote = previewNote;
        viewModel.pressedNote = previewNote.id;
      }
    }

    viewModel.selectedNotes = ObservableSet.of(newSelectedNotes);
    return (
      sessionPressedNote: sessionPressedNote,
      notesToMove: transientNotesToMove,
      didDuplicateOnPointerDown: true,
    );
  }

  ({
    NoteModel sessionPressedNote,
    List<NoteModel> notesToMove,
    bool didDuplicateOnPointerDown,
  })
  _beginSingleNoteMove({
    required NoteModel pressedNote,
    required bool shiftPressed,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) {
    viewModel.selectedNotes.clear();

    if (!shiftPressed) {
      viewModel.pressedNote = pressedNote.id;
      setCursorNoteParameters(pressedNote);
      return (
        sessionPressedNote: pressedNote,
        notesToMove: [pressedNote],
        didDuplicateOnPointerDown: false,
      );
    }

    // Shift-dragging a single unselected note previews the duplicate itself
    // as the moving note. The original stays committed and stationary until
    // the gesture ends.
    final previewNote = _buildTransientDuplicate(
      pressedNote,
      duplicatedNoteIds: duplicatedNoteIds,
      movingTransientNoteIds: movingTransientNoteIds,
    );
    viewModel.selectedNotes = ObservableSet.of({previewNote.id});
    viewModel.pressedNote = previewNote.id;
    setCursorNoteParameters(pressedNote);

    return (
      sessionPressedNote: previewNote,
      notesToMove: [previewNote],
      didDuplicateOnPointerDown: true,
    );
  }

  void _initializeSession() {
    final dragStartContext = parentState.dragStartContext;
    final noteId = parentState.dragStartRealNoteId;
    if (dragStartContext == null || noteId == null) {
      throw StateError(
        'Move-note sessions require a note under the cursor on pointer down.',
      );
    }

    controller.clearPreviewState();

    final pattern = parentState.activePattern;
    final notes = pattern.notes.nonObservableInner.values;
    final selectedNotes = viewModel.selectedNotes.nonObservableInner;
    final pressedNote = parentState.requireActivePatternNote(noteId);
    final isSelectionMove = selectedNotes.contains(noteId);
    final duplicatedNoteIds = <Id>{};
    final movingTransientNoteIds = <Id>{};
    final selectedNoteModels = notes
        .where((note) => selectedNotes.contains(note.id))
        .toList(growable: false);
    final moveStart = isSelectionMove
        ? _beginSelectionMove(
            pressedNote: pressedNote,
            selectedNotes: selectedNoteModels,
            shiftPressed: interactionState.isShiftPressed,
            duplicatedNoteIds: duplicatedNoteIds,
            movingTransientNoteIds: movingTransientNoteIds,
          )
        : _beginSingleNoteMove(
            pressedNote: pressedNote,
            shiftPressed: interactionState.isShiftPressed,
            duplicatedNoteIds: duplicatedNoteIds,
            movingTransientNoteIds: movingTransientNoteIds,
          );

    _sessionData = createMoveNotesSessionData(
      pointerOffset: dragStartContext.offset,
      noteUnderCursor: moveStart.sessionPressedNote,
      notesToMove: moveStart.notesToMove,
      didDuplicateOnPointerDown: moveStart.didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
      movingTransientNoteIds: movingTransientNoteIds,
    );

    final sessionData = _sessionData;
    if (sessionData == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: createInitialMoveNotesPreview(sessionData),
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
      name: 'Delegate pointer session to move notes',
      from: PianoRollPointerSessionState,
      to: PianoRollMoveNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.moveNotes &&
          isPointerDownSignal(event),
    ),
    .new(
      name: 'Exit move notes',
      from: PianoRollMoveNotesState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily != PianoRollInteractionFamily.moveNotes,
    ),
  ];

  PianoRollMoveNotesState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    final sessionData = _sessionData;
    final currentKey = parentState.currentKey;
    final currentOffset = parentState.currentOffset;
    if (sessionData == null || currentKey == null || currentOffset == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: resolveMoveNotesSessionPreview(
        key: currentKey,
        offset: currentOffset,
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
    final pattern = parentState.activePatternOrNull;
    if (sessionData != null && preview != null && pattern != null) {
      if (sessionData.movingTransientNoteIds.isNotEmpty) {
        final notesToCommit = <NoteModel>[];
        for (final noteId in sessionData.noteIds) {
          final previewNote = pattern.getPreviewNoteById(noteId);
          if (previewNote == null) {
            continue;
          }

          notesToCommit.add(NoteModel.fromNoteModel(previewNote));
        }

        for (final note in notesToCommit) {
          pattern.removePreviewNoteById(note.id);
        }

        project.startUndoGroup();
        for (final note in notesToCommit) {
          project.execute(AddNoteCommand(patternID: pattern.id, note: note));
        }
        project.commitUndoGroup();
      } else {
        if (sessionData.didDuplicateOnPointerDown) {
          final notesToCommit = <NoteModel>[];
          for (final noteId in sessionData.duplicatedNoteIds) {
            final previewNote = pattern.getPreviewNoteById(noteId);
            if (previewNote == null) {
              continue;
            }

            notesToCommit.add(NoteModel.fromNoteModel(previewNote));
          }

          for (final note in notesToCommit) {
            pattern.removePreviewNoteById(note.id);
            project.execute(AddNoteCommand(patternID: pattern.id, note: note));
          }
        }

        project.push(
          buildMoveNotesCommand(sessionData: sessionData, preview: preview),
          execute: true,
        );
      }
    }

    controller.liveNotes.removeAll();
    viewModel.pressedNote = null;
    controller.clearPreviewState();
    _clearSession();
  }
}
