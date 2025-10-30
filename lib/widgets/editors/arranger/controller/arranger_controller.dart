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

import 'dart:async';
import 'dart:math';

import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/commands/journal_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/arranger/events.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

import '../helpers.dart';

part 'pointer_events.dart';
part 'shortcuts.dart';

class ArrangerController extends _ArrangerController
    with _ArrangerPointerEventsMixin, _ArrangerShortcutsMixin {
  ArrangerController({required super.viewModel, required super.project}) {
    // Register shortcuts for this editor
    registerShortcuts();
  }
}

abstract class _ArrangerController {
  ArrangerViewModel viewModel;
  ProjectModel project;

  late final ReactionDisposer patternCursorAutorunDispose;

  _ArrangerController({required this.viewModel, required this.project}) {
    // Set up an autorun to update the current cursor pattern if the selected
    // pattern changes
    patternCursorAutorunDispose = autorun((_) {
      viewModel.cursorPattern = project.sequence.activePatternID;
      viewModel.cursorTimeRange = null;
    });
  }

  void dispose() {
    patternCursorAutorunDispose();
  }

  void setBaseTrackHeight(double pointerY, double trackHeight) {
    final oldClampedTrackHeight = viewModel.baseTrackHeight.clamp(
      minTrackHeight,
      maxTrackHeight,
    );
    final oldVerticalScrollPosition = viewModel.verticalScrollPosition;
    final clampedTrackHeight = trackHeight.clamp(
      minTrackHeight,
      maxTrackHeight,
    );

    final heightRatio = clampedTrackHeight / oldClampedTrackHeight;

    viewModel.baseTrackHeight = trackHeight;
    viewModel.verticalScrollPosition =
        ((oldVerticalScrollPosition + pointerY) * heightRatio - pointerY).clamp(
          0,
          double.infinity,
        );

    onBaseTrackHeightChanged.add(null);
  }

  /// We need to snap the vertical scroll position animation when this happens.
  final onBaseTrackHeightChanged = StreamController<void>.broadcast();

  void deleteSelected() {
    if (viewModel.selectedClips.isEmpty ||
        project.sequence.activeArrangementID == null) {
      return;
    }

    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    project.startJournalPage();

    for (final clipID in viewModel.selectedClips) {
      project.execute(
        DeleteClipCommand(
          arrangementID: project.sequence.activeArrangementID!,
          clip: arrangement.clips[clipID]!,
        ),
      );
    }

    project.commitJournalPage();
  }

  void selectAll() {
    if (project.sequence.activeArrangementID == null) return;

    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    viewModel.selectedClips.clear();

    for (final clipID in arrangement.clips.keys) {
      viewModel.selectedClips.add(clipID);
    }
  }
}
