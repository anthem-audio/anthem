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

class TimelinePlayheadDragState extends TimelineMachineState {
  @override
  TimelinePointerSessionState get parentState =>
      super.parentState as TimelinePointerSessionState;

  TimelineInteractionFamily? get interactionFamily =>
      parentState.interactionFamily;

  TimelineActivePointer? get dragStartPosition => parentState.dragStartPosition;
  TimelineActivePointer? get dragCurrentPosition =>
      parentState.dragCurrentPosition;

  @override
  Iterable<EditorStateMachineStateTransition<TimelineStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate pointer session to timeline playhead drag',
      from: TimelinePointerSessionState,
      to: TimelinePlayheadDragState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelinePointerSessionState).interactionFamily ==
          TimelineInteractionFamily.playheadDrag,
    ),
    .new(
      name: 'Exit timeline playhead drag',
      from: TimelinePlayheadDragState,
      to: TimelinePointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as TimelinePlayheadDragState).interactionFamily !=
          TimelineInteractionFamily.playheadDrag,
    ),
  ];

  TimelinePlayheadDragState(super.parentState);
}
