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
import 'package:flutter/foundation.dart';
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
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: timeStamp,
        position: position,
        scrollDelta: scrollDelta,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
  }
}

class _EditorScrollManagerTestFixture {
  static const childKey = Key('editor-scroll-manager-child');

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
            child: EditorScrollManager.editor(
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
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: timeStamp,
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
  static const _trackpadDevice = 1;
  static const _trackpadPointer = 1;

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
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        timeStamp: timeStamp,
        position: position,
        scrollDelta: scrollDelta,
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
  }

  Future<void> sendPanZoomStart(
    WidgetTester tester, {
    required Offset position,
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerPanZoomStartEvent(
        timeStamp: timeStamp,
        device: _trackpadDevice,
        pointer: _trackpadPointer,
        position: position,
      ),
    );
    await tester.pump();
  }

  Future<void> sendPanZoomUpdate(
    WidgetTester tester, {
    required Offset position,
    required Offset pan,
    required Offset panDelta,
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerPanZoomUpdateEvent(
        timeStamp: timeStamp,
        device: _trackpadDevice,
        pointer: _trackpadPointer,
        position: position,
        pan: pan,
        panDelta: panDelta,
      ),
    );
    await tester.pump();
  }

  Future<void> sendPanZoomEnd(
    WidgetTester tester, {
    required Offset position,
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerPanZoomEndEvent(
        timeStamp: timeStamp,
        device: _trackpadDevice,
        pointer: _trackpadPointer,
        position: position,
      ),
    );
    await tester.pump();
  }

  Future<void> sendScrollInertiaCancel(
    WidgetTester tester, {
    required Offset position,
    Duration timeStamp = Duration.zero,
  }) async {
    tester.binding.handlePointerEvent(
      PointerScrollInertiaCancelEvent(
        timeStamp: timeStamp,
        position: position,
        kind: PointerDeviceKind.trackpad,
        device: _trackpadDevice,
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

      expect(fixture.scrollDelta, equals(kIsWeb ? 48 : 24));
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

    testWidgets('stops zooming when wheel input stops', (tester) async {
      await fixture.pump(tester);

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
        timeStamp: const Duration(milliseconds: 0),
      );
      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
        timeStamp: const Duration(milliseconds: 16),
      );

      final widthAfterInput = fixture.timeView.width;

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 120));

      expect(fixture.timeView.width, closeTo(widthAfterInput, 0.000001));
    });

    testWidgets('stops trackpad momentum when inertia is canceled', (
      tester,
    ) async {
      await fixture.pump(tester);
      final center = fixture.center(tester);

      await fixture.sendPanZoomStart(
        tester,
        position: center,
        timeStamp: const Duration(milliseconds: 0),
      );
      await fixture.sendPanZoomUpdate(
        tester,
        position: center,
        pan: const Offset(0, -24),
        panDelta: const Offset(0, -24),
        timeStamp: const Duration(milliseconds: 16),
      );
      await fixture.sendPanZoomUpdate(
        tester,
        position: center,
        pan: const Offset(0, -48),
        panDelta: const Offset(0, -24),
        timeStamp: const Duration(milliseconds: 32),
      );
      await fixture.sendPanZoomEnd(
        tester,
        position: center,
        timeStamp: const Duration(milliseconds: 48),
      );

      final widthAfterInput = fixture.timeView.width;

      await tester.pump(const Duration(milliseconds: 120));
      final widthDuringMomentum = fixture.timeView.width;

      expect(widthDuringMomentum, greaterThan(widthAfterInput));

      await fixture.sendScrollInertiaCancel(
        tester,
        position: center,
        timeStamp: const Duration(milliseconds: 168),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(fixture.timeView.width, closeTo(widthDuringMomentum, 0.000001));
    });
  });

  group('EditorScrollManager.editor', () {
    late _EditorScrollManagerTestFixture fixture;

    setUp(() {
      fixture = _EditorScrollManagerTestFixture();
    });

    testWidgets('routes ctrl plus wheel input to horizontal zoom', (
      tester,
    ) async {
      await fixture.pump(tester);
      fixture.keyboardModifiers.setCtrl(true);
      final initialWidth = fixture.timeView.width;

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
      );

      expect(fixture.timeView.width, greaterThan(initialWidth));
    });

    testWidgets('stops ctrl zooming when wheel input stops', (tester) async {
      await fixture.pump(tester);
      fixture.keyboardModifiers.setCtrl(true);

      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
        timeStamp: const Duration(milliseconds: 0),
      );
      await fixture.sendScroll(
        tester,
        position: fixture.center(tester),
        scrollDelta: const Offset(0, 24),
        timeStamp: const Duration(milliseconds: 16),
      );

      final widthAfterInput = fixture.timeView.width;

      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 120));

      expect(fixture.timeView.width, closeTo(widthAfterInput, 0.000001));
    });
  });
}
