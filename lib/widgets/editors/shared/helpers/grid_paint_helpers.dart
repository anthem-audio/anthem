/*
  Copyright (C) 2021 - 2023 Joshua Wade

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
  required TimeSignatureModel baseTimeSignature,
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

  paintPhraseShading(
    canvas: canvas,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    defaultTimeSignature: baseTimeSignature,
    timeSignatureChanges: timeSignatureChanges,
    size: size,
    paint: shadedPaint,
    ticksPerQuarter: ticksPerQuarter,
  );
}

void paintVerticalLines({
  required Canvas canvas,
  required double timeViewStart,
  required double timeViewEnd,
  required List<DivisionChange> divisionChanges,
  required Size size,
  required Paint paint,
}) {
  var i = 0;
  // There should always be at least one division change. The first change
  // should always represent the base time signature for the pattern (or the
  // first time signature change, if its position is 0).
  var timePtr =
      (timeViewStart / divisionChanges[0].divisionRenderSize).floor() *
          divisionChanges[0].divisionRenderSize;

  while (timePtr < timeViewEnd) {
    // This shouldn't happen, but safety first
    if (i >= divisionChanges.length) break;

    var thisDivision = divisionChanges[i];
    var nextDivisionStart = 0x4000000000000000; // int max / 2

    if (i < divisionChanges.length - 1) {
      nextDivisionStart = divisionChanges[i + 1].offset;
    }

    if (timePtr >= nextDivisionStart) {
      timePtr = nextDivisionStart;
      i++;
      continue;
    }

    while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: timePtr.toDouble(),
      );

      canvas.drawRect(
        Rect.fromLTWH(x, 0, 1, size.height),
        paint,
      );

      timePtr += thisDivision.divisionRenderSize;

      // If this is true, then this is the last iteration of the inner loop
      if (timePtr >= nextDivisionStart) {
        timePtr = nextDivisionStart;
      }
    }

    i++;
  }
}

void paintPhraseShading({
  required Canvas canvas,
  required double timeViewStart,
  required double timeViewEnd,
  required TimeSignatureModel defaultTimeSignature,
  required List<TimeSignatureChangeModel> timeSignatureChanges,
  required Size size,
  required Paint paint,
  required int ticksPerQuarter,
}) {
  var tick = 0;
  var shadeThisPhrase = false;
  var timeSignatureIndex = 0;

  var timeSignatures =
      timeSignatureChanges.isEmpty || timeSignatureChanges[0].offset > 0
          ? [
              TimeSignatureChangeModel(
                  timeSignature: defaultTimeSignature, offset: 0),
              ...timeSignatureChanges
            ]
          : timeSignatureChanges;

  while (tick < timeViewEnd) {
    final timeSignatureChange = timeSignatures[timeSignatureIndex];
    final timeSignature = timeSignatureChange.timeSignature;

    final barSize = timeSignature.numerator *
        (ticksPerQuarter * 4) ~/
        timeSignature.denominator;

    final nextTimeSignatureChangeOffset =
        timeSignatureIndex + 1 >= timeSignatures.length
            ? 0x7FFFFFFFFFFFFFFF
            : timeSignatures[timeSignatureIndex + 1].offset;

    var phraseWidth = barSize * 4;
    if (tick + phraseWidth > nextTimeSignatureChangeOffset) {
      phraseWidth -= tick + phraseWidth - nextTimeSignatureChangeOffset;
    }

    final startX = timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: size.width,
      time: tick.toDouble(),
    );

    final endX = timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: size.width,
      time: (tick + phraseWidth).toDouble(),
    );

    // If it's actually on screen
    if (tick <= timeViewEnd && tick + phraseWidth >= timeViewStart) {
      // If it should be shaded
      if (shadeThisPhrase) {
        canvas.drawRect(
          Rect.fromLTWH(startX, 0, endX - startX, size.height),
          paint,
        );
      }
    }

    tick += phraseWidth;
    shadeThisPhrase = !shadeThisPhrase;
    if (tick >= nextTimeSignatureChangeOffset) {
      timeSignatureIndex++;
      tick = nextTimeSignatureChangeOffset;
    }
  }
}
