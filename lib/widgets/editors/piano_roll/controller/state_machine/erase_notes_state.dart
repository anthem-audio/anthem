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

class PianoRollEraseNotesState extends PianoRollSessionLeafState {
  PianoRollEraseNotesSessionData? _sessionData;

  @visibleForTesting
  PianoRollEraseNotesSessionData? get sessionData => _sessionData;

  List<NoteModel> _getNotesUnderCursor(
    Iterable<NoteModel> notes,
    double key,
    double offset,
  ) {
    final keyFloor = key.floor();

    return notes.where((note) {
      return offset >= note.offset &&
          offset < note.offset + note.length &&
          keyFloor == note.key;
    }).toList();
  }

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

    final pattern = parentState.activePattern;
    final note = pattern.notes[noteId];
    if (note != null &&
        // Ignore events that come from the resize handle but aren't over
        // the note.
        note.offset + note.length > dragStartContext.offset) {
      pattern.notes.remove(noteId);
      _sessionData!.notesDeleted.add(note);
      viewModel.selectedNotes.remove(note.id);
    }

    _sessionData!.notesToTemporarilyIgnore.addAll(
      _getNotesUnderCursor(
        pattern.notes.values,
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

    final notes = parentState.activePattern.notes.values;
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

      parentState.activePattern.notes.remove(note.id);
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
      name: 'Delegate pointer session to erase notes',
      from: PianoRollPointerSessionState,
      to: PianoRollEraseNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily == PianoRollInteractionFamily.erase &&
          isPointerDownSignal(event),
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
        event.signal is! _PianoRollPointerMoveSignal) {
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
          patternID: parentState.activePattern.id,
          notes: sessionData.notesDeleted,
        ),
      );
    }

    project.commitUndoGroup();
    _clearSession();
  }
}
