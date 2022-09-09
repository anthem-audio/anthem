/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';

// All vertical lines plus every-four-bars shading
void paintTimeGrid({
  required Canvas canvas,
  required Size size,
  required int ticksPerQuarter,
  required Snap snap,
  required TimeSignatureModel? baseTimeSignature,
  required List<TimeSignatureChangeModel> timeSignatureChanges,
  required double timeViewStart,
  required double timeViewEnd,
}) {
  final shadedPaint = Paint()..color = Theme.grid.shaded;
  final accentLinePaint = Paint()..color = Theme.grid.accent;
  final majorLinePaint = Paint()..color = Theme.grid.major;
  final minorLinePaint = Paint()..color = Theme.grid.minor;

  final minorDivisionChanges = getDivisionChanges(
    viewWidthInPixels: size.width,
    minPixelsPerSection: minorMinPixels,
    snap: snap,
    defaultTimeSignature: baseTimeSignature, // TODO
    timeSignatureChanges: [],
    ticksPerQuarter: ticksPerQuarter,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
  );

  paintVerticalLines(
    canvas: canvas,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    divisionChanges: minorDivisionChanges,
    size: size,
    paint: minorLinePaint,
  );

  final majorDivisionChanges = getDivisionChanges(
    viewWidthInPixels: size.width,
    minPixelsPerSection: majorMinPixels,
    snap: snap,
    defaultTimeSignature: baseTimeSignature,
    timeSignatureChanges: timeSignatureChanges,
    ticksPerQuarter: ticksPerQuarter,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
  );

  paintVerticalLines(
    canvas: canvas,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    divisionChanges: majorDivisionChanges,
    size: size,
    paint: majorLinePaint,
  );

  final barDivisionChanges = getDivisionChanges(
    viewWidthInPixels: size.width,
    minPixelsPerSection: majorMinPixels,
    snap: BarSnap(),
    defaultTimeSignature: baseTimeSignature,
    timeSignatureChanges: timeSignatureChanges,
    ticksPerQuarter: ticksPerQuarter,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
  );

  paintVerticalLines(
    canvas: canvas,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    divisionChanges: barDivisionChanges,
    size: size,
    paint: accentLinePaint,
  );

  const phraseDivisionSnapMultiplier = 4 * 4;

  final phraseDivisionChanges = getDivisionChanges(
    viewWidthInPixels: size.width,
    minPixelsPerSection: majorMinPixels,
    snap: DivisionSnap(
      division: Division(multiplier: phraseDivisionSnapMultiplier, divisor: 1),
    ),
    defaultTimeSignature: baseTimeSignature,
    timeSignatureChanges: timeSignatureChanges,
    ticksPerQuarter: ticksPerQuarter,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
  );

  paintVerticalLines(
    canvas: canvas,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    divisionChanges: phraseDivisionChanges,
    size: size,
    paint: shadedPaint,
    paintAcrossDivision: true,
    skipOddLines: true,
    skipWhenZoomedOut: true,
  );
}

void paintVerticalLines({
  required Canvas canvas,
  required double timeViewStart,
  required double timeViewEnd,
  required List<DivisionChange> divisionChanges,
  required Size size,
  required Paint paint,

  // I'm coopting this function to draw the shaded regions every four bars.
  // This is a bit of a hacky way to do it, but it saves duplicating some
  // pretty dense code.
  //
  // By default the line width is 1 pixel. The changes we make to draw the
  // shaded regions are:
  //   - A flag to fill the whole division, as opposed to painting a 1-pixel-
  //     wide line.
  //   - A flag to skip every other line.
  //   - A flag to skip the whole division if its skip value is greater than 1.
  bool paintAcrossDivision = false,
  bool skipOddLines = false,
  bool skipWhenZoomedOut = false,
}) {
  var i = 0;
  // There should always be at least one division change. The first change
  // should always represent the base time signature for the pattern (or the
  // first time signature change, if its position is 0).
  var timePtr =
      (timeViewStart / divisionChanges[0].divisionRenderSize).floor() *
          divisionChanges[0].divisionRenderSize;

  while (timePtr < timeViewEnd) {
    var skip = true;

    // This shouldn't happen, but safety first
    if (i >= divisionChanges.length) break;

    var thisDivision = divisionChanges[i];
    var nextDivisionStart = 0x4000000000000000; // int max / 2

    if (i < divisionChanges.length - 1) {
      nextDivisionStart = divisionChanges[i + 1].offset;
    }

    bool shouldSkipDivision = false;

    // Skip this division if the time pointer is past its end
    shouldSkipDivision = shouldSkipDivision || timePtr >= nextDivisionStart;

    // Skip this division if we're too zoomed out and the skip when zoomed out
    // flag is true
    shouldSkipDivision = shouldSkipDivision ||
        (skipWhenZoomedOut && thisDivision.distanceBetween > 1);

    if (shouldSkipDivision) {
      timePtr = nextDivisionStart;
      i++;
      continue;
    }

    while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
      final isOdd =
          ((timePtr - thisDivision.offset) ~/ thisDivision.divisionRenderSize) %
                  2 ==
              0;
      if (skipOddLines && isOdd) {
        timePtr += thisDivision.divisionRenderSize;
        skip = !skip;
        continue;
      }

      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: timePtr.toDouble(),
      );

      final width = !paintAcrossDivision
          ? 1.0
          : timeToPixels(
              timeViewStart: 0,
              timeViewEnd: timeViewEnd - timeViewStart,
              viewPixelWidth: size.width,
              time: thisDivision.divisionRenderSize
                  .clamp(1, nextDivisionStart - timePtr)
                  .toDouble(),
            );

      canvas.drawRect(
        Rect.fromLTWH(x, 0, width, size.height),
        paint,
      );

      timePtr += thisDivision.divisionRenderSize;
      skip = !skip;

      // If this is true, then this is the last iteration of the inner loop
      if (timePtr >= nextDivisionStart) {
        timePtr = nextDivisionStart;
      }
    }

    i++;
  }
}
