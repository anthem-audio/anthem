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

class PianoRollResizeNotesState extends PianoRollNoteInteractionState {
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

  PianoRollResizeNotesSessionData _createResizeNotesSessionData({
    required double pointerStartOffset,
    required NoteModel pressedNote,
    required Iterable<NoteModel> notesToResize,
    required bool isSelectionResize,
  }) {
    final resizingNotesById = <Id, NoteModel>{pressedNote.id: pressedNote};
    for (final note in notesToResize) {
      resizingNotesById[note.id] = note;
    }

    final resizingNotes = resizingNotesById.values.toList(growable: false);
    if (resizingNotes.isEmpty) {
      throw StateError('Resize session requires at least one note.');
    }

    var smallestNote = resizingNotes.first;
    final startLengths = <Id, Time>{};

    for (final note in resizingNotes) {
      startLengths[note.id] = note.length;
      if (note.length < smallestNote.length) {
        smallestNote = note;
      }
    }

    return PianoRollResizeNotesSessionData(
      pointerStartOffset: pointerStartOffset,
      startLengths: startLengths,
      smallestStartLength: smallestNote.length,
      smallestNote: smallestNote.id,
      pressedNote: pressedNote,
      isSelectionResize: isSelectionResize,
    );
  }

  Map<Id, PianoRollResizeNotePreview> _createInitialResizeNotesPreview(
    PianoRollResizeNotesSessionData sessionData,
  ) {
    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.startLengths.keys.map((noteId) {
        return MapEntry(noteId, (length: sessionData.startLengths[noteId]!));
      }),
    );
  }

  Map<Id, PianoRollResizeNotePreview> _resolveResizeNotesSessionPreview({
    required double currentOffset,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    var snappedOriginalTime = sessionData.pointerStartOffset.floor();
    var snappedEventTime = currentOffset.floor();

    final divisionChanges = controller.divisionChangesForPatternView(
      viewWidthInPixels: interactionState.viewSize.width,
    );

    if (!interactionState.isAltPressed) {
      snappedOriginalTime = snapTimeInActivePattern(
        rawTime: sessionData.pointerStartOffset.floor(),
        round: true,
      );

      snappedEventTime = snapTimeInActivePattern(
        rawTime: currentOffset.floor(),
        round: true,
      );
    }

    late int snapAtSmallestNoteStart;

    final offsetOfSmallestNoteAtStart =
        sessionData.startLengths[sessionData.smallestNote]!;

    for (var i = 0; i < divisionChanges.length; i++) {
      if (i < divisionChanges.length - 1 &&
          divisionChanges[i + 1].offset <= offsetOfSmallestNoteAtStart) {
        continue;
      }

      snapAtSmallestNoteStart = divisionChanges[i].divisionSnapSize;
      break;
    }

    var diff = snappedEventTime - snappedOriginalTime;

    if (!interactionState.isAltPressed &&
        sessionData.smallestStartLength + diff < snapAtSmallestNoteStart) {
      final snapCount =
          ((snapAtSmallestNoteStart -
                      (sessionData.smallestStartLength + diff)) /
                  snapAtSmallestNoteStart)
              .ceil();
      diff += snapCount * snapAtSmallestNoteStart;
    }

    if (interactionState.isAltPressed) {
      final newSmallestNoteSize = sessionData.smallestStartLength + diff;
      if (newSmallestNoteSize < 1) {
        diff += 1 - newSmallestNoteSize;
      }
    }

    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.startLengths.keys.map((noteId) {
        return MapEntry(noteId, (
          length: sessionData.startLengths[noteId]! + diff,
        ));
      }),
    );
  }

  ResizeNotesCommand _buildResizeNotesCommand({
    required PianoRollResizeNotesSessionData sessionData,
    required Map<Id, PianoRollResizeNotePreview> preview,
  }) {
    return ResizeNotesCommand(
      patternID: parentState.activePattern.id,
      noteResizes: preview.entries
          .map((entry) {
            return (
              noteID: entry.key,
              oldLength: sessionData.startLengths[entry.key]!,
              newLength: entry.value.length,
            );
          })
          .toList(growable: false),
    );
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

    final pattern = parentState.activePattern;
    final pressedNote = parentState.requireActivePatternNote(noteId);
    final isSelectionResize = viewModel.selectedNotes.nonObservableInner
        .contains(pressedNote.id);

    if (!isSelectionResize) {
      viewModel.selectedNotes.clear();
    }

    viewModel.pressedNote = pressedNote.id;
    setCursorNoteParameters(pressedNote);

    final notesToResize = isSelectionResize
        ? pattern.notes.where(
            (note) =>
                viewModel.selectedNotes.nonObservableInner.contains(note.id),
          )
        : <NoteModel>[pressedNote];

    _sessionData = _createResizeNotesSessionData(
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
      preview: _createInitialResizeNotesPreview(sessionData),
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
      from: PianoRollPointerSessionState,
      to: PianoRollResizeNotesState,
      canTransition: ({required data, required event, required currentState}) =>
          data.activeInteractionFamily ==
              PianoRollInteractionFamily.resizeNotes &&
          _isResizePointerDownSignal(event),
    ),
    .new(
      name: 'Exit resize notes',
      from: PianoRollResizeNotesState,
      to: PianoRollPointerSessionState,
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
    if (sessionData == null || currentOffset == null) {
      return;
    }

    _applyPreview(
      sessionData: sessionData,
      preview: _resolveResizeNotesSessionPreview(
        currentOffset: currentOffset,
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
        _buildResizeNotesCommand(sessionData: sessionData, preview: preview),
        execute: true,
      );
    }

    viewModel.pressedNote = null;
    viewModel.clearTransientPreviewState();
    _clearSession();
  }
}
