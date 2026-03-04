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

class PianoRollEraseNotesSessionData {
  final Set<NoteModel> notesToTemporarilyIgnore;
  final Set<NoteModel> notesDeleted;
  Point<double> mostRecentPoint;

  PianoRollEraseNotesSessionData({
    required this.notesToTemporarilyIgnore,
    required this.notesDeleted,
    required this.mostRecentPoint,
  });
}

class PianoRollEraseNotesState
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

  PianoRollEraseNotesSessionData? _sessionData;

  @visibleForTesting
  PianoRollEraseNotesSessionData? get sessionData => _sessionData;

  void _initializeSession() {
    final dragStartContext = parentState.dragStartContext;
    if (dragStartContext == null) {
      return;
    }

    project.startUndoGroup();

    _sessionData = PianoRollEraseNotesSessionData(
      mostRecentPoint: Point(dragStartContext.offset, dragStartContext.key),
      notesDeleted: {},
      notesToTemporarilyIgnore: {},
    );

    final noteId = parentState.dragStartRealNoteId;
    if (noteId == null) {
      return;
    }

    final pattern = controller.requireActivePattern();
    final notes = pattern.notes;

    notes.removeWhere((note) {
      final remove =
          note.id == noteId &&
          // Ignore events that come from the resize handle but aren't over
          // the note.
          note.offset + note.length > dragStartContext.offset;

      if (remove) {
        _sessionData!.notesDeleted.add(note);
        viewModel.selectedNotes.remove(note.id);
      }

      return remove;
    });

    _sessionData!.notesToTemporarilyIgnore.addAll(
      controller.getNotesUnderCursor(
        notes,
        dragStartContext.key,
        dragStartContext.offset,
      ),
    );
  }

  void _handleMove() {
    final sessionData = _sessionData;
    final dragCurrentContext = parentState.dragCurrentContext;
    if (sessionData == null || dragCurrentContext == null) {
      return;
    }

    final notes = controller.requireActivePattern().notes;
    final thisPoint = Point(dragCurrentContext.offset, dragCurrentContext.key);

    // We make a line between the previous event point and this point, and
    // we delete all notes that intersect that line.
    final notesUnderCursorPath = notes.where((note) {
      final noteTopLeft = Point(note.offset, note.key);
      final noteBottomRight = Point(note.offset + note.length, note.key + 1);

      return rectanglesIntersect(
            Rectangle.fromPoints(sessionData.mostRecentPoint, thisPoint),
            Rectangle.fromPoints(noteTopLeft, noteBottomRight),
          ) &&
          lineIntersectsBox(
            sessionData.mostRecentPoint,
            thisPoint,
            noteTopLeft,
            noteBottomRight,
          );
    }).toList();

    final notesToRemoveFromIgnore = <NoteModel>[];
    for (final note in sessionData.notesToTemporarilyIgnore) {
      if (!notesUnderCursorPath.contains(note)) {
        notesToRemoveFromIgnore.add(note);
      }
    }

    for (final note in notesToRemoveFromIgnore) {
      sessionData.notesToTemporarilyIgnore.remove(note);
    }

    for (final note in notesUnderCursorPath) {
      if (sessionData.notesToTemporarilyIgnore.contains(note)) {
        continue;
      }

      notes.remove(note);
      sessionData.notesDeleted.add(note);
      viewModel.selectedNotes.remove(note.id);
    }

    sessionData.mostRecentPoint = thisPoint;
  }

  void _clearSession() {
    _sessionData = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate adapted session to erase notes',
      from: PianoRollPointerSessionState,
      to: PianoRollEraseNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily == PianoRollInteractionFamily.erase &&
          event is EditorStateMachineSignalEvent &&
          event.signal is _PianoRollAdaptedPointerSignal,
    ),
    .new(
      name: 'Exit erase notes',
      from: PianoRollEraseNotesState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily != PianoRollInteractionFamily.erase,
    ),
  ];

  PianoRollEraseNotesState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    if (event is! EditorStateMachineSignalEvent ||
        event.signal is! _PianoRollAdaptedPointerMoveSignal) {
      return;
    }

    _handleMove();
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> to,
  }) {
    final sessionData = _sessionData;
    if (sessionData != null && sessionData.notesDeleted.isNotEmpty) {
      project.push(
        DeleteNotesCommand(
          patternID: controller.requireActivePattern().id,
          notes: sessionData.notesDeleted,
        ),
      );
    }

    project.commitUndoGroup();
    _clearSession();
  }
}
