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
  final Map<Id, Time> startLengths;
  final Time smallestStartLength;
  final Id smallestNote;
  final NoteModel pressedNote;
  final bool isSelectionResize;

  PianoRollResizeNotesSessionData({
    required this.pointerStartOffset,
    required this.startLengths,
    required this.smallestStartLength,
    required this.smallestNote,
    required this.pressedNote,
    required this.isSelectionResize,
  });
}

class PianoRollResizeNotesState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  @override
  PianoRollNoteInteractionState get parentState =>
      super.parentState as PianoRollNoteInteractionState;

  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;

  PianoRollResizeNotesSessionData? _sessionData;
  Map<Id, PianoRollResizeNotePreview>? _preview;

  @visibleForTesting
  PianoRollResizeNotesSessionData? get sessionData => _sessionData;

  @visibleForTesting
  Map<Id, PianoRollResizeNotePreview>? get preview => _preview;

  bool _isResizePointerDownSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollPointerDownSignal;
  }

  void _applyPreview({
    required PianoRollResizeNotesSessionData sessionData,
    required Map<Id, PianoRollResizeNotePreview> preview,
  }) {
    _preview = preview;
    viewModel.noteOverrides.clear();

    for (final entry in preview.entries) {
      final noteId = entry.key;
      final previewNote = entry.value;
      if (previewNote.length == sessionData.startLengths[noteId]!) {
        continue;
      }

      viewModel.noteOverrides[noteId] = PianoRollNoteOverride(
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

    viewModel.clearTransientPreviewState();

    final pattern = controller.requireActivePattern();
    final pressedNote = controller.requireActivePatternNote(noteId);
    final isSelectionResize = viewModel.selectedNotes.nonObservableInner
        .contains(pressedNote.id);

    if (!isSelectionResize) {
      viewModel.selectedNotes.clear();
    }

    viewModel.pressedNote = pressedNote.id;
    controller.setCursorNoteParameters(pressedNote);

    final notesToResize = isSelectionResize
        ? pattern.notes.where(
            (note) =>
                viewModel.selectedNotes.nonObservableInner.contains(note.id),
          )
        : <NoteModel>[pressedNote];

    _sessionData = controller.createResizeNotesSessionData(
      pointerStartOffset: parentState.dragStartOffset!,
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
      preview: controller.createInitialResizeNotesPreview(sessionData),
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
      from: PianoRollNoteInteractionState,
      to: PianoRollResizeNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.resizeNotes &&
          _isResizePointerDownSignal(event),
    ),
    .new(
      name: 'Exit resize notes',
      from: PianoRollResizeNotesState,
      to: PianoRollNoteInteractionState,
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
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    final sessionData = _sessionData;
    final currentOffset = parentState.currentOffset;
    if (event is! EditorStateMachineSignalEvent ||
        event.signal is! _PianoRollPointerMoveSignal ||
        sessionData == null ||
        currentOffset == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: controller.resolveResizeNotesSessionPreview(
        currentOffset: currentOffset,
        viewWidthInPixels: interactionState.viewSize.width,
        altPressed: interactionState.isAltPressed,
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
      project.push(
        controller.buildResizeNotesCommand(
          sessionData: sessionData,
          preview: preview,
        ),
        execute: true,
      );
    }

    viewModel.pressedNote = null;
    viewModel.clearTransientPreviewState();
    _clearSession();
  }
}
