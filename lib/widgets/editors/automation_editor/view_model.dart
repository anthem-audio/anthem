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

import 'package:anthem/widgets/editors/automation_editor/automation_point_animation_tracker.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:mobx/mobx.dart';

import '../shared/helpers/types.dart';

part 'view_model.g.dart';

enum HandleKind {
  tensionHandle,
  point,
}

typedef PointAnnotation = ({
  HandleKind kind,
  int pointIndex,
  Offset center,
});

// ignore: library_private_types_in_public_api
class AutomationEditorViewModel = _AutomationEditorViewModel
    with _$AutomationEditorViewModel;

abstract class _AutomationEditorViewModel with Store {
  TimeRange timeView;

  final visiblePoints = CanvasAnnotationSet<PointAnnotation>();

  @observable
  PointAnnotation? hoveredPointAnnotation;

  @observable
  PointAnnotation? pressedPointAnnotation;

  final pointAnimationTracker = AutomationPointAnimationTracker();

  _AutomationEditorViewModel({required this.timeView});
}
