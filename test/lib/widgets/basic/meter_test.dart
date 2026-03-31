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
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _testGradientStops = <MeterGradientStop>[
  (db: -72.0, color: Color(0xFF00FF00)),
  (db: 0.0, color: Color(0xFFFFFF00)),
  (db: 0.0, color: Color(0xFFFF0000)),
  (db: 12.0, color: Color(0xFFFF0000)),
];

double _testDbToNormalizedPosition(double db) {
  if (db <= -60.0) {
    return 0.0;
  }

  if (db >= 0.0) {
    return 1.0;
  }

  return (db + 60.0) / 60.0;
}

void main() {
  group('dbToPixelHeight', () {
    test('returns zero below the minimum point', () {
      expect(Meter.dbToPixelHeight(-72, 120, _testDbToNormalizedPosition), 0.0);
    });

    test('returns the full height above the maximum point', () {
      expect(
        Meter.dbToPixelHeight(18, 120, _testDbToNormalizedPosition),
        120.0,
      );
    });

    test('uses the provided conversion function', () {
      expect(
        Meter.dbToPixelHeight(-6, 120, _testDbToNormalizedPosition),
        closeTo(108.0, 0.000001),
      );
    });
  });

  group('meter helpers', () {
    test('dbToNormalizedHeight uses the shared gain mapping by default', () {
      expect(
        Meter.dbToNormalizedHeight(-48, defaultMeterDbToNormalizedPosition),
        closeTo(gainDbToParameterValue(-48), 0.000001),
      );
    });

    test('default meter mapping treats -600 dB wire values as silence', () {
      expect(defaultMeterDbToNormalizedPosition(-600.0), 0.0);
    });

    test('decayMeterPeakNormalizedHeight falls and clamps to current', () {
      expect(
        Meter.decayPeakNormalizedHeight(
          currentNormalizedHeight: 0.05,
          previousPeakNormalizedHeight: 0.165,
          elapsed: const Duration(seconds: 1),
          fallRateNormalizedPerSecond: 0.1,
        ),
        closeTo(0.065, 0.000001),
      );
    });

    test('resolveMeterGradient converts db stops using the meter mapping', () {
      final resolved = Meter.resolveGradient(
        gradientStops: _testGradientStops,
        dbToNormalizedPosition: defaultMeterDbToNormalizedPosition,
      );

      expect(resolved.colors, hasLength(4));
      expect(resolved.stops, hasLength(4));
      expect(resolved.stops[0], closeTo(gainDbToParameterValue(-72), 0.000001));
      expect(
        resolved.stops[1],
        closeTo(gainParameterZeroDbNormalized, 0.000001),
      );
      expect(
        resolved.stops[2],
        closeTo(gainParameterZeroDbNormalized, 0.000001),
      );
      expect(resolved.stops[3], closeTo(1.0, 0.000001));
    });
  });

  group('MeterValueTracker', () {
    test('holds peaks before decaying them from timestamps', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: defaultMeterDbToNormalizedPosition,
        peakHoldDuration: const Duration(milliseconds: 500),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      var snapshot = tracker.resolve(
        db: (left: -48.0, right: -36.0),
        timestamp: Duration.zero,
      );

      expect(
        snapshot.currentNormalized.left,
        closeTo(gainDbToParameterValue(-48), 0.000001),
      );
      expect(
        snapshot.currentNormalized.right,
        closeTo(gainParameterCurveSectionCeilingNormalized, 0.000001),
      );
      expect(
        snapshot.peakNormalized.left,
        closeTo(gainDbToParameterValue(-48), 0.000001),
      );
      expect(
        snapshot.peakNormalized.right,
        closeTo(gainParameterCurveSectionCeilingNormalized, 0.000001),
      );

      snapshot = tracker.resolve(
        db: (left: -72.0, right: -72.0),
        timestamp: const Duration(milliseconds: 300),
      );

      expect(
        snapshot.currentNormalized.left,
        closeTo(gainDbToParameterValue(-72), 0.000001),
      );
      expect(
        snapshot.currentNormalized.right,
        closeTo(gainDbToParameterValue(-72), 0.000001),
      );
      expect(
        snapshot.peakNormalized.left,
        closeTo(gainDbToParameterValue(-48), 0.000001),
      );
      expect(
        snapshot.peakNormalized.right,
        closeTo(gainParameterCurveSectionCeilingNormalized, 0.000001),
      );

      snapshot = tracker.resolve(
        db: (left: -72.0, right: -72.0),
        timestamp: const Duration(seconds: 1),
      );

      expect(
        snapshot.currentNormalized.left,
        closeTo(gainDbToParameterValue(-72), 0.000001),
      );
      expect(
        snapshot.currentNormalized.right,
        closeTo(gainDbToParameterValue(-72), 0.000001),
      );
      expect(
        snapshot.peakNormalized.left,
        closeTo(gainDbToParameterValue(-48) - 0.05, 0.000001),
      );
      expect(
        snapshot.peakNormalized.right,
        closeTo(gainParameterCurveSectionCeilingNormalized - 0.05, 0.000001),
      );
    });
  });
}
