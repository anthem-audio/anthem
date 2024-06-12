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

import 'dart:ui';

import 'package:anthem/commands/pattern_automation_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/automation_lane.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:mobx/mobx.dart';

import '../automation_point_animation_tracker.dart';
import '../events.dart';

part 'pointer_events.dart';

class AutomationEditorController extends _AutomationEditorController
    with _AutomationEditorPointerEventsMixin {
  AutomationEditorController(
      {required super.viewModel, required super.project});
}

class _AutomationEditorController {
  AutomationEditorViewModel viewModel;
  ProjectModel project;
  late ReactionDisposer pointAnimationAutorunDisposer;

  _AutomationEditorController(
      {required this.viewModel, required this.project}) {
    // This autorun updates the animation targets for automation points based on
    // the current hovered item.
    pointAnimationAutorunDisposer = autorun((_) {
      final pattern = project.song.patterns[project.song.activePatternID];
      if (pattern == null) return;

      final automationLane =
          pattern.automationLanes[project.activeAutomationGeneratorID];
      if (automationLane == null) return;

      // These will not be watched if there aren't any points, so we'll access
      // them here.
      viewModel.hoveredPointAnnotation;
      viewModel.pressedPointAnnotation;

      final visitedPointIds = <ID>{};

      // We don't need to observe the whole list - we just care when the hovered
      // and pressed point values change.
      for (final point in automationLane.points.nonObservableInner) {
        visitedPointIds.add(point.id);

        for (final handleKind in HandleKind.values) {
          final handle = viewModel.pointAnimationTracker.values[(
            handleKind: handleKind,
            id: point.id,
          )];

          var didUpdateHandle = false;

          for (final (handleState, annotation) in [
            (_HandleState.out, null),
            (_HandleState.hovered, viewModel.hoveredPointAnnotation),
            (_HandleState.pressed, viewModel.pressedPointAnnotation),
          ]) {
            if (annotation?.pointId == point.id &&
                annotation?.kind == handleKind) {
              if (handle != null) {
                handle.setTarget(_getHandleTargetValue(handleState));
                didUpdateHandle = true;
              } else if (annotation != null) {
                viewModel.pointAnimationTracker.addValue(
                  id: point.id,
                  handleKind: handleKind,
                  value: AutomationPointAnimationValue(
                    start: _getHandleTargetValue(_HandleState.out),
                    target: _getHandleTargetValue(handleState),
                    pointId: point.id,
                    handleKind: handleKind,
                    restPos: _getHandleTargetValue(_HandleState.out),
                  ),
                );
              }
            }
          }

          if (!didUpdateHandle) {
            handle?.setTarget(_getHandleTargetValue(_HandleState.out));
          }
        }
      }

      // Remove any points in the animation list that aren't in the current
      // automation lane.
      for (final animationKey in viewModel.pointAnimationTracker.values.keys) {
        if (!visitedPointIds.contains(animationKey.id)) {
          viewModel.pointAnimationTracker.values.remove(animationKey);
        }
      }
    });
  }

  void dispose() {
    pointAnimationAutorunDisposer();
  }
}

double _getHandleTargetValue(_HandleState state) {
  return switch (state) {
    _HandleState.out => 1,
    _HandleState.hovered => automationPointHoveredSizeMultiplier,
    _HandleState.pressed => automationPointPressedSizeMultiplier,
  };
}
