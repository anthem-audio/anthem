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

import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import '../../piano_roll/helpers.dart';

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
    var nextDivisionStart = 0x7FFFFFFFFFFFFFFF; // int max

    if (i < divisionChanges.length - 1) {
      nextDivisionStart = divisionChanges[i + 1].offset;
    }

    if (timePtr >= nextDivisionStart) {
      timePtr = nextDivisionStart;
      i++;
      continue;
    }

    while (timePtr < nextDivisionStart && timePtr < timeViewEnd) {
      var x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: timePtr.toDouble());

      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);

      timePtr += thisDivision.divisionRenderSize;
    }

    i++;
  }
}
