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
  final NoteModel noteUnderCursor;

  /// Difference between the start of the pressed note and the cursor X, in
  /// time.
  final double timeOffset;

  /// Difference between the start of the pressed note and the cursor Y, in
  /// notes.
  final double noteOffset;

  final Map<Id, Time> startTimes;
  final Map<Id, int> startKeys;

  /// Start offset of the earliest note. Used to ensure no note moves before
  /// the start of the pattern.
  final Time startOfFirstNote;
  final int keyOfTopNote;
  final int keyOfBottomNote;
  final bool isSelectionMove;
  final bool didDuplicateOnPointerDown;
  final Set<Id> duplicatedNoteIds;

  PianoRollMoveNotesSessionData({
    required this.noteUnderCursor,
    required this.timeOffset,
    required this.noteOffset,
    required this.startTimes,
    required this.startKeys,
    required this.startOfFirstNote,
    required this.keyOfTopNote,
    required this.keyOfBottomNote,
    required this.isSelectionMove,
    required this.didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
  }) : duplicatedNoteIds = Set<Id>.unmodifiable(duplicatedNoteIds);
}

class PianoRollMoveNotesState
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

  PianoRollMoveNotesSessionData? _sessionData;

  @visibleForTesting
  PianoRollMoveNotesSessionData? get sessionData => _sessionData;

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

  bool _isMovePointerSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollAdaptedPointerSignal;
  }

  void _initializeSession(PianoRollPointerDownEvent event) {
    final noteId = event.noteUnderCursor;
    if (noteId == null) {
      throw StateError(
        'Move-note sessions require a note under the cursor on pointer down.',
      );
    }

    final pattern = controller.requireActivePattern();
    final notes = pattern.notes.nonObservableInner;
    final selectedNotes = viewModel.selectedNotes.nonObservableInner;
    var pressedNote = controller.requireActivePatternNote(noteId);
    final isSelectionMove = selectedNotes.contains(noteId);
    var didDuplicateOnPointerDown = false;
    final duplicatedNoteIds = <Id>{};

    if (isSelectionMove) {
      if (event.keyboardModifiers.shift) {
        project.startUndoGroup();
        didDuplicateOnPointerDown = true;

        final newSelectedNotes = ObservableSet<Id>();

        for (final note
            in notes
                .where((note) {
                  return selectedNotes.contains(note.id);
                })
                .toList(growable: false)) {
          final newNote = NoteModel.fromNoteModel(note);

          project.execute(AddNoteCommand(patternID: pattern.id, note: newNote));

          newSelectedNotes.add(newNote.id);
          duplicatedNoteIds.add(newNote.id);

          if (note.id == noteId) {
            pressedNote = newNote;
          }
        }

        viewModel.selectedNotes = newSelectedNotes;
      }
    } else {
      viewModel.selectedNotes.clear();

      if (event.keyboardModifiers.shift) {
        didDuplicateOnPointerDown = true;

        final newNote = NoteModel.fromNoteModel(pressedNote);
        project.execute(AddNoteCommand(patternID: pattern.id, note: newNote));
        duplicatedNoteIds.add(newNote.id);
      }

      controller.setCursorNoteParameters(pressedNote);
    }

    viewModel.pressedNote = pressedNote.id;

    final notesToMove = isSelectionMove
        ? pattern.notes.where(
            (note) =>
                viewModel.selectedNotes.nonObservableInner.contains(note.id),
          )
        : <NoteModel>[pressedNote];

    _sessionData = controller.createMoveNotesSessionData(
      event: event,
      noteUnderCursor: pressedNote,
      notesToMove: notesToMove,
      isSelectionMove: isSelectionMove,
      didDuplicateOnPointerDown: didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
    );

    controller.liveNotes.addNote(
      key: pressedNote.key,
      velocity: pressedNote.velocity,
      pan: pressedNote.pan,
    );
  }

  void _clearSession() {
    _sessionData = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate adapted session to move notes',
      from: PianoRollNoteInteractionState,
      to: PianoRollMoveNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily ==
              PianoRollInteractionFamily.moveNotes &&
          _isMovePointerSignal(event),
    ),
    .new(
      name: 'Exit move notes',
      from: PianoRollMoveNotesState,
      to: PianoRollNoteInteractionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeAdaptedInteractionFamily !=
          PianoRollInteractionFamily.moveNotes,
    ),
  ];

  PianoRollMoveNotesState(super.parentState);

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
      sessionData: sessionData,
    );
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    final sessionData = _sessionData;
    if (sessionData != null) {
      project.push(controller.buildMoveNotesCommand(sessionData: sessionData));
    }

    controller.liveNotes.removeAll();
    project.commitUndoGroup();
    viewModel.pressedNote = null;
    _clearSession();
  }
}
