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
  final Map<Id, Time> lengths;
  final Map<Id, double> velocities;
  final Map<Id, double> pans;

  /// Start offset of the earliest note. Used to ensure no note moves before
  /// the start of the pattern.
  final Time startOfFirstNote;
  final int keyOfTopNote;
  final int keyOfBottomNote;
  final bool isSelectionMove;
  final bool didDuplicateOnPointerDown;
  final Set<Id> duplicatedNoteIds;
  final Set<Id> movingTransientNoteIds;

  PianoRollMoveNotesSessionData({
    required this.noteUnderCursor,
    required this.timeOffset,
    required this.noteOffset,
    required this.startTimes,
    required this.startKeys,
    required this.lengths,
    required this.velocities,
    required this.pans,
    required this.startOfFirstNote,
    required this.keyOfTopNote,
    required this.keyOfBottomNote,
    required this.isSelectionMove,
    required this.didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) : duplicatedNoteIds = Set<Id>.unmodifiable(duplicatedNoteIds),
       movingTransientNoteIds = Set<Id>.unmodifiable(movingTransientNoteIds);
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
  Map<Id, PianoRollMoveNotePreview>? _preview;

  @visibleForTesting
  PianoRollMoveNotesSessionData? get sessionData => _sessionData;

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

  bool _isMovePointerSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollAdaptedPointerSignal;
  }

  NoteModel _snapshotFromTransientNote(PianoRollTransientNote note) {
    return controller.createCommittedNoteFromTransient(note);
  }

  void _applyPreview({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    _preview = preview;
    viewModel.noteOverrides.clear();

    for (final entry in preview.entries) {
      final noteId = entry.key;
      final previewNote = entry.value;

      if (sessionData.movingTransientNoteIds.contains(noteId)) {
        final transientNote = viewModel.transientNotes[noteId];
        if (transientNote == null) {
          continue;
        }

        viewModel.transientNotes[noteId] = PianoRollTransientNote(
          id: transientNote.id,
          key: previewNote.key,
          velocity: transientNote.velocity,
          length: transientNote.length,
          offset: previewNote.offset,
          pan: transientNote.pan,
        );
        continue;
      }

      final hasKeyOverride = previewNote.key != sessionData.startKeys[noteId]!;
      final hasOffsetOverride =
          previewNote.offset != sessionData.startTimes[noteId]!;
      if (!hasKeyOverride && !hasOffsetOverride) {
        continue;
      }

      viewModel.noteOverrides[noteId] = PianoRollNoteOverride(
        key: hasKeyOverride ? previewNote.key : null,
        offset: hasOffsetOverride ? previewNote.offset : null,
      );
    }

    controller.syncLivePreviewForMoveSession(
      sessionData: sessionData,
      preview: preview,
    );
  }

  void _initializeSession(PianoRollPointerDownEvent event) {
    final noteId = event.noteUnderCursor;
    if (noteId == null) {
      throw StateError(
        'Move-note sessions require a note under the cursor on pointer down.',
      );
    }

    viewModel.clearTransientPreviewState();

    final pattern = controller.requireActivePattern();
    final notes = pattern.notes.nonObservableInner;
    final selectedNotes = viewModel.selectedNotes.nonObservableInner;
    var pressedNote = controller.requireActivePatternNote(noteId);
    var sessionPressedNote = pressedNote;
    final isSelectionMove = selectedNotes.contains(noteId);
    var didDuplicateOnPointerDown = false;
    final duplicatedNoteIds = <Id>{};
    final movingTransientNoteIds = <Id>{};
    late final List<NoteModel> notesToMove;

    if (isSelectionMove) {
      if (event.keyboardModifiers.shift) {
        didDuplicateOnPointerDown = true;

        final newSelectedNotes = <Id>{};
        final transientNotesToMove = <NoteModel>[];
        viewModel.selectedTransientNotes.clear();

        for (final note
            in notes
                .where((note) {
                  return selectedNotes.contains(note.id);
                })
                .toList(growable: false)) {
          final transientNote = PianoRollTransientNote(
            id: getId(),
            key: note.key,
            velocity: note.velocity,
            length: note.length,
            offset: note.offset,
            pan: note.pan,
          );
          final transientSnapshot = _snapshotFromTransientNote(transientNote);

          viewModel.transientNotes[transientNote.id] = transientNote;
          newSelectedNotes.add(transientNote.id);
          duplicatedNoteIds.add(transientNote.id);
          movingTransientNoteIds.add(transientNote.id);
          transientNotesToMove.add(transientSnapshot);

          if (note.id == noteId) {
            sessionPressedNote = transientSnapshot;
            viewModel.pressedTransientNote = transientNote.id;
            viewModel.pressedNote = null;
          }
        }

        viewModel.selectedNotes = ObservableSet.of(newSelectedNotes);
        viewModel.selectedTransientNotes.addAll(newSelectedNotes);
        notesToMove = transientNotesToMove;
      } else {
        viewModel.pressedNote = pressedNote.id;
        viewModel.pressedTransientNote = null;
        viewModel.selectedTransientNotes.clear();
        notesToMove = pattern.notes
            .where(
              (note) =>
                  viewModel.selectedNotes.nonObservableInner.contains(note.id),
            )
            .toList(growable: false);
      }
    } else {
      viewModel.selectedNotes.clear();
      viewModel.selectedTransientNotes.clear();

      if (event.keyboardModifiers.shift) {
        didDuplicateOnPointerDown = true;

        final transientNote = PianoRollTransientNote(
          id: getId(),
          key: pressedNote.key,
          velocity: pressedNote.velocity,
          length: pressedNote.length,
          offset: pressedNote.offset,
          pan: pressedNote.pan,
        );
        viewModel.transientNotes[transientNote.id] = transientNote;
        duplicatedNoteIds.add(transientNote.id);
      }

      controller.setCursorNoteParameters(pressedNote);
      viewModel.pressedNote = pressedNote.id;
      viewModel.pressedTransientNote = null;
      notesToMove = [pressedNote];
    }

    _sessionData = controller.createMoveNotesSessionData(
      event: event,
      noteUnderCursor: sessionPressedNote,
      notesToMove: notesToMove,
      isSelectionMove: isSelectionMove,
      didDuplicateOnPointerDown: didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
      movingTransientNoteIds: movingTransientNoteIds,
    );

    final sessionData = _sessionData;
    if (sessionData == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: controller.createInitialMoveNotesPreview(sessionData),
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

    _applyPreview(
      sessionData: sessionData,
      preview: controller.resolveMoveNotesSessionPreview(
        event: pointerMoveEvent,
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
    final pattern = controller.activePatternOrNull;
    if (sessionData != null && preview != null && pattern != null) {
      if (sessionData.movingTransientNoteIds.isNotEmpty) {
        project.startUndoGroup();
        for (final noteId in sessionData.startTimes.keys) {
          final transientNote = viewModel.transientNotes[noteId];
          if (transientNote == null) {
            continue;
          }

          project.execute(
            AddNoteCommand(
              patternID: pattern.id,
              note: controller.createCommittedNoteFromTransient(transientNote),
            ),
          );
        }
        project.commitUndoGroup();
      } else {
        if (sessionData.didDuplicateOnPointerDown) {
          for (final noteId in sessionData.duplicatedNoteIds) {
            final transientNote = viewModel.transientNotes[noteId];
            if (transientNote == null) {
              continue;
            }

            project.execute(
              AddNoteCommand(
                patternID: pattern.id,
                note: controller.createCommittedNoteFromTransient(
                  transientNote,
                ),
              ),
            );
          }
        }

        project.push(
          controller.buildMoveNotesCommand(
            sessionData: sessionData,
            preview: preview,
          ),
          execute: true,
        );
      }
    }

    controller.liveNotes.removeAll();
    viewModel.pressedNote = null;
    viewModel.clearTransientPreviewState();
    _clearSession();
  }
}
