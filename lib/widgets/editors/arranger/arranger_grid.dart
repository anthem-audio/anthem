/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';

import 'helpers.dart';

class ArrangerBackgroundPainter extends CustomPainter {
  final double baseTrackHeight;
  final Map<ID, double> trackHeightModifiers;
  final List<ID> trackIDs;
  final double verticalScrollPosition;
  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;

  ArrangerBackgroundPainter({
    required this.baseTrackHeight,
    required this.trackHeightModifiers,
    required this.trackIDs,
    required this.verticalScrollPosition,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // final accentLinePaint = Paint()..color = Theme.grid.accent;
    final majorLinePaint = Paint()..color = Theme.grid.major;
    // final minorLinePaint = Paint()..color = Theme.grid.minor;

    // Horizontal lines

    var verticalPositionPointer = -verticalScrollPosition - 1;

    for (final trackID in trackIDs) {
      final trackHeight = getTrackHeight(
        baseTrackHeight,
        trackHeightModifiers[trackID]!,
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
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }

  @override
  bool shouldRepaint(covariant ArrangerBackgroundPainter oldDelegate) {
    return oldDelegate.baseTrackHeight != baseTrackHeight ||
        oldDelegate.trackHeightModifiers != trackHeightModifiers ||
        oldDelegate.trackIDs != trackIDs ||
        oldDelegate.verticalScrollPosition != verticalScrollPosition ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd;
  }
}
