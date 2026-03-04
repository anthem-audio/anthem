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
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
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

/// The long-term interaction state machine for the piano roll.
///
/// This first scaffolding pass only establishes the state hierarchy and
/// controller ownership. All interaction behavior still lives on the legacy
/// controller path until routing is introduced.
class PianoRollStateMachine
    extends EditorStateMachine<PianoRollStateMachineData> {
  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final PianoRollController controller;
  int _pointerDownCount = 0;
  int _pointerMoveCount = 0;
  int _pointerUpCount = 0;

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
  int get pointerDownCount => _pointerDownCount;

  @visibleForTesting
  int get pointerMoveCount => _pointerMoveCount;

  @visibleForTesting
  int get pointerUpCount => _pointerUpCount;

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

  @visibleForTesting
  PianoRollInteractionFamily? classifyPointerDownForPosition({
    required Offset localPosition,
    required int buttons,
    required KeyboardModifiers keyboardModifiers,
  }) {
    return _classifyPointerDownInteraction(
      buttons: buttons,
      ctrlPressed: keyboardModifiers.ctrl,
      context: resolvePointerContextForPosition(localPosition),
    );
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
    _pointerDownCount++;
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

    _pointerMoveCount++;
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

    _pointerUpCount++;
    data.clearInteractionSession();
    emitSignal(const _PianoRollPointerUpSignal());
  }
}

/// Shared interaction data for the future piano-roll state machine.
///
/// This starts intentionally minimal. Later steps will move pointer and view
/// transform ownership here as gesture routing shifts from the legacy path to
/// the machine.
class PianoRollStateMachineData {
  bool isCtrlPressed = false;
  bool isAltPressed = false;
  bool isShiftPressed = false;

  Size viewSize = Size.zero;
  Map<int, PianoRollActivePointer> pointers = {};
  int? activePointerId;
  PianoRollActivePointer? activePointerDownPosition;
  Offset? lastPointerUpPosition;

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
    lastPointerUpPosition = null;
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

    lastPointerUpPosition = event.localPosition;
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

  int? activePointerId;
  PianoRollActivePointer? dragStartPosition;
  PianoRollActivePointer? dragCurrentPosition;
  PianoRollPointerContext? dragStartContext;
  PianoRollPointerContext? dragCurrentContext;
  PianoRollPointerContext? lastPointerUpContext;
  PianoRollInteractionFamily? latchedInteractionFamily;

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

      final lastPointerUpPosition = interactionState.lastPointerUpPosition;
      lastPointerUpContext = lastPointerUpPosition == null
          ? null
          : interactionState.resolvePointerContext(
              viewModel: viewModel,
              localPosition: lastPointerUpPosition,
            );
      latchedInteractionFamily = interactionState.activeInteractionFamily;
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
    latchedInteractionFamily = interactionState.activeInteractionFamily;
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

  PianoRollPointerContext? get dragStartContext => parentState.dragStartContext;
  PianoRollPointerContext? get dragCurrentContext =>
      parentState.dragCurrentContext;
  Id? get dragStartRealNoteId => parentState.dragStartRealNoteId;
  bool get dragStartIsResizeHandle => parentState.dragStartIsResizeHandle;
  double? get dragStartKey => parentState.dragStartKey;
  double? get dragStartOffset => parentState.dragStartOffset;
  double? get currentKey => parentState.currentKey;
  double? get currentOffset => parentState.currentOffset;

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
