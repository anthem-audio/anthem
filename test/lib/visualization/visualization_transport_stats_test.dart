/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'package:anthem/visualization/src/visualization_transport_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'VisualizationTransportStats computes delay and thresholds directly',
    () {
      var wallClock = Duration.zero;
      final stats = VisualizationTransportStats(() => wallClock);

      stats.recordArrival(Duration.zero);

      for (var i = 1; i <= 5; i++) {
        wallClock += const Duration(milliseconds: 15);
        stats.recordArrival(Duration(milliseconds: i * 10));
      }

      expect(stats.averageInterval, const Duration(milliseconds: 10));
      expect(stats.averageWallInterval, const Duration(milliseconds: 15));
      expect(stats.averageJitter, const Duration(milliseconds: 5));
      expect(stats.p95Jitter, const Duration(milliseconds: 5));
      expect(stats.recommendedDelay, const Duration(milliseconds: 10));
      expect(stats.bufferMargin, const Duration(milliseconds: 5));
      expect(stats.stallTimeout, const Duration(milliseconds: 120));
    },
  );

  test(
    'VisualizationTransportStats relaxes slowly and clamps large jitter',
    () {
      var wallClock = Duration.zero;
      final stats = VisualizationTransportStats(() => wallClock);

      stats.recordArrival(Duration.zero);

      wallClock += const Duration(milliseconds: 210);
      stats.recordArrival(const Duration(milliseconds: 10));

      expect(stats.recommendedDelay, const Duration(milliseconds: 250));

      wallClock += const Duration(milliseconds: 10);
      stats.recordArrival(const Duration(milliseconds: 20));

      expect(stats.recommendedDelay, const Duration(microseconds: 235000));
      expect(stats.averageInterval, const Duration(milliseconds: 10));
      expect(stats.averageWallInterval, const Duration(milliseconds: 110));
      expect(stats.stallTimeout, const Duration(milliseconds: 705));
    },
  );

  test('VisualizationTransportStats resets on engine-time rollback', () {
    var wallClock = Duration.zero;
    final stats = VisualizationTransportStats(() => wallClock);

    stats.recordArrival(Duration.zero);
    wallClock += const Duration(milliseconds: 20);
    stats.recordArrival(const Duration(milliseconds: 10));

    expect(stats.recommendedDelay, const Duration(milliseconds: 20));

    wallClock += const Duration(milliseconds: 5);
    stats.recordArrival(const Duration(milliseconds: 5));

    expect(stats.recommendedDelay, Duration.zero);
    expect(stats.averageInterval, Duration.zero);
    expect(stats.averageWallInterval, Duration.zero);
    expect(stats.averageJitter, Duration.zero);
    expect(stats.p95Jitter, Duration.zero);
    expect(stats.bufferMargin, const Duration(milliseconds: 4));
    expect(stats.stallTimeout, const Duration(milliseconds: 120));
  });
}
