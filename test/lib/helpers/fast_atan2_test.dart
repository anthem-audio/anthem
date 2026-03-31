/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/helpers/fast_atan2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fastAtan2', () {
    test('returns 0 for (0, 0)', () {
      expect(fastAtan2(0, 0), equals(0.0));
    });

    test('stays close to dart:math atan2 across octants', () {
      const tolerance = 0.0041;
      const values = <double>[-10, -3, -1, -0.25, 0, 0.25, 1, 3, 10];

      for (final y in values) {
        for (final x in values) {
          if (x == 0 && y == 0) {
            continue;
          }

          final expected = atan2(y, x);
          final actual = fastAtan2(y, x);
          final error = (actual - expected).abs();

          expect(
            error,
            lessThan(tolerance),
            reason: 'x=$x y=$y expected=$expected actual=$actual error=$error',
          );
        }
      }
    });
  });
}
