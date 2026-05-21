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

part of 'arranger_state_machine.dart';

class _AutomationPointMoveTarget {
  final AutomationPointModel point;
  final Id patternId;
  final Rect contentRect;
  final int pointIndex;
  final int startOffset;
  final double startValue;
  final bool isInsertedPoint;

  /// Canvas-space origin for drag deltas. For inserted points, this is the
  /// created point center; existing-point drags can use the pointer-down
  /// position to preserve the user's grab offset.
  final Offset dragStartAnchor;
  final List<({int index, int startTime})> pointsToMoveInTime;

  const _AutomationPointMoveTarget({
    required this.point,
    required this.patternId,
    required this.contentRect,
    required this.pointIndex,
    required this.startOffset,
    required this.startValue,
    required this.isInsertedPoint,
    required this.dragStartAnchor,
    required this.pointsToMoveInTime,
  });
}

class ArrangerAutomationPointMoveState extends _ArrangerLeafState {
  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  /// The idle ancestor owns primary click tracking. Automation point move
  /// consumes a double-click-and-hold before idle sees the matching pointer up.
  ArrangerIdleState get _idleState => parentState.parentState;

  _AutomationPointMoveTarget? _target;

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to automation point move',
      from: ArrangerDragState,
      to: ArrangerAutomationPointMoveState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).interactionFamily ==
          ArrangerInteractionFamily.automationPointMove,
    ),
    .new(
      name: 'Automation point move invalid target fallback',
      from: ArrangerAutomationPointMoveState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerAutomationPointMoveState)._target == null,
    ),
    .new(
      name: 'Cancel automation point move',
      from: ArrangerAutomationPointMoveState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Automation point move fallback to drag',
      from: ArrangerAutomationPointMoveState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerAutomationPointMoveState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerAutomationPointMoveState(ArrangerDragState super.parentState);

  @override
  void onEntry({required event, required from}) {
    _consumeIdleClickHandling();
    _initializeMoveSession();
    _syncPointPosition();
  }

  @override
  void onActive({required event}) {
    _syncPointPosition();
  }

  @override
  void onExit({required event, required to}) {
    if (_shouldCommit(event)) {
      _commitMoveSession();
    } else {
      _rollbackMoveSession();
    }

    _idleState.doubleClickPressed = false;
    _target = null;
  }

  void _consumeIdleClickHandling() {
    _idleState._clearPrimaryClickTracking();
  }

  void _initializeMoveSession() {
    _target = null;

    final dragStartContext = parentState.dragStartContext;
    final targetClipId = dragStartContext?.automationClipContentClipId;
    final contentRect = dragStartContext?.automationClipContentRect;
    final startPointer = parentState.dragStartPosition;
    if (targetClipId == null || contentRect == null || startPointer == null) {
      return;
    }

    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }

    final clip = arrangementData.clips[targetClipId];
    if (clip == null) {
      return;
    }

    final track = project.tracks[clip.trackId];
    if (track?.isAutomationLane != true) {
      return;
    }

    final pattern = project.sequence.patterns[clip.patternId];
    if (pattern == null) {
      return;
    }

    final clipTimeViewStart = clip.timeView?.start ?? 0;
    final clipTimeViewEnd = clip.timeView?.end ?? clip.width;
    if (clipTimeViewEnd <= clipTimeViewStart) {
      return;
    }

    if (contentRect.isEmpty) {
      return;
    }

    final automationHandle = dragStartContext?.automationHandle;
    if (automationHandle?.kind == AutomationHandleKind.point) {
      _initializeExistingPointMoveSession(
        pattern: pattern,
        automationHandle: automationHandle!,
        contentRect: contentRect,
        startPointer: startPointer,
      );
      return;
    }

    if (!_idleState.doubleClickPressed) {
      return;
    }

    final startOffset = _pointOffsetForPointerX(
      pointerX: startPointer.x,
      clip: clip,
      clipTimeViewStart: clipTimeViewStart,
      clipTimeViewEnd: clipTimeViewEnd,
    );
    final startValue = _pointValueForPointerY(
      pointerY: startPointer.y,
      contentRect: contentRect,
    );
    final dragStartAnchor = _pointCenterForAutomationPoint(
      clip: clip,
      clipTimeViewStart: clipTimeViewStart,
      contentRect: contentRect,
      pointOffset: startOffset,
      pointValue: startValue,
    );
    final pointIndex = _findIndexForNewAutomationPoint(
      pattern.automation.points.nonObservableInner,
      startOffset,
    );
    final point = AutomationPointModel(
      idAllocator: ServiceRegistry.forProject(project.id).idAllocator,
      offset: startOffset,
      value: startValue,
    );

    pattern.automation.points.insert(pointIndex, point);

    _target = _AutomationPointMoveTarget(
      point: point,
      patternId: pattern.id,
      contentRect: contentRect,
      pointIndex: pointIndex,
      startOffset: startOffset,
      startValue: startValue,
      isInsertedPoint: true,
      dragStartAnchor: dragStartAnchor,
      pointsToMoveInTime: List.generate(
        pattern.automation.points.length - pointIndex,
        (index) {
          final pointToMove = pattern.automation.points[pointIndex + index];
          return (index: pointIndex + index, startTime: pointToMove.offset);
        },
      ),
    );
  }

  void _initializeExistingPointMoveSession({
    required PatternModel pattern,
    required AutomationHandleAnnotation automationHandle,
    required Rect contentRect,
    required ActivePointer startPointer,
  }) {
    final points = pattern.automation.points;
    var pointIndex = automationHandle.pointIndex;
    if (pointIndex < 0 ||
        pointIndex >= points.length ||
        points[pointIndex].id != automationHandle.pointId) {
      pointIndex = points.indexWhere(
        (point) => point.id == automationHandle.pointId,
      );
      if (pointIndex == -1) {
        return;
      }
    }

    final point = points[pointIndex];
    _target = _AutomationPointMoveTarget(
      point: point,
      patternId: pattern.id,
      contentRect: contentRect,
      pointIndex: pointIndex,
      startOffset: point.offset,
      startValue: point.value,
      isInsertedPoint: false,
      dragStartAnchor: Offset(startPointer.x, startPointer.y),
      pointsToMoveInTime: List.generate(points.length - pointIndex, (index) {
        final pointToMove = points[pointIndex + index];
        return (index: pointIndex + index, startTime: pointToMove.offset);
      }),
    );
  }

  Offset _pointCenterForAutomationPoint({
    required ClipModel clip,
    required int clipTimeViewStart,
    required Rect contentRect,
    required int pointOffset,
    required double pointValue,
  }) {
    return Offset(
      timeToPixels(
        time: (clip.offset + pointOffset - clipTimeViewStart).toDouble(),
        timeViewStart: interactionState.renderedTimeViewStart,
        timeViewEnd: interactionState.renderedTimeViewEnd,
        viewPixelWidth: interactionState.viewSize.width,
      ),
      contentRect.top + (1 - pointValue) * contentRect.height,
    );
  }

  int _pointOffsetForPointerX({
    required double pointerX,
    required ClipModel clip,
    required int clipTimeViewStart,
    required int clipTimeViewEnd,
  }) {
    final rawArrangementTime = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: pointerX,
    );
    final arrangementTime = interactionState.isAltPressed
        ? rawArrangementTime.round()
        : getSnappedTime(
            rawTime: rawArrangementTime.round(),
            divisionChanges: arrangerStateMachine.divisionChanges(),
            round: true,
          );
    final pointOffset = arrangementTime - clip.offset + clipTimeViewStart;

    return pointOffset.clamp(clipTimeViewStart, clipTimeViewEnd).toInt();
  }

  double _pointValueForPointerY({
    required double pointerY,
    required Rect contentRect,
  }) {
    if (contentRect.height <= 0) {
      return 0;
    }

    return (1 - (pointerY - contentRect.top) / contentRect.height).clamp(
      0.0,
      1.0,
    );
  }

  void _syncPointPosition() {
    final target = _target;
    final currentPointer = parentState.dragCurrentPosition;
    if (target == null || currentPointer == null) {
      return;
    }

    final pattern = project.sequence.patterns[target.patternId];
    if (pattern == null) {
      return;
    }

    final points = pattern.automation.points;
    if (target.pointIndex >= points.length ||
        points[target.pointIndex].id != target.point.id) {
      return;
    }

    final normalizedYDelta = target.contentRect.height <= 0
        ? 0.0
        : -(currentPointer.y - target.dragStartAnchor.dy) /
              target.contentRect.height;

    target.point.value = interactionState.isShiftPressed
        ? target.startValue
        : (target.startValue + normalizedYDelta).clamp(0.0, 1.0);

    var xDelta = resolveSnappedDragDelta(
      startPx: target.dragStartAnchor.dx,
      currentPx: currentPointer.x,
      snapOverridden: interactionState.isAltPressed,
    ).delta;

    if (target.pointIndex == 0 && target.startOffset + xDelta < 0) {
      xDelta = -target.startOffset;
    } else if (target.pointIndex > 0) {
      final previousPointOffset = points[target.pointIndex - 1].offset;
      if (target.startOffset + xDelta < previousPointOffset) {
        xDelta = previousPointOffset - target.startOffset;
      }
    }

    if (interactionState.isCtrlPressed) {
      xDelta = 0;
    }

    for (final pointToMove in target.pointsToMoveInTime) {
      if (pointToMove.index >= points.length) {
        continue;
      }

      points[pointToMove.index].offset = pointToMove.startTime + xDelta;
    }
  }

  bool _shouldCommit(EditorStateMachineEvent event) {
    if (isArrangerCancelSignal(event)) {
      return false;
    }

    if (event is! EditorStateMachineSignalEvent) {
      return false;
    }

    final signal = event.signal;
    return signal is _ArrangerPointerUpSignal &&
        signal.event is! PointerCancelEvent;
  }

  void _commitMoveSession() {
    final target = _target;
    if (target == null) {
      return;
    }

    final pattern = project.sequence.patterns[target.patternId];
    if (pattern == null ||
        target.pointIndex >= pattern.automation.points.length ||
        pattern.automation.points[target.pointIndex].id != target.point.id) {
      return;
    }

    final point = pattern.automation.points[target.pointIndex];
    final shouldAddPoint = target.isInsertedPoint;
    final didChangeValue = target.startValue != point.value;
    final didChangeOffset = target.startOffset != point.offset;

    if (!shouldAddPoint && !didChangeValue && !didChangeOffset) {
      return;
    }

    project.startUndoGroup();

    if (shouldAddPoint) {
      project.push(
        AddAutomationPointCommand(
          patternID: target.patternId,
          point: point,
          index: target.pointIndex,
        ),
      );
    }

    if (didChangeValue) {
      project.push(
        SetAutomationPointValueCommand(
          patternID: target.patternId,
          pointIndex: target.pointIndex,
          oldValue: target.startValue,
          newValue: point.value,
        ),
      );
    }

    if (didChangeOffset) {
      final delta = point.offset - target.startOffset;
      for (final pointToMove in target.pointsToMoveInTime) {
        project.push(
          SetAutomationPointOffsetCommand(
            patternID: target.patternId,
            pointIndex: pointToMove.index,
            oldOffset: pointToMove.startTime,
            newOffset: pointToMove.startTime + delta,
          ),
        );
      }
    }

    project.commitUndoGroup();
  }

  void _rollbackMoveSession() {
    final target = _target;
    if (target == null) {
      return;
    }

    final pattern = project.sequence.patterns[target.patternId];
    if (pattern == null) {
      return;
    }

    final points = pattern.automation.points;
    for (final pointToMove in target.pointsToMoveInTime) {
      if (pointToMove.index >= points.length) {
        continue;
      }

      points[pointToMove.index].offset = pointToMove.startTime;
    }

    if (!target.isInsertedPoint) {
      if (target.pointIndex < points.length &&
          points[target.pointIndex].id == target.point.id) {
        points[target.pointIndex].value = target.startValue;
      } else {
        for (final point in points) {
          if (point.id == target.point.id) {
            point.value = target.startValue;
            break;
          }
        }
      }
      return;
    }

    if (target.pointIndex < points.length &&
        points[target.pointIndex].id == target.point.id) {
      points.removeAt(target.pointIndex);
      return;
    }

    points.removeWhere((point) => point.id == target.point.id);
  }
}

int _findIndexForNewAutomationPoint(
  List<AutomationPointModel> points,
  int time,
) {
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    if (point.offset > time) {
      return i;
    }
  }

  return points.length;
}
