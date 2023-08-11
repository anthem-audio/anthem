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
import 'package:anthem/model/pattern/automation_lane.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/automation_editor/view_model.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';

import '../automation_point_animation_tracker.dart';
import '../events.dart';

part 'pointer_events.dart';

class AutomationEditorController extends _AutomationEditorController
    with _AutomationEditorPointerEventsMixin {
  AutomationEditorController(
      {required AutomationEditorViewModel viewModel,
      required ProjectModel project})
      : super(viewModel: viewModel, project: project);
}

class _AutomationEditorController {
  AutomationEditorViewModel viewModel;
  ProjectModel project;

  _AutomationEditorController({required this.viewModel, required this.project});
}
