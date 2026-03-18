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

import 'package:anthem/widgets/basic/meter.dart';
import 'package:anthem/widgets/basic/meter_scale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeterScale.formatLabel', () {
    test('formats negative infinity as infinity symbol', () {
      expect(MeterScale.formatLabel(double.negativeInfinity), '-\u221e');
    });

    test('formats whole db values without decimals', () {
      expect(MeterScale.formatLabel(-24), '-24');
      expect(MeterScale.formatLabel(12), '12');
    });
  });

  group('MeterScale.positionForDb', () {
    test('maps the top of the scale to zero', () {
      expect(
        MeterScale.positionForDb(
          db: 12,
          height: 100,
          dbToPosition: defaultMeterDbToPosition,
        ),
        closeTo(0.0, 0.000001),
      );
    });

    test('maps negative infinity to the bottom of the scale', () {
      expect(
        MeterScale.positionForDb(
          db: double.negativeInfinity,
          height: 100,
          dbToPosition: defaultMeterDbToPosition,
        ),
        closeTo(100.0, 0.000001),
      );
    });
  });

  group('meter scale defaults', () {
    test('line tick defaults include 12 through -66', () {
      expect(defaultMeterScaleTickValues.first, 12.0);
      expect(defaultMeterScaleTickValues.last, -66.0);
      expect(defaultMeterScaleTickValues, containsAll(<double>[6.0, -36.0]));
    });

    test('label defaults include infinity marker position', () {
      expect(defaultMeterScaleLabelValues.last, double.negativeInfinity);
    });
  });
}
