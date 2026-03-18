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
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _testGradientStops = <MeterGradientStop>[
  (db: -72.0, color: Color(0xFF00FF00)),
  (db: 0.0, color: Color(0xFFFFFF00)),
  (db: 0.0, color: Color(0xFFFF0000)),
  (db: 12.0, color: Color(0xFFFF0000)),
];

const _backgroundTrackColor = Color(0xFF101010);

Widget _buildMeterHarness({
  required StereoMeterValues db,
  required Duration timestamp,
  Duration peakHoldDuration = const Duration(milliseconds: 500),
  double peakFallRateNormalizedPerSecond = 0.96,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 21,
        height: 100,
        child: Meter(
          db: db,
          timestamp: timestamp,
          gradientStops: _testGradientStops,
          peakHoldDuration: peakHoldDuration,
          peakFallRateNormalizedPerSecond: peakFallRateNormalizedPerSecond,
        ),
      ),
    ),
  );
}

MeterPainter _readPainter(WidgetTester tester) {
  return tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
      as MeterPainter;
}

void main() {
  group('dbToPixelHeight', () {
    test('throws when dbToPosition is empty', () {
      expect(
        () => Meter.dbToPixelHeight(0, 100, const []),
        throwsA(isA<StateError>()),
      );
    });

    test('returns zero below the minimum db point', () {
      expect(
        Meter.dbToPixelHeight(-72, 120, const [
          (-60, 0.0),
          (-12, 0.7),
          (0, 1.0),
        ]),
        0.0,
      );
    });

    test('returns the full height above the maximum db point', () {
      expect(
        Meter.dbToPixelHeight(18, 120, const [
          (-60, 0.0),
          (-12, 0.7),
          (0, 1.0),
        ]),
        120.0,
      );
    });

    test('interpolates within the matching segment', () {
      expect(
        Meter.dbToPixelHeight(-6, 120, const [
          (-60, 0.0),
          (-12, 0.6),
          (0, 1.0),
        ]),
        closeTo(96.0, 0.000001),
      );
    });

    test('supports interpolation with a two-point mapping', () {
      expect(
        Meter.dbToPixelHeight(-30, 100, const [(-60, 0.0), (0, 1.0)]),
        closeTo(50.0, 0.000001),
      );
    });
  });

  group('meter helpers', () {
    test('dbToNormalizedHeight uses the configured mapping', () {
      expect(
        Meter.dbToNormalizedHeight(-48, defaultMeterDbToPosition),
        closeTo(0.12, 0.000001),
      );
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
        dbToPosition: defaultMeterDbToPosition,
      );

      expect(resolved.colors, hasLength(4));
      expect(resolved.stops, hasLength(4));
      expect(resolved.stops[0], closeTo(0.03, 0.000001));
      expect(resolved.stops[1], closeTo(0.805, 0.000001));
      expect(resolved.stops[2], closeTo(0.805, 0.000001));
      expect(resolved.stops[3], closeTo(1.0, 0.000001));
    });
  });

  group('Meter', () {
    testWidgets('holds peaks before decaying them from timestamps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildMeterHarness(
          db: (left: -48.0, right: -36.0),
          timestamp: Duration.zero,
        ),
      );

      var painter = _readPainter(tester);
      expect(painter.value.left, closeTo(0.12, 0.000001));
      expect(painter.value.right, closeTo(0.22, 0.000001));
      expect(painter.peak.left, closeTo(0.12, 0.000001));
      expect(painter.peak.right, closeTo(0.22, 0.000001));

      await tester.pumpWidget(
        _buildMeterHarness(
          db: (left: -72.0, right: -72.0),
          timestamp: const Duration(milliseconds: 300),
          peakHoldDuration: const Duration(milliseconds: 500),
          peakFallRateNormalizedPerSecond: 0.1,
        ),
      );

      painter = _readPainter(tester);
      expect(painter.value.left, closeTo(0.03, 0.000001));
      expect(painter.value.right, closeTo(0.03, 0.000001));
      expect(painter.peak.left, closeTo(0.12, 0.000001));
      expect(painter.peak.right, closeTo(0.22, 0.000001));

      await tester.pumpWidget(
        _buildMeterHarness(
          db: (left: -72.0, right: -72.0),
          timestamp: const Duration(seconds: 1),
          peakHoldDuration: const Duration(milliseconds: 500),
          peakFallRateNormalizedPerSecond: 0.1,
        ),
      );

      painter = _readPainter(tester);
      expect(painter.value.left, closeTo(0.03, 0.000001));
      expect(painter.value.right, closeTo(0.03, 0.000001));
      expect(painter.peak.left, closeTo(0.07, 0.000001));
      expect(painter.peak.right, closeTo(0.17, 0.000001));
    });
  });

  group('MeterPainter.shouldRepaint', () {
    test('returns false when painter inputs are unchanged', () {
      final resolved = Meter.resolveGradient(
        gradientStops: _testGradientStops,
        dbToPosition: defaultMeterDbToPosition,
      );
      final oldPainter = MeterPainter(
        value: (left: 0.2, right: 0.4),
        peak: (left: 0.3, right: 0.5),
        gradientColors: resolved.colors,
        gradientStopPositions: resolved.stops,
        backgroundTrackColor: _backgroundTrackColor,
      );
      final newPainter = MeterPainter(
        value: (left: 0.2, right: 0.4),
        peak: (left: 0.3, right: 0.5),
        gradientColors: resolved.colors,
        gradientStopPositions: resolved.stops,
        backgroundTrackColor: _backgroundTrackColor,
      );

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });

    test('returns true when peak values change', () {
      final resolved = Meter.resolveGradient(
        gradientStops: _testGradientStops,
        dbToPosition: defaultMeterDbToPosition,
      );
      final oldPainter = MeterPainter(
        value: (left: 0.2, right: 0.4),
        peak: (left: 0.3, right: 0.5),
        gradientColors: resolved.colors,
        gradientStopPositions: resolved.stops,
        backgroundTrackColor: _backgroundTrackColor,
      );
      final newPainter = MeterPainter(
        value: (left: 0.2, right: 0.4),
        peak: (left: 0.31, right: 0.5),
        gradientColors: resolved.colors,
        gradientStopPositions: resolved.stops,
        backgroundTrackColor: _backgroundTrackColor,
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });
  });
}
