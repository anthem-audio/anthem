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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_controller.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_interaction_target.dart';
import 'package:flutter/widgets.dart';

part 'loop_create_state.dart';
part 'loop_edit_state.dart';
part 'loop_handle_move_state.dart';
part 'playhead_drag_state.dart';

enum TimelineModifierKey { ctrl, alt, shift }

enum TimelineInteractionFamily { playheadDrag, loopCreate, loopHandleMove }

enum TimelineLoopHandle { start, end }

bool isTimelineLoopInteractionFamily(TimelineInteractionFamily? family) {
  return family == TimelineInteractionFamily.loopCreate ||
      family == TimelineInteractionFamily.loopHandleMove;
}

class TimelineActivePointer {
  double x;
  double y;

  TimelineActivePointer(this.x, this.y);

  TimelineActivePointer clone() => TimelineActivePointer(x, y);

  Offset toOffset() => Offset(x, y);
}

class TimelinePendingLoopHandlePress {
  final int pointerId;
  final TimelineLoopHandle handle;

  const TimelinePendingLoopHandlePress({
    required this.pointerId,
    required this.handle,
  });
}

/// The shared timeline interaction state machine.
///
/// This scaffold establishes the target hierarchy and controller ownership
/// without taking over live gesture handling from `timeline.dart` yet.
class TimelineStateMachine
    extends EditorStateMachine<TimelineStateMachineData> {
  final ProjectModel project;
  final TimelineController controller;
  final TimelineInteractionTarget? interactionTarget;

  void onPointerDown(PointerDownEvent event) {
    data.handlePointerDown(event);
    notifyDataUpdated();
  }

  void onPointerMove(PointerMoveEvent event) {
    data.handlePointerMove(event);
    notifyDataUpdated();
  }

  void onPointerUp(PointerEvent event) {
    final activePointerId = data.activePointerId;
    data.handlePointerUp(event);
    if (activePointerId == event.pointer) {
      data.clearInteractionSession();
    }
    notifyDataUpdated();
  }

  void onPointerCancel(PointerCancelEvent event) {
    onPointerUp(event);
  }

  void onViewSizeChanged(Size viewSize) {
    if (data.viewSize == viewSize) {
      return;
    }

    data.viewSize = viewSize;
    notifyDataUpdated();
  }

  void onRenderedTimeViewChanged({
    required double timeViewStart,
    required double timeViewEnd,
  }) {
    if (data.renderedTimeViewStart == timeViewStart &&
        data.renderedTimeViewEnd == timeViewEnd) {
      return;
    }

    data.renderedTimeViewStart = timeViewStart;
    data.renderedTimeViewEnd = timeViewEnd;
    notifyDataUpdated();
  }

  void syncModifierState({
    required bool ctrlPressed,
    required bool altPressed,
    required bool shiftPressed,
  }) {
    var didChange = false;

    if (data.isCtrlPressed != ctrlPressed) {
      data.isCtrlPressed = ctrlPressed;
      didChange = true;
    }
    if (data.isAltPressed != altPressed) {
      data.isAltPressed = altPressed;
      didChange = true;
    }
    if (data.isShiftPressed != shiftPressed) {
      data.isShiftPressed = shiftPressed;
      didChange = true;
    }

    if (!didChange) {
      return;
    }

    notifyDataUpdated();
  }

  void registerPendingLoopHandlePress({
    required int pointerId,
    required TimelineLoopHandle handle,
  }) {
    final pendingLoopHandlePress = data.pendingLoopHandlePress;
    if (pendingLoopHandlePress?.pointerId == pointerId &&
        pendingLoopHandlePress?.handle == handle) {
      return;
    }

    data.setPendingLoopHandlePress(pointerId: pointerId, handle: handle);
    notifyDataUpdated();
  }

  TimelineStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.controller,
    required this.interactionTarget,
  });

  factory TimelineStateMachine.create({
    required ProjectModel project,
    required TimelineController controller,
  }) {
    final data = TimelineStateMachineData();
    final idleState = TimelineIdleState();
    final pointerSessionState = TimelinePointerSessionState(idleState);
    final playheadDragState = TimelinePlayheadDragState(pointerSessionState);
    final loopEditState = TimelineLoopEditState(pointerSessionState);
    final loopCreateState = TimelineLoopCreateState(loopEditState);
    final loopHandleMoveState = TimelineLoopHandleMoveState(loopEditState);
    final states = <EditorStateMachineState<TimelineStateMachineData>>[
      idleState,
      pointerSessionState,
      playheadDragState,
      loopEditState,
      loopCreateState,
      loopHandleMoveState,
    ];

    return TimelineStateMachine._(
      data: data,
      idleState: idleState,
      states: states,
      project: project,
      controller: controller,
      interactionTarget: controller.interactionTarget,
    );
  }
}

/// Shared rendered-view and pointer data for the timeline interaction machine.
class TimelineStateMachineData {
  bool isCtrlPressed = false;
  bool isAltPressed = false;
  bool isShiftPressed = false;

  Size viewSize = Size.zero;
  Map<int, TimelineActivePointer> pointers = {};
  int? activePointerId;
  int? activePointerButtons;
  TimelineActivePointer? activePointerDownPosition;

  double renderedTimeViewStart = 0;
  double renderedTimeViewEnd = 0;

  TimelinePendingLoopHandlePress? pendingLoopHandlePress;
  TimelineInteractionFamily? activeInteractionFamily;

  bool get hasActivePointerSession => activePointerId != null;

  bool get hasActiveInteractionSession =>
      hasActivePointerSession && activeInteractionFamily != null;

  TimelineActivePointer? get activePointer {
    final pointerId = activePointerId;
    if (pointerId == null) {
      return null;
    }

    return pointers[pointerId];
  }

