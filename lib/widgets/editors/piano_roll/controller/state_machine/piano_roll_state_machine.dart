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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'create_note_state.dart';
part 'erase_notes_state.dart';
part 'move_notes_state.dart';
part 'resize_notes_state.dart';
part 'selection_box_state.dart';

sealed class _PianoRollPointerSignal {
  const _PianoRollPointerSignal();
}

class _PianoRollPointerDownSignal extends _PianoRollPointerSignal {
  const _PianoRollPointerDownSignal();
}

class _PianoRollPointerMoveSignal extends _PianoRollPointerSignal {
  const _PianoRollPointerMoveSignal();
}

class _PianoRollPointerUpSignal extends _PianoRollPointerSignal {
  const _PianoRollPointerUpSignal();
}

bool _isPianoRollNoteInteractionFamily(PianoRollInteractionFamily? family) {
  return switch (family) {
    PianoRollInteractionFamily.moveNotes ||
    PianoRollInteractionFamily.resizeNotes ||
    PianoRollInteractionFamily.createNote => true,
    null ||
    PianoRollInteractionFamily.selectionBox ||
    PianoRollInteractionFamily.erase => false,
  };
}

class PianoRollActivePointer {
  double x;
  double y;

  PianoRollActivePointer(this.x, this.y);

  PianoRollActivePointer clone() => PianoRollActivePointer(x, y);

  Offset toOffset() => Offset(x, y);
}

class PianoRollPointerContext {
  final Offset localPosition;
  final double key;
  final double offset;
  final PianoRollRenderedNoteRef? noteUnderCursor;
  final PianoRollRenderedNoteRef? resizeHandleUnderCursor;

  const PianoRollPointerContext({
    required this.localPosition,
    required this.key,
    required this.offset,
    required this.noteUnderCursor,
    required this.resizeHandleUnderCursor,
  });

  Id? get realNoteUnderCursorId =>
      noteUnderCursor?.realNoteId ?? resizeHandleUnderCursor?.realNoteId;

  bool get isOverResizeHandle => resizeHandleUnderCursor?.realNoteId != null;
}

