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

import 'package:anthem/widgets/basic/lazy_follower.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LazyFollowAnimationHelper', () {
    testWidgets('first update can snap instead of animate', (
      WidgetTester tester,
    ) async {
      var target = 48.0;

      final helper = LazyFollowAnimationHelper(
        duration: 250,
        vsync: tester,
        animateOnFirstUpdate: false,
        items: [LazyFollowItem(initialValue: 0, getTarget: () => target)],
      );
      try {
        helper.update();

        final [item] = helper.items;

        expect(item.animation.value, equals(48.0));
        expect(helper.animationController.isAnimating, isFalse);
      } finally {
        helper.dispose();
      }
    });

    testWidgets('subsequent updates animate from current value', (
      WidgetTester tester,
    ) async {
      var target = 10.0;

      final helper = LazyFollowAnimationHelper(
        duration: 250,
        vsync: tester,
        animateOnFirstUpdate: false,
        items: [LazyFollowItem(initialValue: 0, getTarget: () => target)],
      );
      try {
        helper.update();
        target = 110.0;
        helper.update();

        final [item] = helper.items;

        expect(item.animation.value, equals(10.0));
        expect(helper.animationController.isAnimating, isTrue);

        await tester.pumpAndSettle();
        expect(item.animation.value, closeTo(110.0, 0.001));
      } finally {
        helper.dispose();
      }
    });

    testWidgets('unchanged targets do not restart animation', (
      WidgetTester tester,
    ) async {
      var target = 24.0;

      final helper = LazyFollowAnimationHelper(
        duration: 250,
        vsync: tester,
        animateOnFirstUpdate: false,
        items: [LazyFollowItem(initialValue: 0, getTarget: () => target)],
      );
      try {
        helper.update();
        expect(helper.animationController.isAnimating, isFalse);

        helper.update();
        expect(helper.animationController.isAnimating, isFalse);
      } finally {
        helper.dispose();
      }
    });

    testWidgets('shouldSnap can snap even if target did not change', (
      WidgetTester tester,
    ) async {
      var target = 0.0;
      var shouldSnap = false;

      final helper = LazyFollowAnimationHelper(
        duration: 250,
        vsync: tester,
        animateOnFirstUpdate: false,
        items: [
          LazyFollowItem(
            initialValue: 0,
            getTarget: () => target,
            getShouldSnap: () => shouldSnap,
          ),
        ],
      );
      try {
        helper.update();
        target = 100.0;
        helper.update();

        final [item] = helper.items;

        await tester.pump(const Duration(milliseconds: 100));
        expect(item.animation.value, lessThan(100.0));

        shouldSnap = true;
        helper.update();

        expect(item.animation.value, closeTo(100.0, 0.000001));
      } finally {
        helper.dispose();
      }
    });
  });
}
