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

import 'package:anthem/widgets/editors/shared/scroll_manager.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _VerticalEditorScrollManagerTestFixture {
  static const childKey = Key('vertical-editor-scroll-manager-child');

  final KeyboardModifiers keyboardModifiers = KeyboardModifiers();
  double scrollDelta = 0;
  (double pointerY, double delta)? zoomEvent;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<KeyboardModifiers>.value(
        value: keyboardModifiers,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: EditorScrollManager.verticalOnly(
              onVerticalScrollChange: (delta) {
                scrollDelta += delta;
                return delta;
              },
              onVerticalZoom: (pointerY, delta) {
                zoomEvent = (pointerY, delta);
              },
              child: const ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox(key: childKey, width: 200, height: 120),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset center(WidgetTester tester) => tester.getCenter(find.byKey(childKey));

  Future<void> sendScroll(
    WidgetTester tester, {
    required Offset position,
    required Offset scrollDelta,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: position,
        scrollDelta: scrollDelta,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
  }
}

class _TimelineScrollManagerTestFixture {
  static const childKey = Key('timeline-scroll-manager-child');

  final KeyboardModifiers keyboardModifiers = KeyboardModifiers();
  final TimeRange timeView = TimeRange(0, 1000);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<KeyboardModifiers>.value(
        value: keyboardModifiers,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: EditorScrollManager.timeline(
              timeView: timeView,
              child: const ColoredBox(
                color: Color(0xFFFFFFFF),
                child: SizedBox(key: childKey, width: 200, height: 120),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset center(WidgetTester tester) => tester.getCenter(find.byKey(childKey));

  Future<void> sendScroll(
    WidgetTester tester, {
    required Offset position,
    required Offset scrollDelta,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: position,
        scrollDelta: scrollDelta,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
  }
}

void main() {
  group('PanZoomAxisCoordinator', () {
    late PanZoomAxisCoordinator coordinator;

    setUp(() {
      coordinator = PanZoomAxisCoordinator();
    });

    test('locks horizontally for strongly horizontal gestures', () {
      final filtered = coordinator.filter(dx: 30, dy: 5);

      expect(coordinator.mode, PanZoomAxisLockMode.lockedHorizontal);
      expect(filtered.dx, equals(30));
      expect(filtered.dy, equals(0));
    });

    test('locks vertically for strongly vertical gestures', () {
      final filtered = coordinator.filter(dx: 5, dy: 30);

      expect(coordinator.mode, PanZoomAxisLockMode.lockedVertical);
      expect(filtered.dx, equals(0));
      expect(filtered.dy, equals(30));
    });

    test('keeps truly diagonal gestures free on both axes', () {
      final filtered = coordinator.filter(dx: 12, dy: 11);

      expect(coordinator.mode, PanZoomAxisLockMode.free);
      expect(filtered.dx, equals(12));
      expect(filtered.dy, equals(11));
    });

    test(
      'keeps the current lock until suppressed travel exceeds hysteresis',
      () {
        coordinator.filter(dx: 30, dy: 5);

        final filtered = coordinator.filter(dx: 2, dy: 40);

        expect(coordinator.mode, PanZoomAxisLockMode.lockedHorizontal);
        expect(filtered.dx, equals(2));
        expect(filtered.dy, equals(0));
      },
    );

    test(
      'can switch from horizontal lock to vertical lock after enough travel',
      () {
        coordinator.filter(dx: 30, dy: 5);
        coordinator.filter(dx: 2, dy: 30);

        final filtered = coordinator.filter(dx: 2, dy: 30);

        expect(coordinator.mode, PanZoomAxisLockMode.lockedVertical);
        expect(filtered.dx, equals(0));
        expect(filtered.dy, equals(30));
      },
    );

    test('can unlock from a locked axis back to free diagonal motion', () {
      coordinator.filter(dx: 30, dy: 5);
      coordinator.filter(dx: 1, dy: 30);

      final filtered = coordinator.filter(dx: 30, dy: 30);

      expect(coordinator.mode, PanZoomAxisLockMode.free);
      expect(filtered.dx, equals(30));
      expect(filtered.dy, equals(30));
    });

    test('reset returns the coordinator to the undecided state', () {
      coordinator.filter(dx: 30, dy: 5);

      coordinator.reset();

      expect(coordinator.mode, PanZoomAxisLockMode.undecided);
      final filtered = coordinator.filter(dx: 6, dy: 5);
      expect(filtered.dx, equals(6));
      expect(filtered.dy, equals(5));
      expect(coordinator.mode, PanZoomAxisLockMode.undecided);
    });
  });

  group('EditorScrollManager.verticalOnly', () {
    late _VerticalEditorScrollManagerTestFixture fixture;

    setUp(() {
      fixture = _VerticalEditorScrollManagerTestFixture();
    });

    testWidgets('routes plain wheel input to vertical scrolling', (
      tester,
    ) async {
      await fixture.pump(tester);

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
      );

      expect(fixture.scrollDelta, equals(24));
      expect(fixture.zoomEvent, isNull);
    });

    testWidgets('ignores horizontal modifiers instead of scrolling', (
      tester,
    ) async {
      await fixture.pump(tester);
      fixture.keyboardModifiers.setShift(true);

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
      );

      expect(fixture.scrollDelta, equals(0));
      expect(fixture.zoomEvent, isNull);
    });

    testWidgets('routes alt plus wheel input to vertical zoom', (tester) async {
      await fixture.pump(tester);
      fixture.keyboardModifiers.setAlt(true);

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
      );

      expect(fixture.scrollDelta, equals(0));
      expect(fixture.zoomEvent, isNotNull);
      expect(fixture.zoomEvent!.$2, closeTo(-0.12, 0.000001));
    });
  });

  group('EditorScrollManager.timeline', () {
    late _TimelineScrollManagerTestFixture fixture;

    setUp(() {
      fixture = _TimelineScrollManagerTestFixture();
    });

    testWidgets('routes wheel input to horizontal zoom', (tester) async {
      await fixture.pump(tester);
      final initialWidth = fixture.timeView.width;

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
      );

      expect(fixture.timeView.width, greaterThan(initialWidth));
    });
  });
}
