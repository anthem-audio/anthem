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

class _TimelineLoopCreateSessionData {
  final int startTime;

  const _TimelineLoopCreateSessionData({required this.startTime});
}

class TimelineLoopCreateState extends TimelineMachineState {
  _TimelineLoopCreateSessionData? _sessionData;

  @override
  TimelineLoopEditState get parentState =>
      super.parentState as TimelineLoopEditState;

  TimelineInteractionFamily? get interactionFamily =>
      parentState.interactionFamily;

  TimelineActivePointer? get dragStartPosition => parentState.dragStartPosition;
  TimelineActivePointer? get dragCurrentPosition =>
      parentState.dragCurrentPosition;

  int? get startTime => _sessionData?.startTime;

  void _initializeSession() {
    final dragStartPosition = this.dragStartPosition;
    if (dragStartPosition == null) {
      _sessionData = null;
      return;
    }

    final startTime = controller.resolveTimelineTimeFromPointerX(
      pointerX: dragStartPosition.x,
      ignoreSnap: interactionState.isAltPressed,
      round: true,
    );
    if (startTime == null) {
      _sessionData = null;
      return;
    }

    if (!interactionState.isAltPressed) {
      controller.clearLoopPoints();
    }

    _sessionData = _TimelineLoopCreateSessionData(startTime: startTime);
  }

  void _applyLoopPreview() {
    final sessionData = _sessionData;
    final dragCurrentPosition = this.dragCurrentPosition;
    if (sessionData == null || dragCurrentPosition == null) {
      return;
    }

    controller.updateLoopCreateFromPointerX(
      startTime: sessionData.startTime,
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
      name: 'Delegate loop edit to timeline loop create',
      from: TimelineLoopEditState,
      to: TimelineLoopCreateState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelineLoopEditState).interactionFamily ==
          TimelineInteractionFamily.loopCreate,
    ),
    .new(
      name: 'Exit timeline loop create',
      from: TimelineLoopCreateState,
      to: TimelineLoopEditState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelineLoopCreateState).interactionFamily !=
          TimelineInteractionFamily.loopCreate,
    ),
  ];

  TimelineLoopCreateState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> from,
  }) {
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    _applyLoopPreview();
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<TimelineStateMachineData> to,
  }) {
    _clearSession();
  }
}
