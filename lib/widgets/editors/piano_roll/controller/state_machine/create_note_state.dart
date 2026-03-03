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

  @visibleForTesting
  PianoRollCreateNoteSessionData? get sessionData => _sessionData;

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

  void _initializeSession(PianoRollPointerDownEvent event) {
    final createdNote = controller.createNoteFromPointerDown(event: event);
    if (createdNote == null) {
      _sessionData = null;
      viewModel.pressedNote = null;
      return;
    }

    viewModel.pressedNote = createdNote.id;

    final moveSessionData = controller.createMoveNotesSessionData(
      event: event,
      noteUnderCursor: createdNote,
      notesToMove: [createdNote],
      isSelectionMove: false,
      didDuplicateOnPointerDown: false,
      duplicatedNoteIds: const {},
    );

    _sessionData = PianoRollCreateNoteSessionData(
      createdNoteId: createdNote.id,
      moveSessionData: moveSessionData,
    );

    controller.liveNotes.addNote(
      key: createdNote.key,
      velocity: createdNote.velocity,
      pan: createdNote.pan,
    );
  }

  void _clearSession() {
    _sessionData = null;
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

    controller.applyMoveNotesSessionUpdate(
      event: pointerMoveEvent,
      sessionData: sessionData.moveSessionData,
    );
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    final sessionData = _sessionData;
    if (sessionData != null) {
      project.push(
        controller.buildMoveNotesCommand(
          sessionData: sessionData.moveSessionData,
        ),
      );
    }

    controller.liveNotes.removeAll();
    project.commitUndoGroup();
    viewModel.pressedNote = null;
    _clearSession();
  }
}
