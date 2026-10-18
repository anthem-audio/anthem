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

import 'package:anthem/widgets/project/tempo_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no estimate or timeout until two taps; averages all intervals', () {
    final session = TapTempoSession(12800);
    expect(session.completionDelay, isNull);
    expect(session.addTap(Duration.zero), isNull);
    expect(session.completionDelay, isNull);
    expect(session.addTap(const Duration(milliseconds: 400)), 15000);
    expect(session.addTap(const Duration(seconds: 1)), 12000);
    expect(session.completionDelay, const Duration(seconds: 2));
    expect(session.originalTempoRaw, 12800);
  });

  test('uses the last 16 taps once the window is full', () {
    final session = TapTempoSession(12800);
    session.addTap(Duration.zero);
    session.addTap(const Duration(seconds: 6));
    for (var i = 1; i <= 15; i++) {
      session.addTap(Duration(milliseconds: 6000 + i * 500));
    }
    // The initial six-second interval is outside the latest 16 taps.
    expect(session.estimatedTempoRaw, 12000);
  });

  test('rounds to the nearest whole BPM, including halfway values', () {
    for (final (interval, expected) in [
      (const Duration(microseconds: 499500), 12000), // 120.12 rounds down.
      (const Duration(microseconds: 496000), 12100), // 120.97 rounds up.
      (const Duration(milliseconds: 4800), 1300), // 12.5 rounds up.
    ]) {
      final session = TapTempoSession(12837)..addTap(Duration.zero);
      expect(session.addTap(interval), expected);
      expect(session.originalTempoRaw, 12837);
    }
  });

  test(
    'clamps to the existing tempo range and uses that tempo for timeout',
    () {
      final fast = TapTempoSession(12800)..addTap(Duration.zero);
      expect(fast.addTap(const Duration(milliseconds: 1)), 99900);
      expect(fast.completionDelay!.inMicroseconds, closeTo(240240, 1));

      final slow = TapTempoSession(12800)..addTap(Duration.zero);
      expect(slow.addTap(const Duration(seconds: 60)), 1000);
      expect(slow.completionDelay, const Duration(seconds: 24));
    },
  );

  test(
    'ignores duplicate and decreasing timestamps without losing history',
    () {
      final session = TapTempoSession(12800);
      session.addTap(const Duration(seconds: 1));
      expect(session.addTap(const Duration(seconds: 1)), isNull);
      expect(session.addTap(Duration.zero), isNull);
      expect(session.addTap(const Duration(milliseconds: 1500)), 12000);
      expect(session.addTap(const Duration(milliseconds: 1400)), isNull);
      expect(session.addTap(const Duration(seconds: 2)), 12000);
    },
  );
}
