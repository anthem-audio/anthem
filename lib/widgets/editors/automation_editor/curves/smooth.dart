/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'dart:math' as math;

import 'package:anthem/helpers/bw_fast_math.dart';

double linearCenterTransitionRate = 0.27;
double linearCenterWidth = 1.6;

double _g(double x) {
  return math.atan(x * linearCenterTransitionRate * math.pi) / math.pi + 0.5;
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
  final linearCenterInterpolation = _getLinearCenterInterpolation(tension);

  var powValue = 0.0;
  if (tension > 0) {
    powValue = _powPositive(tension / 2, 2.2);
  } else if (tension < 0) {
    powValue = -_powPositive(-tension / 2, 2.2);
  }

  return powValue * linearCenterInterpolation +
      0.7 * tension * (1 - linearCenterInterpolation);
}

double _powPositive(double base, double exponent) {
  if (base == 0.0) {
    return 0.0;
  }

  return bwExp(exponent * bwLog(base));
}

double evaluateSmooth(double normalizedX, double tension) {
  final rawTension = _getRawTension(tension * 15);
  if (tension >= 0) {
    return _powPositive(normalizedX, rawTension + 1);
  } else {
    return 1 - _powPositive(1 - normalizedX, -rawTension + 1);
  }
}
