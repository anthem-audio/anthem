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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/arranger_events.dart';
import 'package:anthem/widgets/editors/arranger/arranger_view_model.dart';
import 'package:mobx/mobx.dart';

import '../helpers.dart';

part 'pointer_events.dart';

class ArrangerController extends _ArrangerController
    with _ArrangerPointerEventsMixin {
  ArrangerController({
    required ArrangerViewModel viewModel,
    required ProjectModel project,
  }) : super(viewModel: viewModel, project: project);
}

abstract class _ArrangerController {
  ArrangerViewModel viewModel;
  ProjectModel project;

  late final ReactionDisposer patternCursorAutorunDispose;

  _ArrangerController({
    required this.viewModel,
    required this.project,
  }) {
    // Set up an autorun to update the current cursor pattern if the selected
    // pattern changes
    patternCursorAutorunDispose = autorun((_) {
      viewModel.cursorPattern = project.song.activePatternID;
    });
  }

  void dispose() {
    patternCursorAutorunDispose();
  }

  void setBaseTrackHeight(double trackHeight) {
    final oldClampedTrackHeight =
        viewModel.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
    final oldVerticalScrollPosition = viewModel.verticalScrollPosition;
    final clampedTrackHeight =
        trackHeight.clamp(minTrackHeight, maxTrackHeight);

    viewModel.baseTrackHeight = trackHeight;
    viewModel.verticalScrollPosition = oldVerticalScrollPosition *
        (clampedTrackHeight / oldClampedTrackHeight);
  }
}
