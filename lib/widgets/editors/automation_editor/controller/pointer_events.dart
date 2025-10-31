/*
  Copyright (C) 2023 - 2025 Joshua Wade

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
  bool didCreateAutomationLane;

  _PointMoveActionData({
    required this.pointIndex,
    required this.startTime,
    required this.startValue,
    required this.startPointerOffset,
    required this.pointsToMoveInTime,
    required this.insertedPointIndex,
    required this.didCreateAutomationLane,
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

  void hover(Offset pos) {
    final annotations = viewModel.visiblePoints.hitTestAll(pos);

    final hovered =
        annotations.firstWhereOrNull(
          (element) => element.metadata.kind == HandleKind.point,
        ) ??
        annotations.firstOrNull;

    final hoveredAnnotation = hovered?.metadata;
    viewModel.hoveredPointAnnotation = hoveredAnnotation;
  }

  void pointerDown(AutomationEditorPointerDownEvent event) {
    final pattern = project.sequence.patterns[project.sequence.activePatternID];
    if (pattern == null) return;

    if (project.activeAutomationGeneratorID == null) return;

    var didCreateAutomationLane = false;

    if (event.buttons & kSecondaryButton > 0 &&
        pattern.automationLanes[project.activeAutomationGeneratorID] == null) {
      pattern.automationLanes[project.activeAutomationGeneratorID!] =
          AutomationLaneModel();
      didCreateAutomationLane = true;
    }

    final automationLane =
        pattern.automationLanes[project.activeAutomationGeneratorID];

    if (automationLane == null) return;

    final annotations = viewModel.visiblePoints.hitTestAll(event.pos);

    var pressed =
        annotations.firstWhereOrNull(
          (element) => element.metadata.kind == HandleKind.point,
        ) ??
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

        if (!HardwareKeyboard.instance.isAltPressed) {
          final divisionChanges = getDivisionChanges(
            viewWidthInPixels: event.viewSize.width,
            snap: AutoSnap(),
            defaultTimeSignature: project.sequence.defaultTimeSignature,
            timeSignatureChanges: pattern.timeSignatureChanges,
            ticksPerQuarter: project.sequence.ticksPerQuarter,
            timeViewStart: viewModel.timeView.start,
            timeViewEnd: viewModel.timeView.end,
          );

          newPointTime = getSnappedTime(
            rawTime: newPointTime,
            divisionChanges: divisionChanges,
            round: true,
          );
        }

        insertedPointIndex = _findIndexForNewPoint(
          automationLane,
          newPointTime,
        );
        final point = AutomationPointModel(
          offset: newPointTime,
          value: 1 - (event.pos.dy / event.viewSize.height),
          tension: viewModel.lastInteractedTension ?? 0,
        );
        automationLane.points.insert(insertedPointIndex, point);
        // Note: we don't calculate a valid center or rect here, since it's not needed
        // after click detection, which has already happened.
        pressed = (
          metadata: (
            center: const Offset(0, 0),
            kind: HandleKind.point,
            pointIndex: insertedPointIndex,
            pointId: point.id,
          ),
          rect: const Rect.fromLTWH(0, 0, 0, 0),
        );
      } else {
        return;
      }
    } else {
      if (pressed.metadata.kind == HandleKind.point &&
          event.buttons & kSecondaryButton > 0) {
        viewModel.pointMenu.children = [
          AnthemMenuItem(
            text: 'Delete',
            onSelected: () {
              project.execute(
                DeleteAutomationPointCommand(
                  patternID: project.sequence.activePatternID!,
                  automationGeneratorID: project.activeAutomationGeneratorID!,
                  point: automationLane.points[pressed!.metadata.pointIndex],
                  index: pressed.metadata.pointIndex,
                ),
              );
            },
          ),
        ];
        viewModel.pointMenuController.open(event.globalPos);
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
                  .points[pressed.metadata.pointIndex + index]
                  .offset,
            );
          },
        ),
        insertedPointIndex: insertedPointIndex,
        didCreateAutomationLane: didCreateAutomationLane,
      );

      viewModel.lastInteractedTension = point.tension;
    } else {
      if (event.buttons & kSecondaryButton > 0) {
        project.execute(
          SetAutomationPointTensionCommand(
            patternID: project.sequence.activePatternID!,
            automationGeneratorID: project.activeAutomationGeneratorID!,
            pointIndex: pressed.metadata.pointIndex,
            oldTension: point.tension,
            newTension: 0,
          ),
        );

        viewModel.lastInteractedTension = 0;

        viewModel.hoveredPointAnnotation = null;

        return;
      }

      _eventHandlingState = EventHandlingState.changingTension;

      // The first point doesn't have a tension handle, so this is safe
      final previousPoint = automationLane
          .points
          .nonObservableInner[pressed.metadata.pointIndex - 1];

      _tensionChangeActionData = _TensionChangeActionData(
        pointIndex: pressed.metadata.pointIndex,
        startTension: point.tension,
        startPointerOffset: event.pos,
        invert: previousPoint.value < point.value,
      );
    }

    viewModel.pressedPointAnnotation = pressed.metadata;
  }

  void pointerMove(AutomationEditorPointerMoveEvent event) {
    final pattern = project.sequence.patterns[project.sequence.activePatternID];
    if (pattern == null) return;
    final automationLane =
        pattern.automationLanes[project.activeAutomationGeneratorID];
    if (automationLane == null) return;

    if (_eventHandlingState == EventHandlingState.movingPoint) {
      final deltaFromStart =
          event.pos - _pointMoveActionData!.startPointerOffset;

      final normalizedYDelta = -deltaFromStart.dy / event.viewSize.height;

      if (!HardwareKeyboard.instance.isShiftPressed) {
        automationLane.points[_pointMoveActionData!.pointIndex].value =
            (_pointMoveActionData!.startValue + normalizedYDelta).clamp(0, 1);
      } else {
        automationLane.points[_pointMoveActionData!.pointIndex].value =
            _pointMoveActionData!.startValue;
      }

      var xDelta =
          (pixelsToTime(
                    timeViewStart: viewModel.timeView.start,
                    timeViewEnd: viewModel.timeView.end,
                    viewPixelWidth: event.viewSize.width,
                    pixelOffsetFromLeft: deltaFromStart.dx,
                  ) -
                  viewModel.timeView.start)
              .round();

      if (!HardwareKeyboard.instance.isAltPressed) {
        final divisionChanges = getDivisionChanges(
          viewWidthInPixels: event.viewSize.width,
          snap: AutoSnap(),
          defaultTimeSignature: project.sequence.defaultTimeSignature,
          timeSignatureChanges: pattern.timeSignatureChanges,
          ticksPerQuarter: project.sequence.ticksPerQuarter,
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

      if (!HardwareKeyboard.instance.isControlPressed) {
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
      final invertMultiplier = _tensionChangeActionData!.invert ? -1 : 1;

      point.tension =
          (_tensionChangeActionData!.startTension +
                  invertMultiplier * deltaTension)
              .clamp(-1, 1);
    }
  }

  void pointerUp() {
    if (project.sequence.activePatternID == null) return;
    if (project.activeAutomationGeneratorID == null) return;

    switch (_eventHandlingState) {
      case EventHandlingState.movingPoint:
        final point = project
            .sequence
            .patterns[project.sequence.activePatternID]!
            .automationLanes[project.activeAutomationGeneratorID]!
            .points[_pointMoveActionData!.pointIndex];

        project.startJournalPage();

        if (_pointMoveActionData!.insertedPointIndex != null) {
          project.push(
            AddAutomationPointCommand(
              patternID: project.sequence.activePatternID!,
              automationGeneratorID: project.activeAutomationGeneratorID!,
              point: point,
              index: _pointMoveActionData!.insertedPointIndex!,
              createAutomationLane:
                  _pointMoveActionData!.didCreateAutomationLane,
            ),
          );
        }

        if (_pointMoveActionData!.startValue != point.value) {
          project.push(
            SetAutomationPointValueCommand(
              patternID: project.sequence.activePatternID!,
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
                patternID: project.sequence.activePatternID!,
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
            .sequence
            .patterns[project.sequence.activePatternID]!
            .automationLanes[project.activeAutomationGeneratorID]!
            .points[_tensionChangeActionData!.pointIndex];

        project.startJournalPage();

        final tension = point.tension;

        project.push(
          SetAutomationPointTensionCommand(
            patternID: project.sequence.activePatternID!,
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

    viewModel.pressedPointAnnotation = null;
  }

  void pointMenuClosed() {
    viewModel.pointMenu.children = [];
  }

  void mouseOut() {
    for (final value in viewModel.pointAnimationTracker.values.values) {
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
