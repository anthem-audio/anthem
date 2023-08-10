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
  int? insertedPointIndex;

  _PointMoveActionData({
    required this.pointIndex,
    required this.startTime,
    required this.startValue,
    required this.startPointerOffset,
    required this.pointsToMoveInTime,
    required this.insertedPointIndex,
  });
}

class _TensionChangeActionData {
  int pointIndex;
  double startTension;
  Offset startPointerOffset;
  bool invert;

  _TensionChangeActionData({
    required this.pointIndex,
    required this.startTension,
    required this.startPointerOffset,
    required this.invert,
  });
}

mixin _AutomationEditorPointerEventsMixin on _AutomationEditorController {
  var _eventHandlingState = EventHandlingState.idle;

  _PointMoveActionData? _pointMoveActionData;
  _TensionChangeActionData? _tensionChangeActionData;

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

    var pressed = annotations.firstWhereOrNull(
            (element) => element.metadata.kind == HandleKind.point) ??
        annotations.firstOrNull;

    int? insertedPointIndex;

    if (pressed == null) {
      if (event.buttons & kSecondaryButton > 0) {
        int newPointTime;

        newPointTime = pixelsToTime(
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
          viewPixelWidth: event.viewSize.width,
          pixelOffsetFromLeft: event.pos.dx,
        ).round();

        if (!event.keyboardModifiers.alt) {
          final divisionChanges = getDivisionChanges(
            viewWidthInPixels: event.viewSize.width,
            snap: AutoSnap(),
            defaultTimeSignature: project.song.defaultTimeSignature,
            timeSignatureChanges: pattern.timeSignatureChanges,
            ticksPerQuarter: project.song.ticksPerQuarter,
            timeViewStart: viewModel.timeView.start,
            timeViewEnd: viewModel.timeView.end,
          );

          newPointTime = getSnappedTime(
            rawTime: newPointTime,
            divisionChanges: divisionChanges,
            round: true,
          );
        }

        insertedPointIndex =
            _findIndexForNewPoint(automationLane, newPointTime);
        final point = AutomationPointModel(
          offset: newPointTime,
          value: 1 - (event.pos.dy / event.viewSize.height),
          tension: viewModel.lastInteractedTension ?? 0,
        );
        automationLane.points.insert(
          insertedPointIndex,
          point,
        );
        // Note: we don't calculate a valid center or rect here, since it's not needed
        // after click detection, which has already happened.
        pressed = (
          metadata: (
            center: const Offset(0, 0),
            kind: HandleKind.point,
            pointIndex: insertedPointIndex
          ),
          rect: const Rect.fromLTWH(0, 0, 0, 0),
        );
      } else {
        return;
      }
    }

    final point =
        automationLane.points.nonObservableInner[pressed.metadata.pointIndex];

    if (pressed.metadata.kind == HandleKind.point) {
      _eventHandlingState = EventHandlingState.movingPoint;

      _pointMoveActionData = _PointMoveActionData(
        pointIndex: pressed.metadata.pointIndex,
        startTime: point.offset,
        startValue: point.value,
        startPointerOffset: event.pos,
        pointsToMoveInTime: List.generate(
          automationLane.points.length - pressed.metadata.pointIndex,
          (index) {
            pressed!;
            return (
              index: index + pressed.metadata.pointIndex,
              startTime: automationLane
                  .points[pressed.metadata.pointIndex + index].offset,
            );
          },
        ),
        insertedPointIndex: insertedPointIndex,
      );

      viewModel.lastInteractedTension = point.tension;
    } else {
      if (event.buttons & kSecondaryButton > 0) {
        project.execute(
          SetAutomationPointTensionCommand(
            patternID: project.song.activePatternID!,
            automationGeneratorID: project.activeAutomationGeneratorID!,
            pointIndex: pressed.metadata.pointIndex,
            oldTension: point.tension,
            newTension: 0,
          ),
        );

        viewModel.lastInteractedTension = 0;

        _handleHoverAnimation(null);

        return;
      }

      _eventHandlingState = EventHandlingState.changingTension;

      // The first point doesn't have a tension handle, so this is safe
      final previousPoint = automationLane
          .points.nonObservableInner[pressed.metadata.pointIndex - 1];

      _tensionChangeActionData = _TensionChangeActionData(
        pointIndex: pressed.metadata.pointIndex,
        startTension: point.tension,
        startPointerOffset: event.pos,
        invert: previousPoint.value < point.value,
      );
    }

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

      if (!event.keyboardModifiers.shift) {
        automationLane.points[_pointMoveActionData!.pointIndex].value =
            (_pointMoveActionData!.startValue + normalizedYDelta).clamp(0, 1);
      } else {
        automationLane.points[_pointMoveActionData!.pointIndex].value =
            _pointMoveActionData!.startValue;
      }

      var xDelta = (pixelsToTime(
                timeViewStart: viewModel.timeView.start,
                timeViewEnd: viewModel.timeView.end,
                viewPixelWidth: event.viewSize.width,
                pixelOffsetFromLeft: deltaFromStart.dx,
              ) -
              viewModel.timeView.start)
          .round();

      if (!event.keyboardModifiers.alt) {
        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.viewSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.song.defaultTimeSignature,
          timeSignatureChanges: pattern.timeSignatureChanges,
          ticksPerQuarter: project.song.ticksPerQuarter,
          timeViewStart: viewModel.timeView.start,
          timeViewEnd: viewModel.timeView.end,
        );

        final snappedTime = getSnappedTime(
          rawTime: _pointMoveActionData!.startTime + xDelta,
          divisionChanges: divisionChanges,
          round: true,
          startTime: _pointMoveActionData!.startTime,
        );

        xDelta = snappedTime - _pointMoveActionData!.startTime;
      }

      final thisPointStartOffset = _pointMoveActionData!.startTime;

      if (_pointMoveActionData!.pointIndex == 0 &&
          thisPointStartOffset + xDelta < 0) {
        xDelta = -thisPointStartOffset;
      } else if (_pointMoveActionData!.pointIndex > 0) {
        final lastPointStartOffset =
            automationLane.points[_pointMoveActionData!.pointIndex - 1].offset;

        if (thisPointStartOffset + xDelta < lastPointStartOffset) {
          xDelta = lastPointStartOffset - thisPointStartOffset;
        }
      }

      if (!event.keyboardModifiers.ctrl) {
        for (final pointToMove in _pointMoveActionData!.pointsToMoveInTime) {
          automationLane.points[pointToMove.index].offset =
              pointToMove.startTime + xDelta;
        }
      } else {
        for (final pointToMove in _pointMoveActionData!.pointsToMoveInTime) {
          automationLane.points[pointToMove.index].offset =
              pointToMove.startTime;
        }
      }
    } else if (_eventHandlingState == EventHandlingState.changingTension) {
      final point = automationLane.points[_tensionChangeActionData!.pointIndex];

      final deltaY =
          event.pos.dy - _tensionChangeActionData!.startPointerOffset.dy;
      final deltaTension = -deltaY / 250;
      final invertMult = _tensionChangeActionData!.invert ? -1 : 1;

      point.tension =
          (_tensionChangeActionData!.startTension + invertMult * deltaTension)
              .clamp(-1, 1);
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

        if (_pointMoveActionData!.insertedPointIndex != null) {
          project.push(
            AddAutomationPointCommand(
              patternID: project.song.activePatternID!,
              automationGeneratorID: project.activeAutomationGeneratorID!,
              point: point,
              index: _pointMoveActionData!.insertedPointIndex!,
            ),
          );
        }

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

        if (_pointMoveActionData!.startTime != point.offset) {
          final delta = point.offset - _pointMoveActionData!.startTime;

          var i = 0;
          for (final pointToMove in _pointMoveActionData!.pointsToMoveInTime) {
            project.push(
              SetAutomationPointOffsetCommand(
                patternID: project.song.activePatternID!,
                automationGeneratorID: project.activeAutomationGeneratorID!,
                pointIndex: _pointMoveActionData!.pointIndex + i,
                oldOffset: pointToMove.startTime,
                newOffset: pointToMove.startTime + delta,
              ),
            );
            i++;
          }
        }

        project.commitJournalPage();

        break;
      case EventHandlingState.changingTension:
        final point = project
            .song
            .patterns[project.song.activePatternID]!
            .automationLanes[project.activeAutomationGeneratorID]!
            .points[_tensionChangeActionData!.pointIndex];

        project.startJournalPage();

        final tension = point.tension;

        project.push(
          SetAutomationPointTensionCommand(
            patternID: project.song.activePatternID!,
            automationGeneratorID: project.activeAutomationGeneratorID!,
            pointIndex: _tensionChangeActionData!.pointIndex,
            oldTension: _tensionChangeActionData!.startTension,
            newTension: tension,
          ),
        );

        viewModel.lastInteractedTension = tension;

        project.commitJournalPage();

        break;
      case EventHandlingState.idle:
        break;
    }

    _eventHandlingState = EventHandlingState.idle;

    _pointMoveActionData = null;
    _tensionChangeActionData = null;

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

/// Finds the correct index to insert a point at, given the time value for that
/// point.
int _findIndexForNewPoint(AutomationLaneModel automationLane, int time) {
  final points = automationLane.points;

  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    if (point.offset > time) {
      return i;
    }
  }

  return points.length;
}
