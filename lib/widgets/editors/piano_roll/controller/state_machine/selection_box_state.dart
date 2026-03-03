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

class PianoRollSelectionBoxSessionData {
  final Point<double> start;
  final Set<Id> originalSelection;
  final bool isSubtractiveSelectionLatched;

  PianoRollSelectionBoxSessionData({
    required this.start,
    required this.originalSelection,
    required this.isSubtractiveSelectionLatched,
  });
}

class PianoRollSelectionBoxState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  @override
  PianoRollPointerSessionState get parentState =>
      super.parentState as PianoRollPointerSessionState;

  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;

  PianoRollSelectionBoxSessionData? _sessionData;

  @visibleForTesting
  PianoRollSelectionBoxSessionData? get sessionData => _sessionData;

  bool _isSelectionBoxPointerSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollAdaptedPointerSignal;
  }

  bool _isPointerMoveSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollAdaptedPointerMoveSignal;
  }

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

  void _initializeSelectionSession(PianoRollPointerDownEvent event) {
    final isSubtractiveSelectionLatched =
        event.keyboardModifiers.shift &&
        event.noteUnderCursor != null &&
        viewModel.selectedNotes.nonObservableInner.contains(
          event.noteUnderCursor,
        );

    if (!event.keyboardModifiers.shift) {
      viewModel.selectedNotes.clear();
    }

    _sessionData = PianoRollSelectionBoxSessionData(
      start: Point(event.offset, event.key),
      originalSelection: Set<Id>.unmodifiable(
        viewModel.selectedNotes.nonObservableInner,
      ),
      isSubtractiveSelectionLatched: isSubtractiveSelectionLatched,
    );
  }

  void _syncSelection(PianoRollPointerMoveEvent event) {
    final sessionData = _sessionData;
    if (sessionData == null) {
      return;
    }

    viewModel.selectionBox = Rectangle.fromPoints(
      sessionData.start,
      Point(event.offset, event.key),
    );

    final notesInSelection = controller
        .requireActivePattern()
        .notes
        .where(
          (note) => rectanglesIntersect(
            viewModel.selectionBox!,
            Rectangle(note.offset, note.key, note.length, 1),
          ),
        )
        .map((note) => note.id)
        .toSet();

    final nextSelection = sessionData.isSubtractiveSelectionLatched
        ? sessionData.originalSelection.difference(notesInSelection)
        : sessionData.originalSelection.union(notesInSelection);

    viewModel.selectedNotes = ObservableSet.of(nextSelection);
  }

  void _clearSelectionSession() {
    _sessionData = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate adapted session to selection box',
      from: PianoRollPointerSessionState,
      to: PianoRollSelectionBoxState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily ==
              PianoRollInteractionFamily.selectionBox &&
          _isSelectionBoxPointerSignal(event),
    ),
    .new(
      name: 'Exit selection box',
      from: PianoRollSelectionBoxState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily !=
          PianoRollInteractionFamily.selectionBox,
    ),
  ];

  PianoRollSelectionBoxState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    final pointerDownEvent = _pointerDownEvent(event);
    if (pointerDownEvent == null) {
      return;
    }

    _initializeSelectionSession(pointerDownEvent);
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    final pointerMoveEvent = _pointerMoveEvent(event);
    if (pointerMoveEvent == null) {
      return;
    }

    _syncSelection(pointerMoveEvent);
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    viewModel.selectionBox = null;
    _clearSelectionSession();
  }
}
