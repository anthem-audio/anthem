/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/shared/helpers/grid_paint_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:flutter/widgets.dart';

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.ticksPerQuarter,
    required this.defaultTimeSignature,
    required this.timeSignatureChanges,
  });

  final double timeViewStart;
  final double timeViewEnd;
  final int ticksPerQuarter;
  final TimeSignatureModel defaultTimeSignature;
  final List<TimeSignatureChangeModel> timeSignatureChanges;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a bottom border - we don't make this a separate widget because we
    // want to draw the playhead line on top of it.
    final borderPaint = Paint()
      ..color = AnthemTheme.panel.border
      ..style = PaintingStyle.fill;

    final markerPaint = Paint()
      ..color = const Color(0xFF696969)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      borderPaint,
    );

    // Line to separate numbers and tick marks
    canvas.drawRect(
      Rect.fromLTWH(0, loopAreaHeight, size.width, 1),
      borderPaint,
    );

    final minorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: minorMinPixels,
      snap: AutoSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: minorDivisionChanges,
      size: Size(size.width, size.height - 1),
      paint: markerPaint,
      height: 5,
    );

    final majorDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: majorMinPixels,
      snap: AutoSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,

      // When zoomed in, this means major tick marks will always be drawn less
      // frequently than minor tick marks.
      skipBottomNDivisions: 1,
    );

    paintVerticalLines(
      canvas: canvas,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      divisionChanges: majorDivisionChanges,
      size: Size(size.width, size.height - 1),
      paint: markerPaint,
      height: 13,
    );

    var barDivisionChanges = getDivisionChanges(
      viewWidthInPixels: size.width,
      minPixelsPerSection: barMinPixels,
      snap: BarSnap(),
      defaultTimeSignature: defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges,
      ticksPerQuarter: ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );

    var i = 0;
    var timePtr = 0;
    var barNumber = barDivisionChanges[0].startLabel;

    barNumber +=
        (timePtr /
                (barDivisionChanges[0].divisionRenderSize /
                    barDivisionChanges[0].distanceBetween))
            .floor();

    while (timePtr < timeViewEnd) {
      // This shouldn't happen, but safety first
      if (i >= barDivisionChanges.length) break;

      final thisDivision = barDivisionChanges[i];
      var nextDivisionStart = 0x001F_FFFF_FFFF_FFFF; // Max safe integer for web

      if (i < barDivisionChanges.length - 1) {
        nextDivisionStart = barDivisionChanges[i + 1].offset;
      }

      while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: timePtr.toDouble(),
        );

        // Don't draw numbers that are off-screen
        if (x >= -50) {
          // Vertical line for bar - skip bar 1, because it looks weird
          if (barNumber > 1) {
            canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), markerPaint);
          }

          // Bar number
          TextSpan span = TextSpan(
            style: TextStyle(
              color: const Color(0xFFB4B4B4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            text: barNumber.toString(),
          );
          TextPainter textPainter = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x + 5, 1));
        }

        timePtr += thisDivision.divisionRenderSize;
        barNumber += thisDivision.distanceBetween;

        // If this is true, then this is the last iteration of the inner loop
        if (timePtr >= nextDivisionStart) {
          timePtr = nextDivisionStart;
          barNumber = barDivisionChanges[i + 1].startLabel;
        }
      }

      i++;
    }
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) {
    return oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.timeViewEnd != timeViewEnd ||
        oldDelegate.ticksPerQuarter != ticksPerQuarter ||
        oldDelegate.defaultTimeSignature != defaultTimeSignature ||
        oldDelegate.timeSignatureChanges != timeSignatureChanges;
  }

  @override
  bool shouldRebuildSemantics(TimelinePainter oldDelegate) => false;
}