/// The primary interaction state machine for piano-roll canvas editing.
class PianoRollStateMachine
    extends EditorStateMachine<PianoRollStateMachineData> {
  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final PianoRollController controller;

  PianoRollStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
    required this.controller,
  });

  factory PianoRollStateMachine.create({
    required ProjectModel project,
    required PianoRollViewModel viewModel,
    required PianoRollController controller,
  }) {
    final data = PianoRollStateMachineData()
      ..renderedTimeViewStart = viewModel.timeView.start
      ..renderedTimeViewEnd = viewModel.timeView.end
      ..renderedKeyHeight = viewModel.keyHeight
      ..renderedKeyValueAtTop = viewModel.keyValueAtTop;
    final idleState = PianoRollIdleState();
    final pointerSessionState = PianoRollPointerSessionState(idleState);
    final noteInteractionState = PianoRollNoteInteractionState(
      pointerSessionState,
    );
    final selectionBoxState = PianoRollSelectionBoxState(pointerSessionState);
    final eraseNotesState = PianoRollEraseNotesState(pointerSessionState);
    final moveNotesState = PianoRollMoveNotesState(noteInteractionState);
    final resizeNotesState = PianoRollResizeNotesState(noteInteractionState);
    final createNoteState = PianoRollCreateNoteState(noteInteractionState);
    final states = <EditorStateMachineState<PianoRollStateMachineData>>[
      idleState,
      pointerSessionState,
      noteInteractionState,
      selectionBoxState,
      eraseNotesState,
      moveNotesState,
      resizeNotesState,
      createNoteState,
    ];

    return PianoRollStateMachine._(
      data: data,
      idleState: idleState,
      states: states,
      project: project,
      viewModel: viewModel,
      controller: controller,
    );
  }

  @visibleForTesting
  PianoRollPointerContext resolvePointerContextForPosition(
    Offset localPosition,
  ) {
    return data.resolvePointerContext(
      viewModel: viewModel,
      localPosition: localPosition,
    );
  }

  void onRenderedViewMetricsChanged({
    required Size viewSize,
    required double timeViewStart,
    required double timeViewEnd,
    required double keyHeight,
    required double keyValueAtTop,
  }) {
    final didChange =
        data.viewSize != viewSize ||
        data.renderedTimeViewStart != timeViewStart ||
        data.renderedTimeViewEnd != timeViewEnd ||
        data.renderedKeyHeight != keyHeight ||
        data.renderedKeyValueAtTop != keyValueAtTop;
    if (!didChange) {
      return;
    }

    data.viewSize = viewSize;
    data.renderedTimeViewStart = timeViewStart;
    data.renderedTimeViewEnd = timeViewEnd;
    data.renderedKeyHeight = keyHeight;
    data.renderedKeyValueAtTop = keyValueAtTop;
    notifyDataUpdated();
  }

  PianoRollInteractionFamily? _classifyPointerDownInteraction({
    required int buttons,
    required bool ctrlPressed,
    required PianoRollPointerContext context,
  }) {
    if (project.sequence.activePatternID == null) {
      return null;
    }

    final isPrimaryClick = buttons & kPrimaryMouseButton == kPrimaryMouseButton;
    final isSecondaryClick =
        buttons & kSecondaryMouseButton == kSecondaryMouseButton;

    if (isPrimaryClick && viewModel.tool != EditorTool.eraser) {
      if (ctrlPressed || viewModel.tool == EditorTool.select) {
        return PianoRollInteractionFamily.selectionBox;
      }

      if (context.isOverResizeHandle && viewModel.tool == EditorTool.pencil) {
        return PianoRollInteractionFamily.resizeNotes;
      }

      if (context.realNoteUnderCursorId != null) {
        return PianoRollInteractionFamily.moveNotes;
      }

      return PianoRollInteractionFamily.createNote;
    }

    if (isSecondaryClick || viewModel.tool == EditorTool.eraser) {
      return PianoRollInteractionFamily.erase;
    }

    return null;
  }

  void onPointerDown(
    PointerDownEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    data.handlePointerDown(event, keyboardModifiers: keyboardModifiers);
    final family = _classifyPointerDownInteraction(
      buttons: event.buttons,
      ctrlPressed: data.isCtrlPressed,
      context: resolvePointerContextForPosition(event.localPosition),
    );
    if (family == null) {
      data.clearInteractionSession();
      return;
    }

    data.beginInteractionSession(family: family);
    emitSignal(const _PianoRollPointerDownSignal());
  }

  void onPointerMove(
    PointerMoveEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    data.handlePointerMove(event, keyboardModifiers: keyboardModifiers);
    if (!data.hasActiveInteractionSession) {
      return;
    }

    emitSignal(const _PianoRollPointerMoveSignal());
  }

  void onPointerUp(
    PointerEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    final hadActiveInteractionSession = data.hasActiveInteractionSession;
    data.handlePointerUp(event, keyboardModifiers: keyboardModifiers);
    if (!hadActiveInteractionSession) {
      return;
    }

    data.clearInteractionSession();
    emitSignal(const _PianoRollPointerUpSignal());
  }
}

/// Shared input and rendered-view state for the piano-roll interaction machine.
class PianoRollStateMachineData {
  bool isCtrlPressed = false;
  bool isAltPressed = false;
  bool isShiftPressed = false;

  Size viewSize = Size.zero;
  Map<int, PianoRollActivePointer> pointers = {};
  int? activePointerId;
  PianoRollActivePointer? activePointerDownPosition;

  double renderedTimeViewStart = 0;
  double renderedTimeViewEnd = 0;
  double renderedKeyHeight = 0;
  double renderedKeyValueAtTop = 0;

  PianoRollInteractionFamily? activeInteractionFamily;

  bool get hasActiveInteractionSession => activeInteractionFamily != null;

  PianoRollActivePointer? get activePointer {
    final pointerId = activePointerId;
    if (pointerId == null) {
      return null;
    }

    return pointers[pointerId];
  }

  void _syncKeyboardModifiers(KeyboardModifiers keyboardModifiers) {
    isCtrlPressed = keyboardModifiers.ctrl;
    isAltPressed = keyboardModifiers.alt;
    isShiftPressed = keyboardModifiers.shift;
  }

