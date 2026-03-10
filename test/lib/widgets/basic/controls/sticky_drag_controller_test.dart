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

import 'package:anthem/widgets/basic/controls/sticky_drag_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StickyDragController', () {
    test('continues moving after a fast drag snaps to a sticky point', () {
      final controller = StickyDragController(stickyTrapSize: 0.08);
      controller.reset(rawValue: 0, stickyPoints: const [0.5]);

      final initialResult = controller.applyRawDelta(3.3333333333);
      expect(initialResult.changed, isTrue);
      expect(initialResult.rawValue, closeTo(0.5, 0.000001));

      for (var i = 0; i < 16; i++) {
        final trappedResult = controller.applyRawDelta(0.01);
        expect(trappedResult.changed, isFalse);
        expect(trappedResult.rawValue, closeTo(0.5, 0.000001));
      }

      final releaseResult = controller.applyRawDelta(0.01);
      expect(releaseResult.changed, isTrue);
      expect(releaseResult.rawValue, closeTo(0.51, 0.000001));
    });

    test('continues moving left after a fast drag from the maximum', () {
      final controller = StickyDragController(stickyTrapSize: 0.08);
      controller.reset(rawValue: 1, stickyPoints: const [0.5]);

      final initialResult = controller.applyRawDelta(-3.3333333333);
      expect(initialResult.changed, isTrue);
      expect(initialResult.rawValue, closeTo(0.5, 0.000001));

      for (var i = 0; i < 16; i++) {
        final trappedResult = controller.applyRawDelta(-0.01);
        expect(trappedResult.changed, isFalse);
        expect(trappedResult.rawValue, closeTo(0.5, 0.000001));
      }

      final releaseResult = controller.applyRawDelta(-0.01);
      expect(releaseResult.changed, isTrue);
      expect(releaseResult.rawValue, closeTo(0.49, 0.000001));
    });

    test('reset clears sticky and overshoot state for a new drag', () {
      final controller = StickyDragController(stickyTrapSize: 0.08);
      controller.reset(rawValue: 0, stickyPoints: const [0.5]);

      controller.applyRawDelta(3.3333333333);
      expect(controller.applyRawDelta(0.01).changed, isFalse);

      controller.reset(rawValue: 0.5, stickyPoints: const [0.5]);

      final result = controller.applyRawDelta(0.01);
      expect(result.changed, isTrue);
      expect(result.rawValue, closeTo(0.51, 0.000001));
    });

    test('clamps large sticky exits back into the valid range', () {
      final controller = StickyDragController(stickyTrapSize: 0.08);
      controller.reset(rawValue: 0, stickyPoints: const [0.5]);

      controller.applyRawDelta(0.6);

      final result = controller.applyRawDelta(1.0);
      expect(result.changed, isTrue);
      expect(result.rawValue, closeTo(1.0, 0.000001));
    });
  });
}
