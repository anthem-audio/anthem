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

import 'package:anthem/widgets/basic/scroll/scrollbar_renderer.dart';
import 'package:anthem/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moves immediately when the visual handle is at minimum size', (
    tester,
  ) async {
    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000000,
      handleStart: 0,
      handleEnd: 1000,
    );

    expect(_handleOffset(tester), 0);

    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000000,
      handleStart: 10000,
      handleEnd: 11000,
    );

    expect(_handleOffset(tester), closeTo(0.76076, 0.00001));
  });

  testWidgets('uses logical minimum handle size for visual handle size', (
    tester,
  ) async {
    await _pumpHorizontalScrollbar(
      tester,
      minHandlePixelSize: 0,
      minHandleSize: 200,
      scrollRegionEnd: 1000,
      handleStart: 0,
      handleEnd: 10,
    );

    expect(_handleRect(tester).width, closeTo(20, 0.00001));
  });

  testWidgets('dragging minimum-size handle uses available pixel travel', (
    tester,
  ) async {
    final changes = <ScrollbarChangeEvent>[];

    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000000,
      handleStart: 0,
      handleEnd: 1000,
      onChange: changes.add,
    );

    await tester.drag(find.byType(MouseRegion), const Offset(76, 0));

    expect(changes, isNotEmpty);
    expect(changes.last.handleStart, closeTo(999000, 0.00001));
    expect(changes.last.handleEnd, closeTo(1000000, 0.00001));
  });

  testWidgets('shrinks at end when scrolling past the indicated range', (
    tester,
  ) async {
    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000,
      handleStart: 700,
      handleEnd: 1000,
      canScrollPastEnd: true,
    );

    expect(_handleOffset(tester), closeTo(70, 0.00001));
    expect(_handleRect(tester).width, closeTo(30, 0.00001));

    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000,
      handleStart: 710,
      handleEnd: 1010,
      canScrollPastEnd: true,
    );

    expect(_handleOffset(tester), closeTo(71, 0.00001));
    expect(
      _handleRect(tester).right,
      closeTo(_trackRect(tester).right, 0.00001),
    );

    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 1000,
      handleStart: 800,
      handleEnd: 1100,
      canScrollPastEnd: true,
    );

    expect(_handleOffset(tester), closeTo(76, 0.00001));
    expect(_handleRect(tester).width, closeTo(24, 0.00001));
  });

  testWidgets(
    'keeps full handle size at end when scrolling past end is disabled',
    (tester) async {
      await _pumpHorizontalScrollbar(
        tester,
        scrollRegionEnd: 1000,
        handleStart: 710,
        handleEnd: 1010,
      );

      expect(_handleOffset(tester), closeTo(70, 0.00001));
      expect(_handleRect(tester).width, closeTo(30, 0.00001));
    },
  );

  testWidgets('disables full-size handle with transient offset', (
    tester,
  ) async {
    await _pumpHorizontalScrollbar(
      tester,
      scrollRegionEnd: 100,
      handleStart: 10,
      handleEnd: 110,
    );

    expect(
      _handleColor(tester),
      AnthemTheme.panel.scrollbar.withValues(alpha: 0.5),
    );
  });
}

Future<void> _pumpHorizontalScrollbar(
  WidgetTester tester, {
  required double scrollRegionEnd,
  required double handleStart,
  required double handleEnd,
  double minHandlePixelSize = 24,
  double minHandleSize = 0,
  bool canScrollPastStart = false,
  bool canScrollPastEnd = false,
  void Function(ScrollbarChangeEvent event)? onChange,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 100,
          height: 16,
          child: ScrollbarRenderer(
            minHandlePixelSize: minHandlePixelSize,
            minHandleSize: minHandleSize,
            scrollRegionStart: 0,
            scrollRegionEnd: scrollRegionEnd,
            handleStart: handleStart,
            handleEnd: handleEnd,
            canScrollPastStart: canScrollPastStart,
            canScrollPastEnd: canScrollPastEnd,
            onChange: onChange,
          ),
        ),
      ),
    ),
  );
}

double _handleOffset(WidgetTester tester) {
  final trackRect = _trackRect(tester);
  final handleRect = _handleRect(tester);

  return handleRect.left - trackRect.left;
}

Rect _trackRect(WidgetTester tester) =>
    tester.getRect(find.byType(ScrollbarRenderer));

Rect _handleRect(WidgetTester tester) =>
    tester.getRect(find.byType(MouseRegion));

Color _handleColor(WidgetTester tester) {
  final handleContainers = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(MouseRegion),
      matching: find.byType(Container),
    ),
  );

  for (final container in handleContainers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color!;
    }
  }

  throw StateError('Could not find scrollbar handle color.');
}