  void handlePointerDown(
    PointerDownEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    _syncKeyboardModifiers(keyboardModifiers);

    final position = event.localPosition;
    pointers[event.pointer] = PianoRollActivePointer(position.dx, position.dy);

    activePointerId = event.pointer;
    activePointerDownPosition = PianoRollActivePointer(
      position.dx,
      position.dy,
    );
  }

  void handlePointerMove(
    PointerMoveEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    _syncKeyboardModifiers(keyboardModifiers);

    final pointer = pointers[event.pointer];
    if (pointer == null) {
      return;
    }

    final position = event.localPosition;
    pointer.x = position.dx;
    pointer.y = position.dy;
  }

  void handlePointerUp(
    PointerEvent event, {
    required KeyboardModifiers keyboardModifiers,
  }) {
    _syncKeyboardModifiers(keyboardModifiers);

    final pointerId = event.pointer;
    pointers.remove(pointerId);

    if (activePointerId == pointerId) {
      activePointerId = null;
      activePointerDownPosition = null;
    }
  }

  void beginInteractionSession({required PianoRollInteractionFamily family}) {
    activeInteractionFamily = family;
  }

  void clearInteractionSession() {
    activeInteractionFamily = null;
  }

  PianoRollPointerContext resolvePointerContext({
    required PianoRollViewModel viewModel,
    required Offset localPosition,
  }) {
    final contentUnderCursor = viewModel.getContentUnderCursor(localPosition);
    final viewWidth = max(viewSize.width, 1.0);

    return PianoRollPointerContext(
      localPosition: localPosition,
      key: pixelsToKeyValue(
        keyHeight: renderedKeyHeight,
        keyValueAtTop: renderedKeyValueAtTop,
        pixelOffsetFromTop: localPosition.dy,
      ),
      offset: pixelsToTime(
        timeViewStart: renderedTimeViewStart,
        timeViewEnd: renderedTimeViewEnd,
        viewPixelWidth: viewWidth,
        pixelOffsetFromLeft: localPosition.dx,
      ),
      noteUnderCursor: contentUnderCursor.note?.metadata,
      resizeHandleUnderCursor: contentUnderCursor.resizeHandle?.metadata,
    );
  }
}

class PianoRollIdleState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;
  PatternModel? get activePatternOrNull => controller.activePatternOrNull;
  PatternModel get activePattern => controller.requireActivePattern();

  NoteModel requireActivePatternNote(Id noteId) {
    return activePattern.notes.firstWhere((note) => note.id == noteId);
  }
}

class PianoRollPointerSessionState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  @override
  PianoRollIdleState get parentState => super.parentState as PianoRollIdleState;

  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;
  PatternModel? get activePatternOrNull => parentState.activePatternOrNull;
  PatternModel get activePattern => parentState.activePattern;

  NoteModel requireActivePatternNote(Id noteId) {
    return parentState.requireActivePatternNote(noteId);
  }

  int? activePointerId;
  PianoRollActivePointer? dragStartPosition;
  PianoRollActivePointer? dragCurrentPosition;
  PianoRollPointerContext? dragStartContext;
  PianoRollPointerContext? dragCurrentContext;

  @visibleForTesting
  PianoRollPointerContext? get currentPointerContext => dragCurrentContext;

  @visibleForTesting
  PianoRollPointerContext? get startPointerContext => dragStartContext;

  Id? get dragStartRealNoteId => dragStartContext?.realNoteUnderCursorId;

  bool get dragStartIsResizeHandle =>
      dragStartContext?.isOverResizeHandle ?? false;

  double? get dragStartKey => dragStartContext?.key;
  double? get dragStartOffset => dragStartContext?.offset;
  double? get currentKey => dragCurrentContext?.key;
  double? get currentOffset => dragCurrentContext?.offset;

  void _syncPointerSessionContext() {
    final nextActivePointerId = interactionState.activePointerId;

    if (nextActivePointerId == null) {
      activePointerId = null;
      dragStartPosition = null;
      dragCurrentPosition = null;
      dragStartContext = null;
      dragCurrentContext = null;
      return;
    }

    if (activePointerId != nextActivePointerId) {
      activePointerId = nextActivePointerId;
      dragStartPosition = interactionState.activePointerDownPosition?.clone();
      final startPosition = dragStartPosition;
      dragStartContext = startPosition == null
          ? null
          : interactionState.resolvePointerContext(
              viewModel: viewModel,
              localPosition: startPosition.toOffset(),
            );
    }

    dragCurrentPosition = interactionState.activePointer?.clone();
    final currentPosition = dragCurrentPosition;
    dragCurrentContext = currentPosition == null
        ? null
        : interactionState.resolvePointerContext(
            viewModel: viewModel,
            localPosition: currentPosition.toOffset(),
          );
  }

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStateMachineData> from,
  }) {
    _syncPointerSessionContext();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    _syncPointerSessionContext();
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Enter pointer session',
      from: PianoRollIdleState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.hasActiveInteractionSession,
    ),
    .new(
      name: 'Exit pointer session',
      from: PianoRollPointerSessionState,
      to: PianoRollIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          !data.hasActiveInteractionSession,
    ),
  ];

  PianoRollPointerSessionState(super.parentState);
}

