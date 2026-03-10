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
import 'package:anthem/widgets/editors/shared/timeline/timeline_constants.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_controller.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_interaction_target.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

part 'loop_create_state.dart';
part 'loop_edit_state.dart';
part 'loop_handle_move_state.dart';
part 'playhead_drag_state.dart';

enum TimelineInteractionFamily { playheadDrag, loopCreate, loopHandleMove }

enum TimelineLoopHandle { start, end }

bool isTimelineLoopInteractionFamily(TimelineInteractionFamily? family) {
  return family == TimelineInteractionFamily.loopCreate ||
      family == TimelineInteractionFamily.loopHandleMove;
}

class TimelineActivePointer {
  double x;
  double y;
  final TimelineLoopHandle? pressedLoopHandle;

  TimelineActivePointer(this.x, this.y, {this.pressedLoopHandle});

  TimelineActivePointer clone() =>
      TimelineActivePointer(x, y, pressedLoopHandle: pressedLoopHandle);

  Offset toOffset() => Offset(x, y);
}

/// The shared timeline interaction state machine.
class TimelineStateMachine
    extends EditorStateMachine<TimelineStateMachineData> {
  final ProjectModel project;
  final TimelineController controller;
  final TimelineInteractionTarget? interactionTarget;

  TimelineInteractionFamily? _classifyPointerDownInteraction(
    PointerDownEvent event,
  ) {
    final inLoopBar = event.localPosition.dy <= loopAreaHeight;
    final isPrimaryPress = event.buttons & kPrimaryButton != 0;
    final isSecondaryPress = event.buttons & kSecondaryButton != 0;
    final pressedLoopHandle = data.activePressedLoopHandle;
    final isDoubleClick = data.activePointerIsDoubleClick;

    if (isPrimaryPress && !inLoopBar) {
      return TimelineInteractionFamily.playheadDrag;
    }

    if (isPrimaryPress && !isDoubleClick && pressedLoopHandle != null) {
      return TimelineInteractionFamily.loopHandleMove;
    }

    final isLoopCreate =
        inLoopBar &&
        (isDoubleClick ||
            isSecondaryPress ||
            (isPrimaryPress && data.isCtrlPressed));
    if (isLoopCreate) {
      return TimelineInteractionFamily.loopCreate;
    }

    return null;
  }

  void onPointerDown(
    PointerDownEvent event, {
    TimelineLoopHandle? pressedLoopHandle,
  }) {
    if (interactionTarget == null) {
      return;
    }

    if (data.hasActivePointerSession) {
      return;
    }

    data.handlePointerDown(event, pressedLoopHandle: pressedLoopHandle);

    final interactionFamily = _classifyPointerDownInteraction(event);
    if (interactionFamily != null) {
      data.beginInteractionSession(family: interactionFamily);
    }

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
  DateTime? lastPointerDownTimestamp;
  bool activePointerIsDoubleClick = false;

  Size viewSize = Size.zero;
  Map<int, TimelineActivePointer> pointers = {};
  int? activePointerId;
  int? activePointerButtons;
  TimelineActivePointer? activePointerDownPosition;

  double renderedTimeViewStart = 0;
  double renderedTimeViewEnd = 0;

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

  TimelineLoopHandle? get activePressedLoopHandle =>
      activePointerDownPosition?.pressedLoopHandle;

  void handlePointerDown(
    PointerDownEvent event, {
    TimelineLoopHandle? pressedLoopHandle,
  }) {
    final timestamp = DateTime.now();
    activePointerIsDoubleClick =
        lastPointerDownTimestamp != null &&
        timestamp.difference(lastPointerDownTimestamp!) <
            timelineDoubleClickThreshold &&
        event.buttons & kPrimaryButton != 0;
    lastPointerDownTimestamp = timestamp;

    final position = event.localPosition;
    pointers[event.pointer] = TimelineActivePointer(
      position.dx,
      position.dy,
      pressedLoopHandle: pressedLoopHandle,
    );
    activePointerId = event.pointer;
    activePointerButtons = event.buttons;
    activePointerDownPosition = TimelineActivePointer(
      position.dx,
      position.dy,
      pressedLoopHandle: pressedLoopHandle,
    );
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

    if (activePointerId == pointerId) {
      activePointerId = null;
      activePointerButtons = null;
      activePointerDownPosition = null;
      activePointerIsDoubleClick = false;
    }
  }

  void beginInteractionSession({required TimelineInteractionFamily family}) {
    activeInteractionFamily = family;
  }

  void clearInteractionSession() {
    activeInteractionFamily = null;
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

class TimelineIdleState extends TimelineMachineState {}

class TimelinePointerSessionState extends TimelineMachineState {
  @override
  TimelineIdleState get parentState => super.parentState as TimelineIdleState;

  int? get activePointerId => interactionState.activePointerId;
  int? get activeButtons => interactionState.activePointerButtons;
  TimelineActivePointer? get dragStartPosition =>
      interactionState.activePointerDownPosition?.clone();
  TimelineActivePointer? get dragCurrentPosition =>
      interactionState.activePointer?.clone();
  TimelineInteractionFamily? get interactionFamily =>
      interactionState.activeInteractionFamily;
  TimelineLoopHandle? get pressedLoopHandle =>
      interactionState.activePressedLoopHandle;

  bool get isDoubleClickQualified =>
      interactionState.activePointerIsDoubleClick;

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> from,
  }) {
    controller.activateTransportSequence();
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
