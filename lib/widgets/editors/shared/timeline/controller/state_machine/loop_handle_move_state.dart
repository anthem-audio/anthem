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

part of 'timeline_state_machine.dart';

class _TimelineLoopHandleMoveSessionData {
  final TimelineLoopHandle handle;
  final int originalHandleTime;

  const _TimelineLoopHandleMoveSessionData({
    required this.handle,
    required this.originalHandleTime,
  });
}

class TimelineLoopHandleMoveState extends TimelineMachineState {
  _TimelineLoopHandleMoveSessionData? _sessionData;

  @override
  TimelineLoopEditState get parentState =>
      super.parentState as TimelineLoopEditState;

  TimelineInteractionFamily? get interactionFamily =>
      parentState.interactionFamily;
  TimelineLoopHandle? get pressedLoopHandle => parentState.pressedLoopHandle;

  TimelineActivePointer? get dragStartPosition => parentState.dragStartPosition;
  TimelineActivePointer? get dragCurrentPosition =>
      parentState.dragCurrentPosition;

  TimelineLoopHandle? get activeHandle => _sessionData?.handle;
  int? get originalHandleTime => _sessionData?.originalHandleTime;

  void _initializeSession() {
    final pressedLoopHandle = this.pressedLoopHandle;
    final loopPoints = controller.loopPoints();
    if (pressedLoopHandle == null || loopPoints == null) {
      _sessionData = null;
      return;
    }

    final originalHandleTime = switch (pressedLoopHandle) {
      TimelineLoopHandle.start => loopPoints.start,
      TimelineLoopHandle.end => loopPoints.end,
    };

    _sessionData = _TimelineLoopHandleMoveSessionData(
      handle: pressedLoopHandle,
      originalHandleTime: originalHandleTime,
    );
  }

  void _applyLoopHandleMove() {
    final sessionData = _sessionData;
    final dragCurrentPosition = this.dragCurrentPosition;
    if (sessionData == null || dragCurrentPosition == null) {
      return;
    }

    controller.updateLoopHandleMoveFromPointerX(
      handle: sessionData.handle,
      originalHandleTime: sessionData.originalHandleTime,
      pointerX: dragCurrentPosition.x,
      ignoreSnap: interactionState.isAltPressed,
    );
  }

  void _clearSession() {
    _sessionData = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<TimelineStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate loop edit to timeline loop-handle move',
      from: TimelineLoopEditState,
      to: TimelineLoopHandleMoveState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelineLoopEditState).interactionFamily ==
          TimelineInteractionFamily.loopHandleMove,
    ),
    .new(
      name: 'Exit timeline loop-handle move',
      from: TimelineLoopHandleMoveState,
      to: TimelineLoopEditState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelineLoopHandleMoveState).interactionFamily !=
          TimelineInteractionFamily.loopHandleMove,
    ),
  ];

  TimelineLoopHandleMoveState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> from,
  }) {
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    _applyLoopHandleMove();
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> to,
  }) {
    _clearSession();
  }
}