class PianoRollNoteInteractionState
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
  PatternModel? get activePatternOrNull => parentState.activePatternOrNull;
  PatternModel get activePattern => parentState.activePattern;

  PianoRollPointerContext? get dragStartContext => parentState.dragStartContext;
  PianoRollPointerContext? get dragCurrentContext =>
      parentState.dragCurrentContext;
  Id? get dragStartRealNoteId => parentState.dragStartRealNoteId;
  bool get dragStartIsResizeHandle => parentState.dragStartIsResizeHandle;
  double? get dragStartKey => parentState.dragStartKey;
  double? get dragStartOffset => parentState.dragStartOffset;
  double? get currentKey => parentState.currentKey;
  double? get currentOffset => parentState.currentOffset;

  NoteModel requireActivePatternNote(Id noteId) {
    return parentState.requireActivePatternNote(noteId);
  }

  int snapTimeInActivePattern({
    required int rawTime,
    bool ceil = false,
    bool round = false,
    int startTime = 0,
  }) {
    return controller.snapTimeInActivePattern(
      rawTime: rawTime,
      viewWidthInPixels: interactionState.viewSize.width,
      ceil: ceil,
      round: round,
      startTime: startTime,
    );
  }

  void setCursorNoteParameters(NoteModel note) {
    viewModel.cursorNoteLength = note.length;
    viewModel.cursorNoteVelocity = note.velocity;
    viewModel.cursorNotePan = note.pan;
  }

  PianoRollMoveNotesSessionData createMoveNotesSessionData({
    required double pointerOffset,
    required NoteModel noteUnderCursor,
    required Iterable<NoteModel> notesToMove,
    required bool isSelectionMove,
    required bool didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
  }) {
    final movingNotesById = <Id, NoteModel>{
      noteUnderCursor.id: noteUnderCursor,
    };
    for (final note in notesToMove) {
      movingNotesById[note.id] = note;
    }

    final movingNotes = movingNotesById.values.toList(growable: false);
    if (movingNotes.isEmpty) {
      throw StateError('Move session requires at least one note.');
    }

    final startTimes = <Id, Time>{};
    final startKeys = <Id, int>{};
    final lengths = <Id, Time>{};
    final velocities = <Id, double>{};
    final pans = <Id, double>{};
    var startOfFirstNote = maxSafeIntWeb;
    var keyOfTopNote = 0;
    var keyOfBottomNote = maxSafeIntWeb;

    for (final note in movingNotes) {
      startTimes[note.id] = note.offset;
      startKeys[note.id] = note.key;
      lengths[note.id] = note.length;
      velocities[note.id] = note.velocity;
      pans[note.id] = note.pan;
      startOfFirstNote = min(startOfFirstNote, note.offset);
      keyOfTopNote = max(keyOfTopNote, note.key);
      keyOfBottomNote = min(keyOfBottomNote, note.key);
    }

    return PianoRollMoveNotesSessionData(
      noteUnderCursor: noteUnderCursor,
      timeOffset: pointerOffset - noteUnderCursor.offset,
      noteOffset: 0.5,
      startTimes: startTimes,
      startKeys: startKeys,
      lengths: lengths,
      velocities: velocities,
      pans: pans,
      startOfFirstNote: startOfFirstNote,
      keyOfTopNote: keyOfTopNote,
      keyOfBottomNote: keyOfBottomNote,
      isSelectionMove: isSelectionMove,
      didDuplicateOnPointerDown: didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
      movingTransientNoteIds: movingTransientNoteIds,
    );
  }

  Map<Id, PianoRollMoveNotePreview> createInitialMoveNotesPreview(
    PianoRollMoveNotesSessionData sessionData,
  ) {
    return Map<Id, PianoRollMoveNotePreview>.fromEntries(
      sessionData.startTimes.keys.map((noteId) {
        return MapEntry(noteId, (
          key: sessionData.startKeys[noteId]!,
          offset: sessionData.startTimes[noteId]!,
        ));
      }),
    );
  }

  Map<Id, PianoRollMoveNotePreview> resolveMoveNotesSessionPreview({
    required double key,
    required double offset,
    required PianoRollMoveNotesSessionData sessionData,
  }) {
    final targetKey = key - sessionData.noteOffset;
    final targetOffset = offset - sessionData.timeOffset;
    var snappedOffset = targetOffset.floor();

    if (!interactionState.isAltPressed) {
      snappedOffset = snapTimeInActivePattern(
        rawTime: targetOffset.floor(),
        round: true,
        startTime: sessionData.startTimes[sessionData.noteUnderCursor.id]!,
      );
    }

    var timeOffsetFromEventStart =
        snappedOffset - sessionData.startTimes[sessionData.noteUnderCursor.id]!;
    var keyOffsetFromEventStart =
        targetKey.round() -
        sessionData.startKeys[sessionData.noteUnderCursor.id]!;

    if (sessionData.startOfFirstNote + timeOffsetFromEventStart < 0) {
      timeOffsetFromEventStart = -sessionData.startOfFirstNote;
    }

    if (sessionData.keyOfTopNote + keyOffsetFromEventStart > maxKeyValue) {
      keyOffsetFromEventStart = maxKeyValue.round() - sessionData.keyOfTopNote;
    }

    if (sessionData.keyOfBottomNote + keyOffsetFromEventStart < minKeyValue) {
      keyOffsetFromEventStart =
          minKeyValue.round() - sessionData.keyOfBottomNote;
    }

    return Map<Id, PianoRollMoveNotePreview>.fromEntries(
      sessionData.startTimes.keys.map((noteId) {
        return MapEntry(noteId, (
          key:
              sessionData.startKeys[noteId]! +
              (interactionState.isShiftPressed ? 0 : keyOffsetFromEventStart),
          offset:
              sessionData.startTimes[noteId]! +
              (!interactionState.isShiftPressed && interactionState.isCtrlPressed
                  ? 0
                  : timeOffsetFromEventStart),
        ));
      }),
    );
  }

  void syncLivePreviewForMoveSession({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    final notePreview = preview[sessionData.noteUnderCursor.id];
    if (notePreview == null) {
      return;
    }

    if (!controller.liveNotes.hasNoteForKey(notePreview.key)) {
      controller.liveNotes.removeAll();
      controller.liveNotes.addNote(
        key: notePreview.key,
        velocity: sessionData.noteUnderCursor.velocity,
        pan: sessionData.noteUnderCursor.pan,
      );
    }
  }

  MoveNotesCommand buildMoveNotesCommand({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    return MoveNotesCommand(
      patternID: activePattern.id,
      noteMoves: preview.entries
          .where(
            (entry) => !sessionData.movingTransientNoteIds.contains(entry.key),
          )
          .map((entry) {
            return (
              noteID: entry.key,
              oldOffset: sessionData.startTimes[entry.key]!,
              newOffset: entry.value.offset,
              oldKey: sessionData.startKeys[entry.key]!,
              newKey: entry.value.key,
            );
          })
          .toList(growable: false),
    );
  }

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Enter note interaction',
      from: PianoRollPointerSessionState,
      to: PianoRollNoteInteractionState,
      canTransition: ({required data, required event, required currentState}) =>
          _isPianoRollNoteInteractionFamily(data.activeInteractionFamily) &&
          event is EditorStateMachineSignalEvent &&
          event.signal is _PianoRollPointerDownSignal,
    ),
    .new(
      name: 'Exit note interaction',
      from: PianoRollNoteInteractionState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          !_isPianoRollNoteInteractionFamily(data.activeInteractionFamily),
    ),
  ];

  PianoRollNoteInteractionState(super.parentState);
}
