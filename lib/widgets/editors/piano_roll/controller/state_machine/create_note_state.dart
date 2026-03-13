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

class PianoRollCreateNoteState extends PianoRollNoteInteractionState {
  PianoRollCreateNoteSessionData? _sessionData;
  Map<Id, PianoRollMoveNotePreview>? _preview;

  @visibleForTesting
  PianoRollCreateNoteSessionData? get sessionData => _sessionData;

  @visibleForTesting
  Map<Id, PianoRollMoveNotePreview>? get preview => _preview;

  bool _isCreatePointerDownSignal(EditorStateMachineEvent event) {
    return event is EditorStateMachineSignalEvent &&
        event.signal is _PianoRollPointerDownSignal;
  }

  NoteModel? _createPreviewNoteFromPointerDown({
    required double key,
    required double offset,
  }) {
    final eventTime = offset.floor();
    if (eventTime < 0) {
      return null;
    }

    final targetTime = interactionState.isAltPressed
        ? eventTime
        : snapTimeInActivePattern(rawTime: eventTime);

    return NoteModel(
      idAllocator: controller.idAllocator,
      key: key.floor(),
      velocity: viewModel.cursorNoteVelocity,
      length: viewModel.cursorNoteLength,
      offset: targetTime,
      pan: viewModel.cursorNotePan,
    );
  }

  void _applyPreview({
    required PianoRollCreateNoteSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    _preview = preview;

    final patternPreviewNote = parentState.activePattern.getPreviewNoteById(
      sessionData.createdNoteId,
    );
    final previewNote = preview[sessionData.createdNoteId];
    if (patternPreviewNote == null || previewNote == null) {
      return;
    }

    parentState.activePattern.updatePreviewNote(
      noteId: sessionData.createdNoteId,
      key: previewNote.key,
      offset: previewNote.offset,
    );

    syncLivePreviewForMoveSession(
      sessionData: sessionData.moveSessionData,
      preview: preview,
    );
  }

  void _initializeSession() {
    final dragStartContext = parentState.dragStartContext;
    if (dragStartContext == null) {
      return;
    }

    controller.clearPreviewState();
    viewModel.selectedNotes.clear();

    final createdNote = _createPreviewNoteFromPointerDown(
      key: dragStartContext.key,
      offset: dragStartContext.offset,
    );
    if (createdNote == null) {
      _sessionData = null;
      viewModel.pressedNote = null;
      return;
    }

    parentState.activePattern.addPreviewNote(createdNote);
    viewModel.pressedNote = createdNote.id;

    final moveSessionData = createMoveNotesSessionData(
      pointerOffset: dragStartContext.offset,
      noteUnderCursor: createdNote,
      notesToMove: [createdNote],
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
      preview: createInitialMoveNotesPreview(moveSessionData),
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
      name: 'Delegate pointer session to create note',
      from: PianoRollPointerSessionState,
      to: PianoRollCreateNoteState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.createNote &&
          _isCreatePointerDownSignal(event),
    ),
    .new(
      name: 'Exit create note',
      from: PianoRollCreateNoteState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily != PianoRollInteractionFamily.createNote,
    ),
  ];

  PianoRollCreateNoteState(super.parentState);

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
    final pattern = parentState.activePatternOrNull;
    if (sessionData != null && pattern != null) {
      final previewNote = pattern.getPreviewNoteById(sessionData.createdNoteId);
      if (previewNote != null) {
        final committedNote = NoteModel.fromNoteModel(previewNote);
        pattern.removePreviewNoteById(sessionData.createdNoteId);
        project.execute(
          AddNoteCommand(patternID: pattern.id, note: committedNote),
        );
      }
    }

    controller.liveNotes.removeAll();
    viewModel.pressedNote = null;
    controller.clearPreviewState();
    _clearSession();
  }
}
