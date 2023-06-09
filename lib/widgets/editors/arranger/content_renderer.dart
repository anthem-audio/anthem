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

/// Size of the resize handles, in pixels.
const clipResizeHandleWidth = 12.0;

/// How far over the clip the resize handle extends, in pixels.
const clipResizeHandleOvershoot = 2.0;

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
      painterBuilder: () => ArrangerContentPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        verticalScrollPosition: verticalScrollPosition,
        project: project,
        arrangement: arrangement,
        viewModel: viewModel,
        devicePixelRatio: View.of(context).devicePixelRatio,
      ),
      isComplex: true,
    );
  }
}

class ArrangerContentPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final double verticalScrollPosition;
  final ProjectModel project;
  final ArrangementModel arrangement;
  final ArrangerViewModel viewModel;
  final double devicePixelRatio;

  ArrangerContentPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.verticalScrollPosition,
    required this.project,
    required this.arrangement,
    required this.viewModel,
    required this.devicePixelRatio,
  });

  @override
  bool shouldRepaint(ArrangerContentPainter oldDelegate) {
    return timeViewStart != oldDelegate.timeViewStart ||
        timeViewEnd != oldDelegate.timeViewEnd ||
        verticalScrollPosition != oldDelegate.verticalScrollPosition ||
        project != oldDelegate.project ||
        arrangement != oldDelegate.arrangement ||
        viewModel != oldDelegate.viewModel ||
        devicePixelRatio != oldDelegate.devicePixelRatio ||
        super.shouldRepaint(oldDelegate);
  }

  @override
  void observablePaint(Canvas canvas, Size size) {
    viewModel.visibleClips.clear();
    viewModel.visibleResizeAreas.clear();

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
        canvasSize: size,
        pattern: pattern,
        clip: clip,
        x: x,
        y: y,
        width: width,
        height: trackHeight,
        selected: viewModel.selectedClips.contains(clip.id),
        pressed: viewModel.pressedClip == clip.id,
        devicePixelRatio: devicePixelRatio,
      );

      viewModel.visibleClips.add(
        rect: Rect.fromLTWH(x, y, width - 1, trackHeight - 1),
        metadata: (id: clip.id),
      );

      const minimumClickableClipArea = 30;

      final startResizeHandleRect = Rect.fromLTWH(
        x - clipResizeHandleOvershoot,
        y,
        clipResizeHandleWidth
            // Ensures there's a bit of the clip still showing
            -
            (minimumClickableClipArea - width)
                .clamp(0, (clipResizeHandleWidth - clipResizeHandleOvershoot)),
        trackHeight - 1,
      );
      viewModel.visibleResizeAreas.add(
        rect: startResizeHandleRect,
        metadata: (id: clip.id, type: ResizeAreaType.start),
      );

      // Notice this is fromLTRB. We generally use fromLTWH elsewhere.
      final endResizeHandleRect = Rect.fromLTRB(
        x +
            (width - (clipResizeHandleWidth - clipResizeHandleOvershoot))
                // Ensures there's a bit of the clip still showing
                .clamp(minimumClickableClipArea, double.infinity)
                .clamp(0, width),
        y,
        x + width + clipResizeHandleOvershoot,
        y + trackHeight - 1,
      );
      viewModel.visibleResizeAreas.add(
        rect: endResizeHandleRect,
        metadata: (id: clip.id, type: ResizeAreaType.end),
      );
    });
  }
}
