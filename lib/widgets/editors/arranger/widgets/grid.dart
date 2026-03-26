/*
  Copyright (C) 2022 - 2026 Joshua Wade

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

import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';

class ArrangerBackgroundPainter extends CustomPainterObserver {
  final Animation<double> verticalScrollPositionAnimation;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;
  final ArrangementModel? activeArrangement;
  final ProjectModel project;

  ArrangerBackgroundPainter({
    required Listenable repaint,
    required this.activeArrangement,
    required this.project,
    required this.verticalScrollPositionAnimation,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
  }) : super(debugName: 'ArrangerBackgroundPainter', repaint: repaint);

  double get timeViewStart => timeViewStartAnimation.value;
  double get timeViewEnd => timeViewEndAnimation.value;

  @override
  void observablePaint(Canvas canvas, Size size) {
    // final accentLinePaint = Paint()..color = AnthemTheme.grid.accent;
    final majorLinePaint = Paint()..color = AnthemTheme.grid.major;
    // final minorLinePaint = Paint()..color = AnthemTheme.grid.minor;

    // Horizontal lines

    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final viewModel = serviceRegistry.arrangerViewModel;
    final trackController = serviceRegistry.trackController;
    final renderedVerticalScrollPosition =
        verticalScrollPositionAnimation.value;
    final verticalScrollDelta =
        viewModel.verticalScrollPosition - renderedVerticalScrollPosition;

    var i = 0;
    for (final (_, isSendTrack, _) in trackController.getTracksIterable()) {
      final trackPosition = viewModel.trackPositionCalculator.getTrackPosition(
        i,
      );
      final trackHeight = viewModel.trackPositionCalculator.getTrackHeight(i);

      var drawPosition = trackPosition + verticalScrollDelta;
      if (!isSendTrack) {
        drawPosition += trackHeight;
      }
      drawPosition--;

      canvas.drawRect(
        Rect.fromLTWH(0, drawPosition, size.width, 1),
        majorLinePaint,
      );

      i++;
    }

    // Vertical lines

    paintTimeGrid(
      canvas: canvas,
      size: size,
      snap: AutoSnap(),
      baseTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: activeArrangement?.timeSignatureChanges ?? [],
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }

  @override
  bool shouldRepaint(covariant ArrangerBackgroundPainter oldDelegate) {
    return oldDelegate.activeArrangement != activeArrangement ||
        oldDelegate.project != project ||
        oldDelegate.verticalScrollPositionAnimation !=
            verticalScrollPositionAnimation ||
        oldDelegate.timeViewStartAnimation != timeViewStartAnimation ||
        oldDelegate.timeViewEndAnimation != timeViewEndAnimation;
  }
}
