/*
  Copyright (C) 2023 Joshua Wade

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

part of 'automation_editor_controller.dart';

enum _HandleState { out, hovered, pressed }

/// These are the possible states that the automation editor can have during
/// event handing. The current state tells the controller how to handle incoming
/// pointer events.
enum EventHandlingState {
  /// Nothing is happening right now.
  idle,

  /// A point is being moved. Note that horizontal point movements will also
  /// cause all points after the pressed point to move.
  movingPoint,

  /// The tension value for a point is being changed.
  changingTension,
}

class _PointMoveActionData {
  int pointIndex;
  Time startTime;
  double startValue;
  Offset startPointerOffset;
  List<({int index, Time startTime})> pointsToMoveInTime;

  _PointMoveActionData({
    required this.pointIndex,
    required this.startTime,
    required this.startValue,
    required this.startPointerOffset,
    required this.pointsToMoveInTime,
  });
}

// class _TensionChangeActionData {}

mixin _AutomationEditorPointerEventsMixin on _AutomationEditorController {
  var _eventHandlingState = EventHandlingState.idle;

  _PointMoveActionData? _pointMoveActionData;
  // _TensionChangeActionData? _tensionChangeActionData;

  double _getTargetValue(_HandleState state) {
    return switch (state) {
      _HandleState.out => 1,
      _HandleState.hovered => automationPointHoveredSizeMultiplier,
      _HandleState.pressed => automationPointPressedSizeMultiplier,
    };
  }

  void _setPointTargetPos({
    required int pointIndex,
    required HandleKind handleKind,
    required _HandleState startState,
    required _HandleState endState,
  }) {
    var didSetTarget = false;
    for (final point in viewModel.pointAnimationTracker.values) {
      if (point.pointIndex == pointIndex && point.handleKind == handleKind) {
        point.target = _getTargetValue(endState);
        didSetTarget = true;
        continue;
      }
    }
    if (!didSetTarget) {
      viewModel.pointAnimationTracker.addValue(
        AutomationPointAnimationValue(
          handleKind: handleKind,
          pointIndex: pointIndex,
          start: _getTargetValue(startState),
          target: _getTargetValue(endState),
        ),
      );
    }
  }

  void hover(Offset pos) {
    final annotations = viewModel.visiblePoints.hitTestAll(pos);

    final hovered = annotations.firstWhereOrNull(
            (element) => element.metadata.kind == HandleKind.point) ??
        annotations.firstOrNull;

    _handleHoverAnimation(hovered);
  }

  void pointerDown(AutomationEditorPointerDownEvent event) {
    final pattern = project.song.patterns[project.song.activePatternID];
    if (pattern == null) return;
    final automationLane =
        pattern.automationLanes[project.activeAutomationGeneratorID];
    if (automationLane == null) return;

    final annotations = viewModel.visiblePoints.hitTestAll(event.pos);

    final pressed = annotations.firstWhereOrNull(
            (element) => element.metadata.kind == HandleKind.point) ??
        annotations.firstOrNull;

    if (pressed == null) {
      if (event.buttons & kSecondaryButton > 0) {
        // TODO: Create a point
        // pressed = ...
      } else {
        return;
      }
    }

    pressed!;

    _eventHandlingState = EventHandlingState.movingPoint;

    final point =
        automationLane.points.nonObservableInner[pressed.metadata.pointIndex];

    _pointMoveActionData = _PointMoveActionData(
      pointIndex: pressed.metadata.pointIndex,
      startTime: point.offset,
      startValue: point.value,
      startPointerOffset: event.pos,
      pointsToMoveInTime: List.generate(
        automationLane.points.length - 1 - pressed.metadata.pointIndex,
        (index) => (
          index: index,
          startTime: automationLane
              .points[pressed.metadata.pointIndex + 1 + index].offset,
        ),
      ),
    );

    _handlePressAnimation(pressed);
  }

  void pointerMove(AutomationEditorPointerMoveEvent event) {
    final pattern = project.song.patterns[project.song.activePatternID];
    if (pattern == null) return;
    final automationLane =
        pattern.automationLanes[project.activeAutomationGeneratorID];
    if (automationLane == null) return;

    if (_eventHandlingState == EventHandlingState.movingPoint) {
      final deltaFromStart =
          event.pos - _pointMoveActionData!.startPointerOffset;

      final normalizedYDelta = -deltaFromStart.dy / event.viewSize.height;

      automationLane.points[_pointMoveActionData!.pointIndex].value =
          (_pointMoveActionData!.startValue + normalizedYDelta).clamp(0, 1);
    }
  }

  void pointerUp() {
    if (project.song.activePatternID == null) return;
    if (project.activeAutomationGeneratorID == null) return;

    switch (_eventHandlingState) {
      case EventHandlingState.movingPoint:
        final point = project
            .song
            .patterns[project.song.activePatternID]!
            .automationLanes[project.activeAutomationGeneratorID]!
            .points[_pointMoveActionData!.pointIndex];

        project.startJournalPage();
        if (_pointMoveActionData!.startValue != point.value) {
          project.push(
            SetAutomationPointValueCommand(
              patternID: project.song.activePatternID!,
              automationGeneratorID: project.activeAutomationGeneratorID!,
              pointIndex: _pointMoveActionData!.pointIndex,
              oldValue: _pointMoveActionData!.startValue,
              newValue: point.value,
            ),
          );
        }
        project.commitJournalPage();
        break;
      default:
        break;
    }

    _eventHandlingState = EventHandlingState.idle;

    _pointMoveActionData = null;

    _handleReleaseAnimation();
  }

  void _handleHoverAnimation(CanvasAnnotation<PointAnnotation>? hovered) {
    final hoveredAnnotation = hovered?.metadata;
    final oldHoveredAnnotation = viewModel.hoveredPointAnnotation;
    viewModel.hoveredPointAnnotation = hoveredAnnotation;

    if (hoveredAnnotation != oldHoveredAnnotation) {
      if (oldHoveredAnnotation != null) {
        _setPointTargetPos(
          pointIndex: oldHoveredAnnotation.pointIndex,
          handleKind: oldHoveredAnnotation.kind,
          startState: viewModel.pressedPointAnnotation == oldHoveredAnnotation
              ? _HandleState.pressed
              : _HandleState.hovered,
          endState: _HandleState.out,
        );
      }
      if (hoveredAnnotation != null) {
        _setPointTargetPos(
          pointIndex: hoveredAnnotation.pointIndex,
          handleKind: hoveredAnnotation.kind,
          startState: _HandleState.out,
          endState: viewModel.pressedPointAnnotation == hoveredAnnotation
              ? _HandleState.pressed
              : _HandleState.hovered,
        );
      }
    }
  }

  void _handlePressAnimation(CanvasAnnotation<PointAnnotation> pressed) {
    final pressedAnnotation = pressed.metadata;

    viewModel.pressedPointAnnotation = pressedAnnotation;

    _setPointTargetPos(
      pointIndex: pressedAnnotation.pointIndex,
      handleKind: pressedAnnotation.kind,
      startState: pressedAnnotation == viewModel.hoveredPointAnnotation
          ? _HandleState.hovered
          : _HandleState.out,
      endState: _HandleState.pressed,
    );
  }

  void _handleReleaseAnimation() {
    final pressedAnnotation = viewModel.pressedPointAnnotation;

    if (pressedAnnotation == null) return;

    viewModel.pressedPointAnnotation = null;

    _setPointTargetPos(
      pointIndex: pressedAnnotation.pointIndex,
      handleKind: pressedAnnotation.kind,
      startState: _HandleState.pressed,
      endState: pressedAnnotation == viewModel.hoveredPointAnnotation
          ? _HandleState.hovered
          : _HandleState.out,
    );
  }

  void mouseOut() {
    for (final value in viewModel.pointAnimationTracker.values) {
      value.target = 1;
    }
    viewModel.hoveredPointAnnotation = null;
  }
}
