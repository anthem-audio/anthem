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

double _identityMeterPosition(double value) => value;

StereoMeterTimestamps _stereoTimestamp(Duration timestamp) =>
    (left: timestamp, right: timestamp);

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
    test('estimates history capacity with 50 percent headroom', () {
      expect(
        MeterValueTracker.estimateHistoryCapacity(
          peakHoldDuration: const Duration(milliseconds: 750),
          estimatedSamplesPerSecond: 60,
        ),
        68,
      );
      expect(
        MeterValueTracker.estimateHistoryCapacity(
          peakHoldDuration: const Duration(milliseconds: 750),
          estimatedSamplesPerSecond: 240,
        ),
        270,
      );
    });

    test('holds peaks before decaying them from timestamps', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: defaultMeterDbToNormalizedPosition,
        peakHoldDuration: const Duration(milliseconds: 500),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      var snapshot = tracker.resolve(
        db: (left: -48.0, right: -36.0),
        timestamps: (left: Duration.zero, right: Duration.zero),
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
        timestamps: (
          left: const Duration(milliseconds: 300),
          right: const Duration(milliseconds: 300),
        ),
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
        timestamps: (
          left: const Duration(seconds: 1),
          right: const Duration(seconds: 1),
        ),
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
        closeTo(gainDbToParameterValue(-48) - 0.07, 0.000001),
      );
      expect(
        snapshot.peakNormalized.right,
        closeTo(gainParameterCurveSectionCeilingNormalized - 0.07, 0.000001),
      );
    });

    test('rate-limits decreases in the recent maximum', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(Duration.zero),
      );
      tracker.resolve(
        db: (left: 0.79, right: 0.79),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 900)),
      );

      var snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(seconds: 1)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.79, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.79, 0.000001));

      snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 1800)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.79, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.79, 0.000001));

      snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 1900)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.78, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.78, 0.000001));
    });

    test('uses elapsed engine time when updates arrive late', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(Duration.zero),
      );
      tracker.resolve(
        db: (left: 0.79, right: 0.79),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 900)),
      );
      tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(seconds: 1)),
      );

      final snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(seconds: 2)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.69, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.69, 0.000001));
    });

    test('jumps immediately to an increasing recent maximum', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(milliseconds: 100),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(Duration.zero),
      );
      tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 100)),
      );

      final snapshot = tracker.resolve(
        db: (left: 0.9, right: 0.9),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 200)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.9, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.9, 0.000001));
    });

    test('equal values refresh their hold timestamp', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(Duration.zero),
      );
      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(const Duration(milliseconds: 500)),
      );

      final snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: _stereoTimestamp(const Duration(seconds: 1)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.8, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.8, 0.000001));
    });

    test('tracks stereo engine timestamps independently', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.6),
        timestamps: _stereoTimestamp(Duration.zero),
      );
      tracker.resolve(
        db: (left: 0.1, right: 0.6),
        timestamps: (left: const Duration(seconds: 1), right: Duration.zero),
      );

      final snapshot = tracker.resolve(
        db: (left: 0.1, right: 0.1),
        timestamps: (
          left: const Duration(seconds: 1),
          right: const Duration(milliseconds: 500),
        ),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.7, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.6, 0.000001));
    });

    test('grows history without losing retained samples', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
        estimatedSamplesPerSecond: 1,
      );

      for (var i = 0; i < 100; i++) {
        tracker.resolve(
          db: (left: 1 - i * 0.005, right: 1 - i * 0.005),
          timestamps: _stereoTimestamp(Duration(milliseconds: i * 9)),
        );
      }

      final snapshot = tracker.resolve(
        db: (left: 0.0, right: 0.0),
        timestamps: _stereoTimestamp(const Duration(seconds: 1)),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.995, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.995, 0.000001));
    });

    test('resets a channel when its engine timestamp moves backward', () {
      final tracker = MeterValueTracker(
        dbToNormalizedPosition: _identityMeterPosition,
        peakHoldDuration: const Duration(seconds: 1),
        peakFallRateNormalizedPerSecond: 0.1,
      );

      tracker.resolve(
        db: (left: 0.8, right: 0.8),
        timestamps: _stereoTimestamp(const Duration(seconds: 1)),
      );

      final snapshot = tracker.resolve(
        db: (left: 0.2, right: 0.3),
        timestamps: _stereoTimestamp(Duration.zero),
      );

      expect(snapshot.peakNormalized.left, closeTo(0.2, 0.000001));
      expect(snapshot.peakNormalized.right, closeTo(0.3, 0.000001));
    });
  });
}
