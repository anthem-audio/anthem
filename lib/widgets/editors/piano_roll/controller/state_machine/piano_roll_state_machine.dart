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
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'create_note_state.dart';
part 'erase_notes_state.dart';
part 'move_notes_state.dart';
part 'resize_notes_state.dart';
part 'selection_box_state.dart';

sealed class _PianoRollAdaptedPointerSignal {
  const _PianoRollAdaptedPointerSignal();
}

class _PianoRollAdaptedPointerDownSignal
    extends _PianoRollAdaptedPointerSignal {
  final PianoRollInteractionFamily family;
  final PianoRollPointerDownEvent event;

  const _PianoRollAdaptedPointerDownSignal({
    required this.family,
    required this.event,
  });
}

class _PianoRollAdaptedPointerMoveSignal
    extends _PianoRollAdaptedPointerSignal {
  final PianoRollPointerMoveEvent event;

  const _PianoRollAdaptedPointerMoveSignal(this.event);
}

class _PianoRollAdaptedPointerUpSignal extends _PianoRollAdaptedPointerSignal {
  final PianoRollPointerUpEvent event;

  const _PianoRollAdaptedPointerUpSignal(this.event);
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
  int _adaptedPointerDownCount = 0;
  int _adaptedPointerMoveCount = 0;
  int _adaptedPointerUpCount = 0;

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
  int get adaptedPointerDownCount => _adaptedPointerDownCount;

  @visibleForTesting
  int get adaptedPointerMoveCount => _adaptedPointerMoveCount;

  @visibleForTesting
  int get adaptedPointerUpCount => _adaptedPointerUpCount;

  @visibleForTesting
  PianoRollPointerContext? resolvePointerContextForEvent(
    PianoRollPointerEvent event,
  ) {
    return data.resolvePointerContext(
      viewModel: viewModel,
      localPosition: event.pointerEvent.localPosition,
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

  void onAdaptedPointerDown(PianoRollPointerDownEvent event) {
    _adaptedPointerDownCount++;
    data.handlePointerDown(event);
    final context = resolvePointerContextForEvent(event);
    final family = controller.classifyPointerDownInteraction(
      buttons: event.pointerEvent.buttons,
      ctrlPressed: data.isCtrlPressed,
      isResizeHandle: context?.isOverResizeHandle ?? false,
      realNoteUnderCursorId: context?.realNoteUnderCursorId,
    );
    if (family == null) {
      data.clearInteractionSession();
      return;
    }

    data.beginInteractionSession(family: family);
    emitSignal(
      _PianoRollAdaptedPointerDownSignal(family: family, event: event),
    );
  }

  void onAdaptedPointerMove(PianoRollPointerMoveEvent event) {
    data.handlePointerMove(event);
    if (!data.hasActiveInteractionSession) {
      return;
    }

    _adaptedPointerMoveCount++;
    emitSignal(_PianoRollAdaptedPointerMoveSignal(event));
  }

  void onAdaptedPointerUp(PianoRollPointerUpEvent event) {
    final hadActiveInteractionSession = data.hasActiveInteractionSession;
    data.handlePointerUp(event);
    if (!hadActiveInteractionSession) {
      return;
    }

    _adaptedPointerUpCount++;
    data.clearInteractionSession();
    emitSignal(_PianoRollAdaptedPointerUpSignal(event));
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

  void handlePointerDown(PianoRollPointerDownEvent event) {
    _syncKeyboardModifiers(event.keyboardModifiers);

    final position = event.pointerEvent.localPosition;
    pointers[event.pointerEvent.pointer] = PianoRollActivePointer(
      position.dx,
      position.dy,
    );

    if (event.pointerEvent is PointerDownEvent) {
      activePointerId = event.pointerEvent.pointer;
      activePointerDownPosition = PianoRollActivePointer(
        position.dx,
        position.dy,
      );
      lastPointerUpPosition = null;
    }
  }

  void handlePointerMove(PianoRollPointerMoveEvent event) {
    _syncKeyboardModifiers(event.keyboardModifiers);

    final pointer = pointers[event.pointerEvent.pointer];
    if (pointer == null) {
      return;
    }

    final position = event.pointerEvent.localPosition;
    pointer.x = position.dx;
    pointer.y = position.dy;
  }

  void handlePointerUp(PianoRollPointerUpEvent event) {
    _syncKeyboardModifiers(event.keyboardModifiers);

    lastPointerUpPosition = event.pointerEvent.localPosition;
    final pointerId = event.pointerEvent.pointer;
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
      name: 'Enter adapted pointer session',
      from: PianoRollIdleState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.hasActiveInteractionSession,
    ),
    .new(
      name: 'Exit adapted pointer session',
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
          event.signal is _PianoRollAdaptedPointerSignal,
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
