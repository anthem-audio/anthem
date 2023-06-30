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

import 'dart:math';

double linearCenterTransitionRate = 0.27;
double linearCenterWidth = 1.6;

double _g(double x) {
  return atan(x * linearCenterTransitionRate * pi) / pi + 0.5;
}

double _getLinearCenterInterpolation(double tension) {
  return 1 -
      (_g(tension + linearCenterWidth) +
          (1 - _g(tension - linearCenterWidth)) -
          1);
}

/// Returns values similar to the input near 0, and grows as tension moves away
/// from 0.
double _getRawTension(double tension) {
  double linearCenterInterpolation = _getLinearCenterInterpolation(tension);

  return pow(tension / 2, 2.2).toDouble() * linearCenterInterpolation +
      0.7 * tension * (1 - linearCenterInterpolation);
}

double evaluateSmooth(double normalizedX, double tension) {
  final rawTension = _getRawTension(tension * 10);
  if (tension >= 0) {
    return pow(normalizedX, rawTension + 1).toDouble();
  } else {
    return 1 - pow(1 - normalizedX, -rawTension + 1).toDouble();
  }
}
