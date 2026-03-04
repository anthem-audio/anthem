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

class PianoRollCreateNoteSessionData {
  final Id createdNoteId;
  final PianoRollMoveNotesSessionData moveSessionData;

  PianoRollCreateNoteSessionData({
    required this.createdNoteId,
    required this.moveSessionData,
  });
}

class PianoRollCreateNoteState
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

  PianoRollCreateNoteSessionData? _sessionData;
  Map<Id, PianoRollMoveNotePreview>? _preview;

  @visibleForTesting
  PianoRollCreateNoteSessionData? get sessionData => _sessionData;

  @visibleForTesting
  Map<Id, PianoRollMoveNotePreview>? get preview => _preview;

  PianoRollPointerDownEvent? _pointerDownEvent(EditorStateMachineEvent event) {
    if (event is! EditorStateMachineSignalEvent) {
      return null;
    }

    final signal = event.signal;
    return signal is _PianoRollAdaptedPointerDownSignal ? signal.event : null;
  }

  PianoRollPointerMoveEvent? _pointerMoveEvent(EditorStateMachineEvent event) {
    if (event is! EditorStateMachineSignalEvent) {
      return null;
    }

    final signal = event.signal;
    return signal is _PianoRollAdaptedPointerMoveSignal ? signal.event : null;
  }

  bool _isCreatePointerSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollAdaptedPointerSignal;
  }

  void _applyPreview({
    required PianoRollCreateNoteSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    _preview = preview;

    final transientNote = viewModel.transientNotes[sessionData.createdNoteId];
    final previewNote = preview[sessionData.createdNoteId];
    if (transientNote == null || previewNote == null) {
      return;
    }

    viewModel.transientNotes[sessionData.createdNoteId] =
        PianoRollTransientNote(
          id: transientNote.id,
          key: previewNote.key,
          velocity: transientNote.velocity,
          length: transientNote.length,
          offset: previewNote.offset,
          pan: transientNote.pan,
        );

    controller.syncLivePreviewForMoveSession(
      sessionData: sessionData.moveSessionData,
      preview: preview,
    );
  }

  void _initializeSession(PianoRollPointerDownEvent event) {
    viewModel.clearTransientPreviewState();
    viewModel.selectedNotes.clear();

    final createdNote = controller.createTransientNoteFromPointerDown(
      event: event,
    );
    if (createdNote == null) {
      _sessionData = null;
      viewModel.pressedNote = null;
      viewModel.pressedTransientNote = null;
      return;
    }

    viewModel.transientNotes[createdNote.id] = createdNote;
    viewModel.pressedNote = null;
    viewModel.pressedTransientNote = createdNote.id;

    final createdNoteSnapshot = controller.createCommittedNoteFromTransient(
      createdNote,
    );
    final moveSessionData = controller.createMoveNotesSessionData(
      event: event,
      noteUnderCursor: createdNoteSnapshot,
      notesToMove: [createdNoteSnapshot],
      isSelectionMove: false,
      didDuplicateOnPointerDown: false,
      duplicatedNoteIds: const {},
      movingTransientNoteIds: {createdNote.id},
    );

    _sessionData = PianoRollCreateNoteSessionData(
      createdNoteId: createdNote.id,
      moveSessionData: moveSessionData,
    );

    _applyPreview(
      sessionData: _sessionData!,
      preview: controller.createInitialMoveNotesPreview(moveSessionData),
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
      name: 'Delegate adapted session to create note',
      from: PianoRollNoteInteractionState,
      to: PianoRollCreateNoteState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily ==
              PianoRollInteractionFamily.createNote &&
          _isCreatePointerSignal(event),
    ),
    .new(
      name: 'Exit create note',
      from: PianoRollCreateNoteState,
      to: PianoRollNoteInteractionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily !=
          PianoRollInteractionFamily.createNote,
    ),
  ];

  PianoRollCreateNoteState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    final pointerDownEvent = _pointerDownEvent(event);
    if (pointerDownEvent == null) {
      return;
    }

    _initializeSession(pointerDownEvent);
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    final pointerMoveEvent = _pointerMoveEvent(event);
    final sessionData = _sessionData;
    if (pointerMoveEvent == null || sessionData == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: controller.resolveMoveNotesSessionPreview(
        event: pointerMoveEvent,
        sessionData: sessionData.moveSessionData,
      ),
    );
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    final sessionData = _sessionData;
    final pattern = controller.activePatternOrNull;
    if (sessionData != null && pattern != null) {
      final transientNote = viewModel.transientNotes[sessionData.createdNoteId];
      if (transientNote != null) {
        project.execute(
          AddNoteCommand(
            patternID: pattern.id,
            note: controller.createCommittedNoteFromTransient(transientNote),
          ),
        );
      }
    }

    controller.liveNotes.removeAll();
    viewModel.pressedNote = null;
    viewModel.clearTransientPreviewState();
    _clearSession();
  }
}