  bool isModifierPressed(TimelineModifierKey modifier) {
    return switch (modifier) {
      TimelineModifierKey.ctrl => isCtrlPressed,
      TimelineModifierKey.alt => isAltPressed,
      TimelineModifierKey.shift => isShiftPressed,
    };
  }

  void setModifier(TimelineModifierKey modifier, bool isPressed) {
    switch (modifier) {
      case TimelineModifierKey.ctrl:
        isCtrlPressed = isPressed;
      case TimelineModifierKey.alt:
        isAltPressed = isPressed;
      case TimelineModifierKey.shift:
        isShiftPressed = isPressed;
    }
  }

  void handlePointerDown(PointerDownEvent event) {
    final position = event.localPosition;
    pointers[event.pointer] = TimelineActivePointer(position.dx, position.dy);
    activePointerId = event.pointer;
    activePointerButtons = event.buttons;
    activePointerDownPosition = TimelineActivePointer(position.dx, position.dy);
  }

  void handlePointerMove(PointerMoveEvent event) {
    final pointer = pointers[event.pointer];
    if (pointer == null) {
      return;
    }

    final position = event.localPosition;
    pointer.x = position.dx;
    pointer.y = position.dy;
    if (activePointerId == event.pointer) {
      activePointerButtons = event.buttons;
    }
  }

  void handlePointerUp(PointerEvent event) {
    final pointerId = event.pointer;
    pointers.remove(pointerId);

    final pendingLoopHandlePress = this.pendingLoopHandlePress;
    if (pendingLoopHandlePress?.pointerId == pointerId) {
      clearPendingLoopHandlePress();
    }

    if (activePointerId == pointerId) {
      activePointerId = null;
      activePointerButtons = null;
      activePointerDownPosition = null;
    }
  }

  void beginInteractionSession({required TimelineInteractionFamily family}) {
    activeInteractionFamily = family;
  }

  void clearInteractionSession() {
    activeInteractionFamily = null;
  }

  void setPendingLoopHandlePress({
    required int pointerId,
    required TimelineLoopHandle handle,
  }) {
    pendingLoopHandlePress = TimelinePendingLoopHandlePress(
      pointerId: pointerId,
      handle: handle,
    );
  }

  void clearPendingLoopHandlePress() {
    pendingLoopHandlePress = null;
  }
}

abstract class TimelineMachineState
    extends EditorStateMachineState<TimelineStateMachineData> {
  TimelineStateMachine get timelineStateMachine =>
      stateMachine as TimelineStateMachine;

  TimelineStateMachineData get interactionState => timelineStateMachine.data;

  ProjectModel get project => timelineStateMachine.project;
  TimelineController get controller => timelineStateMachine.controller;
  TimelineInteractionTarget? get interactionTarget =>
      timelineStateMachine.interactionTarget;

  TimelineMachineState([super.parentState]);
}

class TimelineIdleState extends TimelineMachineState {
  static const Duration doubleClickThreshold = Duration(milliseconds: 500);

  DateTime? lastPointerDownTimestamp;
  bool pendingDoubleClickQualification = false;
}

class TimelinePointerSessionState extends TimelineMachineState {
  @override
  TimelineIdleState get parentState => super.parentState as TimelineIdleState;

  int? activePointerId;
  int? activeButtons;
  TimelineActivePointer? dragStartPosition;
  TimelineActivePointer? dragCurrentPosition;
  TimelineInteractionFamily? interactionFamily;
  TimelineLoopHandle? pressedLoopHandle;
  bool isDoubleClickQualified = false;

  void _syncPointerSessionData() {
    final nextActivePointerId = interactionState.activePointerId;

    if (nextActivePointerId == null) {
      activePointerId = null;
      activeButtons = null;
      dragStartPosition = null;
      dragCurrentPosition = null;
      interactionFamily = null;
      pressedLoopHandle = null;
      isDoubleClickQualified = false;
      return;
    }

    if (activePointerId != nextActivePointerId) {
      activePointerId = nextActivePointerId;
      activeButtons = interactionState.activePointerButtons;
      dragStartPosition = interactionState.activePointerDownPosition?.clone();
      dragCurrentPosition = interactionState.activePointer?.clone();
      interactionFamily = interactionState.activeInteractionFamily;

      final pendingLoopHandlePress = interactionState.pendingLoopHandlePress;
      pressedLoopHandle =
          pendingLoopHandlePress != null &&
              pendingLoopHandlePress.pointerId == nextActivePointerId
          ? pendingLoopHandlePress.handle
          : null;
      isDoubleClickQualified = parentState.pendingDoubleClickQualification;
      return;
    }

    activeButtons = interactionState.activePointerButtons;
    dragCurrentPosition = interactionState.activePointer?.clone();
    interactionFamily = interactionState.activeInteractionFamily;

    final pendingLoopHandlePress = interactionState.pendingLoopHandlePress;
    pressedLoopHandle =
        pendingLoopHandlePress != null &&
            pendingLoopHandlePress.pointerId == nextActivePointerId
        ? pendingLoopHandlePress.handle
        : null;
  }

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> from,
  }) {
    _syncPointerSessionData();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    _syncPointerSessionData();
  }

  @override
  Iterable<EditorStateMachineStateTransition<TimelineStateMachineData>>
  get transitions => [
    .new(
      name: 'Enter timeline pointer session',
      from: TimelineIdleState,
      to: TimelinePointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.hasActivePointerSession,
    ),
    .new(
      name: 'Exit timeline pointer session',
      from: TimelinePointerSessionState,
      to: TimelineIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          !data.hasActivePointerSession,
    ),
  ];

  TimelinePointerSessionState(super.parentState);
}
