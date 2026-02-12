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

import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter_test/flutter_test.dart';

TimeSignatureChangeModel _change({
  required int offset,
  required int numerator,
  required int denominator,
}) {
  return TimeSignatureChangeModel(
    offset: offset,
    timeSignature: TimeSignatureModel(numerator, denominator),
  );
}

DivisionChange _divisionChange({required int offset, required int snapSize}) {
  return DivisionChange(
    offset: offset,
    divisionRenderSize: snapSize,
    divisionSnapSize: snapSize,
    distanceBetween: 1,
    startLabel: 1,
  );
}

void main() {
  group('timeToPixels / pixelsToTime', () {
    test('maps values linearly and round-trips', () {
      final px = timeToPixels(
        timeViewStart: 100,
        timeViewEnd: 200,
        viewPixelWidth: 1000,
        time: 150,
      );

      expect(px, 500);

      final time = pixelsToTime(
        timeViewStart: 100,
        timeViewEnd: 200,
        viewPixelWidth: 1000,
        pixelOffsetFromLeft: px,
      );

      expect(time, 150);
    });

    test('supports out-of-range values', () {
      final left = timeToPixels(
        timeViewStart: 100,
        timeViewEnd: 200,
        viewPixelWidth: 1000,
        time: 50,
      );
      final right = pixelsToTime(
        timeViewStart: 100,
        timeViewEnd: 200,
        viewPixelWidth: 1000,
        pixelOffsetFromLeft: 1500,
      );

      expect(left, -500);
      expect(right, 250);
    });
  });

  group('getBarLength', () {
    test('falls back to 4/4 when signature is null', () {
      expect(getBarLength(480, null), 1920);
    });

    test('computes length from explicit signature', () {
      expect(getBarLength(480, TimeSignatureModel(3, 4)), 1440);
      expect(getBarLength(480, TimeSignatureModel(7, 8)), 1680);
    });
  });

  group('allPrimesUntil / factors', () {
    test('returns expected primes for typical upper bounds', () {
      expect(allPrimesUntil(20), [2, 3, 5, 7, 11, 13, 17, 19]);
    });

    test('keeps current lower-bound behavior', () {
      expect(allPrimesUntil(1), [2]);
      expect(() => allPrimesUntil(0), throwsA(isA<RangeError>()));
    });

    test('factorizes composite and prime numbers', () {
      expect(factors(30), [2, 3, 5]);
      expect(factors(48), [2, 2, 2, 2, 3]);
      expect(factors(13), [13]);
    });

    test('returns empty factors for x <= 1', () {
      expect(factors(1), isEmpty);
      expect(factors(0), isEmpty);
      expect(factors(-5), isEmpty);
    });
  });

  group('getBestDivision', () {
    test('uses bar length for bar snap', () {
      final result = getBestDivision(
        timeSignature: TimeSignatureModel(4, 4),
        snap: BarSnap(),
        ticksPerPixel: 1,
        minPixelsPerDivision: 18,
        ticksPerQuarter: 480,
      );

      expect(result.renderSize, 1920);
      expect(result.snapSize, 1920);
      expect(result.skip, 1);
    });

    test('uses 1/16 divisions for auto snap when zoomed in', () {
      final result = getBestDivision(
        timeSignature: TimeSignatureModel(4, 4),
        snap: AutoSnap(),
        ticksPerPixel: 0.5,
        minPixelsPerDivision: 18,
        ticksPerQuarter: 480,
      );

      expect(result.renderSize, 120);
      expect(result.snapSize, 120);
      expect(result.skip, 1);
    });

    test('respects skipBottomNDivisions for auto snap', () {
      final result = getBestDivision(
        timeSignature: TimeSignatureModel(4, 4),
        snap: AutoSnap(),
        ticksPerPixel: 0.5,
        minPixelsPerDivision: 18,
        ticksPerQuarter: 480,
        skipBottomNDivisions: 1,
      );

      expect(result.renderSize, 240);
      expect(result.snapSize, 240);
      expect(result.skip, 1);
    });

    test(
      'keeps snap size stable for division snap while render size grows',
      () {
        final result = getBestDivision(
          timeSignature: TimeSignatureModel(4, 4),
          snap: DivisionSnap(division: Division(multiplier: 1, divisor: 2)),
          ticksPerPixel: 20,
          minPixelsPerDivision: 30,
          ticksPerQuarter: 480,
        );

        expect(result.renderSize, 960);
        expect(result.snapSize, 240);
        expect(result.skip, 1);
      },
    );
  });

  group('getDivisionChanges', () {
    test('returns empty when view width is < 1', () {
      final result = getDivisionChanges(
        viewWidthInPixels: 0.5,
        snap: AutoSnap(),
        defaultTimeSignature: TimeSignatureModel(4, 4),
        timeSignatureChanges: [],
        ticksPerQuarter: 480,
        timeViewStart: 0,
        timeViewEnd: 1920,
      );

      expect(result, isEmpty);
    });

    test(
      'adds default change at offset 0 when first explicit change is later',
      () {
        final result = getDivisionChanges(
          viewWidthInPixels: 1920,
          snap: AutoSnap(),
          defaultTimeSignature: TimeSignatureModel(4, 4),
          timeSignatureChanges: [
            _change(offset: 2880, numerator: 3, denominator: 4),
          ],
          ticksPerQuarter: 480,
          timeViewStart: 0,
          timeViewEnd: 1920,
        );

        expect(result.length, 2);
        expect(result[0].offset, 0);
        expect(result[0].startLabel, 1);
        expect(result[1].offset, 2880);
        expect(result[1].startLabel, 3);
      },
    );

    test('does not insert an extra default when first change is at 0', () {
      final result = getDivisionChanges(
        viewWidthInPixels: 1920,
        snap: AutoSnap(),
        defaultTimeSignature: TimeSignatureModel(4, 4),
        timeSignatureChanges: [
          _change(offset: 0, numerator: 3, denominator: 4),
          _change(offset: 2880, numerator: 4, denominator: 4),
        ],
        ticksPerQuarter: 480,
        timeViewStart: 0,
        timeViewEnd: 1920,
      );

      expect(result.length, 2);
      expect(result[0].offset, 0);
      expect(result[0].startLabel, 1);
      expect(result[1].offset, 2880);
      expect(result[1].startLabel, 3);
    });
  });

  group('getSnappedTime', () {
    test('floors to snap boundary by default', () {
      final snapped = getSnappedTime(
        rawTime: 179,
        divisionChanges: [_divisionChange(offset: 0, snapSize: 120)],
      );

      expect(snapped, 120);
    });

    test('supports ceil and round modes', () {
      final divisionChanges = [_divisionChange(offset: 0, snapSize: 120)];

      expect(
        getSnappedTime(
          rawTime: 179,
          divisionChanges: divisionChanges,
          ceil: true,
        ),
        240,
      );
      expect(
        getSnappedTime(
          rawTime: 179,
          divisionChanges: divisionChanges,
          round: true,
        ),
        120,
      );
      expect(
        getSnappedTime(
          rawTime: 180,
          divisionChanges: divisionChanges,
          round: true,
        ),
        240,
      );
    });

    test('preserves start-time offset from snap boundaries', () {
      final divisionChanges = [_divisionChange(offset: 0, snapSize: 120)];

      expect(
        getSnappedTime(
          rawTime: 179,
          divisionChanges: divisionChanges,
          startTime: 30,
        ),
        150,
      );
      expect(
        getSnappedTime(
          rawTime: 179,
          divisionChanges: divisionChanges,
          startTime: 30,
          ceil: true,
        ),
        270,
      );
    });

    test('uses the active division section based on offsets', () {
      final snapped = getSnappedTime(
        rawTime: 1199,
        divisionChanges: [
          _divisionChange(offset: 0, snapSize: 120),
          _divisionChange(offset: 1000, snapSize: 300),
        ],
      );

      expect(snapped, 1000);
    });
  });

  group('zoomTimeView', () {
    test('keeps cursor anchor stable when unclamped', () {
      final timeView = TimeRange(10000, 11000);
      final beforeAtCursor = timeView.start + timeView.width * (250.0 / 1000.0);

      zoomTimeView(
        timeView: timeView,
        delta: 300,
        mouseX: 250,
        editorWidth: 1000,
      );

      final afterAtCursor = timeView.start + timeView.width * (250.0 / 1000.0);

      expect(afterAtCursor, closeTo(beforeAtCursor, 1e-9));
    });

    test('enforces minimum width of 10', () {
      final timeView = TimeRange(0, 20);

      zoomTimeView(
        timeView: timeView,
        delta: -100000,
        mouseX: 500,
        editorWidth: 1000,
      );

      expect(timeView.width, 10);
    });

    test('clamps start to non-negative values', () {
      final timeView = TimeRange(5, 15);

      zoomTimeView(
        timeView: timeView,
        delta: 4000,
        mouseX: 500,
        editorWidth: 1000,
      );

      expect(timeView.start, 0);
      expect(timeView.end, greaterThan(timeView.start));
    });

    test('zoom in then out returns to original range when unclamped', () {
      final timeView = TimeRange(10000, 11000);

      zoomTimeView(
        timeView: timeView,
        delta: 200,
        mouseX: 500,
        editorWidth: 1000,
      );
      zoomTimeView(
        timeView: timeView,
        delta: -200,
        mouseX: 500,
        editorWidth: 1000,
      );

      expect(timeView.start, closeTo(10000, 1e-9));
      expect(timeView.end, closeTo(11000, 1e-9));
    });
  });
}
