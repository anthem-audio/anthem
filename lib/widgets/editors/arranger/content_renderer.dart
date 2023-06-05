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

import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

class ArrangerContentRenderer extends StatelessObserverWidget {
  final double timeViewStart;
  final double timeViewEnd;
  final double verticalScrollPosition;
  final ArrangerViewModel viewModel;

  const ArrangerContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.verticalScrollPosition,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final arrangement =
        project.song.arrangements[project.song.activeArrangementID];

    if (arrangement == null) return const SizedBox();

    return CustomPaintObserver(
      painterBuilder: () => ClipPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        verticalScrollPosition: verticalScrollPosition,
        project: project,
        arrangement: arrangement,
        viewModel: viewModel,
      ),
    );
  }
}

class ClipPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final double verticalScrollPosition;
  final ProjectModel project;
  final ArrangementModel arrangement;
  final ArrangerViewModel viewModel;

  ClipPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.verticalScrollPosition,
    required this.project,
    required this.arrangement,
    required this.viewModel,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    arrangement.clips.forEach((key, clip) {
      final pattern = project.song.patterns[clip.patternID];
      if (pattern == null) return;

      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: clip.offset.toDouble(),
      );
      final width = timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: clip.offset.toDouble() + clip.getWidth(project),
          ) -
          x +
          1;

      if (x > size.width || x + width < 0) return;

      final y = trackIndexToPos(
            trackIndex: project.song.trackOrder
                .indexWhere((trackID) => trackID == clip.trackID)
                .toDouble(),
            baseTrackHeight: viewModel.baseTrackHeight,
            trackOrder: project.song.trackOrder,
            trackHeightModifiers: viewModel.trackHeightModifiers,
            scrollPosition: verticalScrollPosition,
          ) -
          1;
      final trackHeight = getTrackHeight(
            viewModel.baseTrackHeight,
            viewModel.trackHeightModifiers[clip.trackID]!,
          ) +
          1;

      if (y > size.height || y + trackHeight < 0) return;

      paintClip(
        canvas: canvas,
        size: size,
        pattern: pattern,
        clip: clip,
        x: x,
        y: y,
        width: width,
        height: trackHeight,
        selected: viewModel.selectedClips.contains(clip.id),
        pressed: viewModel.pressedClip == clip.id,
      );
    });
  }
}
