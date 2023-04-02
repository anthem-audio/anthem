/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';

import '../arranger_view_model.dart';
import '../helpers.dart';

class ArrangerBackgroundPainter extends CustomPainterObserver {
  final double verticalScrollPosition;
  final double timeViewStart;
  final double timeViewEnd;
  final ArrangerViewModel viewModel;
  final ArrangementModel? activeArrangement;
  final ProjectModel project;

  ArrangerBackgroundPainter({
    required this.viewModel,
    required this.activeArrangement,
    required this.project,
    required this.verticalScrollPosition,
    required this.timeViewStart,
    required this.timeViewEnd,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    // final accentLinePaint = Paint()..color = Theme.grid.accent;
    final majorLinePaint = Paint()..color = Theme.grid.major;
    // final minorLinePaint = Paint()..color = Theme.grid.minor;

    // Horizontal lines

    var verticalPositionPointer = -verticalScrollPosition - 1;

    final baseTrackHeight = viewModel.baseTrackHeight;

    for (final trackID in project.song.trackOrder) {
      final trackHeight = getTrackHeight(
        baseTrackHeight,
        viewModel.trackHeightModifiers[trackID]!,
      );

      verticalPositionPointer += trackHeight;

      if (verticalPositionPointer < 0) continue;
      if (verticalPositionPointer > size.height) break;

      canvas.drawRect(
        Rect.fromLTWH(0, verticalPositionPointer, size.width, 1),
        majorLinePaint,
      );
    }

    // Vertical lines

    paintTimeGrid(
      canvas: canvas,
      size: size,
      snap: DivisionSnap(division: Division(multiplier: 1, divisor: 4)),
      baseTimeSignature: TimeSignatureModel(4, 4),
      timeSignatureChanges: [],
      ticksPerQuarter: project.song.ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }

  @override
  bool shouldRepaint(covariant ArrangerBackgroundPainter oldDelegate) {
    return oldDelegate.viewModel != viewModel ||
        oldDelegate.activeArrangement != activeArrangement ||
        oldDelegate.project != project ||
        super.shouldRepaint(oldDelegate);
  }
}
