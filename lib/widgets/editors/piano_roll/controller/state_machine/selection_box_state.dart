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

class PianoRollSelectionBoxState extends PianoRollSessionLeafState {
  PianoRollSelectionBoxSessionData? _sessionData;

  @visibleForTesting
  PianoRollSelectionBoxSessionData? get sessionData => _sessionData;

  void _initializeSelectionSession() {
    final dragStartContext = parentState.dragStartContext;
    if (dragStartContext == null) {
      return;
    }

    final isSubtractiveSelectionLatched =
        interactionState.isShiftPressed &&
        parentState.dragStartRealNoteId != null &&
        viewModel.selectedNotes.nonObservableInner.contains(
          parentState.dragStartRealNoteId,
        );

    if (!interactionState.isShiftPressed) {
      viewModel.selectedNotes.clear();
    }

    _sessionData = PianoRollSelectionBoxSessionData(
      start: Point(dragStartContext.offset, dragStartContext.key),
      originalSelection: Set<Id>.unmodifiable(
        viewModel.selectedNotes.nonObservableInner,
      ),
      isSubtractiveSelectionLatched: isSubtractiveSelectionLatched,
    );
  }

  void _syncSelection() {
    final sessionData = _sessionData;
    final dragCurrentContext = parentState.dragCurrentContext;
    if (sessionData == null || dragCurrentContext == null) {
      return;
    }

    viewModel.selectionBox = Rectangle.fromPoints(
      sessionData.start,
      Point(dragCurrentContext.offset, dragCurrentContext.key),
    );

    final notesInSelection = parentState.activePattern.notes.values
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
      name: 'Delegate pointer session to selection box',
      from: PianoRollPointerSessionState,
      to: PianoRollSelectionBoxState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.selectionBox &&
          isPointerDownSignal(event),
    ),
    .new(
      name: 'Exit selection box',
      from: PianoRollSelectionBoxState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily !=
          PianoRollInteractionFamily.selectionBox,
    ),
  ];

  PianoRollSelectionBoxState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    _initializeSelectionSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    if (event is! EditorStateMachineSignalEvent ||
        event.signal is! _PianoRollPointerMoveSignal) {
      return;
    }

    _syncSelection();
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
