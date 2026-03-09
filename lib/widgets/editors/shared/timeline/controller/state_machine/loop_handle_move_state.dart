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

class TimelineLoopHandleMoveState extends TimelineMachineState {
  @override
  TimelineLoopEditState get parentState =>
      super.parentState as TimelineLoopEditState;

  TimelineInteractionFamily? get interactionFamily =>
      parentState.interactionFamily;
  TimelineLoopHandle? get pressedLoopHandle => parentState.pressedLoopHandle;

  TimelineActivePointer? get dragStartPosition => parentState.dragStartPosition;
  TimelineActivePointer? get dragCurrentPosition =>
      parentState.dragCurrentPosition;

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
}
