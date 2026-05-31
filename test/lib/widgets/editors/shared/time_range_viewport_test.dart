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

import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/time_range_animation.dart';
import 'package:anthem/widgets/editors/shared/time_range_content_source.dart';
import 'package:anthem/widgets/editors/shared/time_range_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setRange clamps to content bounds and records transition intent', () {
    final viewport = TimeRangeViewport(
      target: TimeRange(0, 500),
      contentSource: const TimeRangeContentSource.fixed(end: 1000),
    );

    viewport.setRange(start: 900, end: 1400);

    expect(viewport.target.start, closeTo(750, 0.000001));
    expect(viewport.target.end, closeTo(1250, 0.000001));
    expect(viewport.lastMutation.revision, equals(1));
    expect(viewport.lastMutation.transition, TimeRangeTransition.animated);
  });

  test('resizeViewportPreservingScale keeps ticks per pixel fixed', () {
    final viewport = TimeRangeViewport(
      target: TimeRange(100, 1100),
      contentSource: const TimeRangeContentSource.fixed(end: 3000),
    );

    viewport.resizeViewportPreservingScale(
      oldViewportWidth: 500,
      newViewportWidth: 750,
    );

    expect(viewport.target.start, closeTo(100, 0.000001));
    expect(viewport.target.end, closeTo(1600, 0.000001));
    expect(viewport.lastMutation.transition, TimeRangeTransition.immediate);
  });

  test('TimeRangeAnimation snaps immediate viewport mutations', () {
    final viewport = TimeRangeViewport(
      target: TimeRange(0, 100),
      contentSource: const TimeRangeContentSource.fixed(end: 1000),
    );
    final animation = TimeRangeAnimation(
      viewport: viewport,
      vsync: const TestVSync(),
    );

    try {
      animation.update();
      viewport.setRange(start: 100, end: 200);
      animation.update();

      expect(animation.renderedStart, closeTo(0, 0.000001));
      expect(animation.renderedEnd, closeTo(100, 0.000001));

      viewport.setRange(
        start: 300,
        end: 400,
        transition: TimeRangeTransition.immediate,
      );
      animation.update();

      expect(animation.renderedStart, closeTo(300, 0.000001));
      expect(animation.renderedEnd, closeTo(400, 0.000001));
    } finally {
      animation.dispose();
    }
  });
}
