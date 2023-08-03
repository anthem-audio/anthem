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

mixin _AutomationEditorPointerEventsMixin on _AutomationEditorController {
  void mouseOut() {
    for (final value in viewModel.pointAnimationTracker.values) {
      value.target = 1;
    }
    viewModel.hoveredPointAnnotation = null;
  }

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
    _handleHoverAnimation(pos);
  }

  void press(Offset pos) {
    _handlePressAnimation(pos);
  }

  void move(Offset pos) {}

  void release() {
    _handleReleaseAnimation();
  }

  void _handleHoverAnimation(Offset pos) {
    final annotations = viewModel.visiblePoints.hitTestAll(pos);

    final hovered = annotations.firstWhereOrNull(
            (element) => element.metadata.kind == HandleKind.point) ??
        annotations.firstOrNull;

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

  void _handlePressAnimation(Offset pos) {
    final annotations = viewModel.visiblePoints.hitTestAll(pos);

    final pressed = annotations.firstWhereOrNull(
            (element) => element.metadata.kind == HandleKind.point) ??
        annotations.firstOrNull;

    if (pressed == null) return;

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
}
