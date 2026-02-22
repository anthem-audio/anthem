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

import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_group.dart';
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/icon.dart' as anthem_icons;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([MockSpec<HintStore>()])
import 'button_test.mocks.dart';

void main() {
  group('Button callbacks', () {
    testWidgets('Primary click calls onPress', (WidgetTester tester) async {
      int onPressCalls = 0;
      int onRightClickCalls = 0;

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Press',
          onPress: () => onPressCalls += 1,
          onRightClick: () => onRightClickCalls += 1,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(onPressCalls, equals(1));
      expect(onRightClickCalls, equals(0));
    });

    testWidgets('Secondary click calls onRightClick', (
      WidgetTester tester,
    ) async {
      int onPressCalls = 0;
      int onRightClickCalls = 0;

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Press',
          onPress: () => onPressCalls += 1,
          onRightClick: () => onRightClickCalls += 1,
        ),
      );

      final TestGesture mouse = await _createMouse(
        tester,
        buttons: kSecondaryButton,
      );
      await _hoverButton(tester, mouse);
      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(onPressCalls, equals(0));
      expect(onRightClickCalls, equals(1));
    });

    testWidgets('Releasing outside widget does not call callbacks', (
      WidgetTester tester,
    ) async {
      int onPressCalls = 0;
      int onRightClickCalls = 0;

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Press',
          onPress: () => onPressCalls += 1,
          onRightClick: () => onRightClickCalls += 1,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      await _moveMouseOutside(tester, mouse);
      await mouse.up();
      await tester.pump();

      expect(onPressCalls, equals(0));
      expect(onRightClickCalls, equals(0));
    });

    testWidgets('Pointer cancel does not call callbacks', (
      WidgetTester tester,
    ) async {
      int onPressCalls = 0;
      int onRightClickCalls = 0;

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Press',
          onPress: () => onPressCalls += 1,
          onRightClick: () => onRightClickCalls += 1,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      await mouse.cancel();
      await tester.pump();

      expect(onPressCalls, equals(0));
      expect(onRightClickCalls, equals(0));
    });

    testWidgets('Button with onPress consumes parent primary tap', (
      WidgetTester tester,
    ) async {
      int parentTapCalls = 0;
      int onPressCalls = 0;

      await _pumpHarness(
        tester,
        GestureDetector(
          onTap: () => parentTapCalls += 1,
          child: Button(
            width: 100,
            height: 30,
            text: 'Press',
            onPress: () => onPressCalls += 1,
          ),
        ),
      );

      await tester.tap(find.byType(Button));
      await tester.pump();

      expect(onPressCalls, equals(1));
      expect(parentTapCalls, equals(0));
    });

    testWidgets('Button without handlers allows parent primary tap', (
      WidgetTester tester,
    ) async {
      int parentTapCalls = 0;

      await _pumpHarness(
        tester,
        GestureDetector(
          onTap: () => parentTapCalls += 1,
          child: const Button(width: 100, height: 30, text: 'Press'),
        ),
      );

      await tester.tap(find.byType(Button));
      await tester.pump();

      expect(parentTapCalls, equals(1));
    });

    testWidgets('Button with onRightClick consumes parent secondary tap', (
      WidgetTester tester,
    ) async {
      int parentRightClickCalls = 0;
      int onRightClickCalls = 0;

      await _pumpHarness(
        tester,
        GestureDetector(
          onSecondaryTapUp: (_) => parentRightClickCalls += 1,
          child: Button(
            width: 100,
            height: 30,
            text: 'Press',
            onRightClick: () => onRightClickCalls += 1,
          ),
        ),
      );

      final TestGesture mouse = await _createMouse(
        tester,
        buttons: kSecondaryButton,
      );
      await _hoverButton(tester, mouse);
      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(onRightClickCalls, equals(1));
      expect(parentRightClickCalls, equals(0));
    });
  });

  group('Button visuals', () {
    testWidgets('Main variant uses idle, hover, and press colors', (
      WidgetTester tester,
    ) async {
      final ButtonTheme mainTheme = getButtonTheme(ButtonVariant.main);

      await _pumpButton(
        tester,
        const Button(width: 100, height: 30, text: 'Visuals'),
      );

      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.idle),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.hover),
      );

      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.press),
      );

      await mouse.up();
      await tester.pump();
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.hover),
      );

      await _moveMouseOutside(tester, mouse);
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.idle),
      );
    });

    testWidgets('Toggled state uses active color regardless of pointer state', (
      WidgetTester tester,
    ) async {
      final ButtonTheme mainTheme = getButtonTheme(ButtonVariant.main);

      await _pumpButton(
        tester,
        const Button(width: 100, height: 30, text: 'Toggle', toggleState: true),
      );

      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.toggleActive),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.toggleActive),
      );

      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      expect(
        _buttonDecoration(tester).color,
        equals(mainTheme.background.toggleActive),
      );
    });

    testWidgets('Background overrides apply for idle, hover, and press', (
      WidgetTester tester,
    ) async {
      const Color idleColor = Color(0xFF111111);
      const Color hoverColor = Color(0xFF222222);
      const Color pressColor = Color(0xFF333333);

      await _pumpButton(
        tester,
        const Button(
          width: 100,
          height: 30,
          text: 'Override',
          background: idleColor,
          backgroundHover: hoverColor,
          backgroundPress: pressColor,
        ),
      );

      expect(_buttonDecoration(tester).color, equals(idleColor));

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      expect(_buttonDecoration(tester).color, equals(hoverColor));

      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      expect(_buttonDecoration(tester).color, equals(pressColor));
    });

    testWidgets('Toggled background override has highest priority', (
      WidgetTester tester,
    ) async {
      const Color toggleColor = Color(0xFF999999);

      await _pumpButton(
        tester,
        const Button(
          width: 100,
          height: 30,
          text: 'Override',
          toggleState: true,
          background: Color(0xFF111111),
          backgroundHover: Color(0xFF222222),
          backgroundPress: Color(0xFF333333),
          backgroundToggleActive: toggleColor,
        ),
      );

      expect(_buttonDecoration(tester).color, equals(toggleColor));

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      expect(_buttonDecoration(tester).color, equals(toggleColor));

      await mouse.down(_buttonCenter(tester));
      await tester.pump();
      expect(_buttonDecoration(tester).color, equals(toggleColor));
    });

    testWidgets('showMenuIndicator adds indicator widget', (
      WidgetTester tester,
    ) async {
      await _pumpButton(
        tester,
        const Button(
          width: 100,
          height: 30,
          text: 'Menu',
          showMenuIndicator: true,
        ),
      );

      final Finder indicatorFinder = find.descendant(
        of: find.byType(Button),
        matching: find.byType(Positioned),
      );

      expect(indicatorFinder, findsOneWidget);
    });

    testWidgets('hideBorder removes border from button container', (
      WidgetTester tester,
    ) async {
      await _pumpButton(
        tester,
        const Button(
          width: 100,
          height: 30,
          text: 'NoBorder',
          hideBorder: true,
        ),
      );

      expect(_buttonDecoration(tester).border, isNull);
    });

    testWidgets('expand enables StackFit.expand', (WidgetTester tester) async {
      await _pumpButton(
        tester,
        const Button(width: 100, height: 30, text: 'Expand', expand: true),
      );

      final Finder stackFinder = find.descendant(
        of: find.byType(Button),
        matching: find.byType(Stack),
      );

      final Stack stack = tester.widget<Stack>(stackFinder);
      expect(stack.fit, equals(StackFit.expand));
    });

    testWidgets('ButtonGroup applies hideBorder and border radius defaults', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(
        tester,
        const ButtonGroup(
          children: [
            Button(
              key: ValueKey<String>('first'),
              width: 40,
              height: 24,
              text: 'A',
            ),
            Button(
              key: ValueKey<String>('middle'),
              width: 40,
              height: 24,
              text: 'B',
            ),
            Button(
              key: ValueKey<String>('last'),
              width: 40,
              height: 24,
              text: 'C',
            ),
          ],
        ),
      );

      expect(_buttonDecorationByKey(tester, 'first').border, isNull);
      expect(
        _buttonDecorationByKey(tester, 'first').borderRadius,
        equals(const BorderRadius.horizontal(left: Radius.circular(3))),
      );

      expect(_buttonDecorationByKey(tester, 'middle').border, isNull);
      expect(
        _buttonDecorationByKey(tester, 'middle').borderRadius,
        equals(BorderRadius.zero),
      );

      expect(_buttonDecorationByKey(tester, 'last').border, isNull);
      expect(
        _buttonDecorationByKey(tester, 'last').borderRadius,
        equals(const BorderRadius.horizontal(right: Radius.circular(3))),
      );
    });

    testWidgets('Button explicit props override ButtonGroup defaults', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(
        tester,
        const ButtonGroup(
          children: [
            Button(
              key: ValueKey<String>('override'),
              width: 40,
              height: 24,
              text: 'A',
              hideBorder: false,
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
          ],
        ),
      );

      final decoration = _buttonDecorationByKey(tester, 'override');
      expect(decoration.border, isNotNull);
      expect(
        decoration.borderRadius,
        equals(const BorderRadius.all(Radius.circular(7))),
      );
    });
  });

  group('Button content', () {
    testWidgets('Text content is rendered', (WidgetTester tester) async {
      await _pumpButton(
        tester,
        const Button(width: 100, height: 30, text: 'Text button'),
      );

      expect(find.text('Text button'), findsOneWidget);
    });

    testWidgets('contentBuilder takes precedence over text and icon', (
      WidgetTester tester,
    ) async {
      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Text fallback',
          icon: anthem_icons.Icons.add,
          contentBuilder: (BuildContext context, Color contentColor) {
            return const Text('Builder content');
          },
        ),
      );

      expect(find.text('Builder content'), findsOneWidget);
      expect(find.text('Text fallback'), findsNothing);
    });
  });

  group('Button hints', () {
    testWidgets('Hover enter adds hint and hover exit removes hint', (
      WidgetTester tester,
    ) async {
      final hintStore = MockHintStore();
      final List<HintSection> hint = <HintSection>[
        HintSection('click', 'Adds a track'),
      ];
      when(hintStore.addHint(any)).thenReturn(42);

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Hint',
          hint: hint,
          hintStoreOverride: hintStore,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      verify(hintStore.addHint(hint)).called(1);

      await _moveMouseOutside(tester, mouse);
      verify(hintStore.removeHint(42)).called(1);
    });

    testWidgets('Updating hint while hovered replaces active hint', (
      WidgetTester tester,
    ) async {
      final hintStore = MockHintStore();
      final List<HintSection> firstHint = <HintSection>[
        HintSection('click', 'First'),
      ];
      final List<HintSection> secondHint = <HintSection>[
        HintSection('click', 'Second'),
      ];
      int nextHintId = 10;
      when(hintStore.addHint(any)).thenAnswer((_) => nextHintId++);

      await _pumpButton(
        tester,
        Button(
          key: const ValueKey<String>('button-under-test'),
          width: 100,
          height: 30,
          text: 'Hint',
          hint: firstHint,
          hintStoreOverride: hintStore,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      verify(hintStore.addHint(firstHint)).called(1);

      await _pumpButton(
        tester,
        Button(
          key: const ValueKey<String>('button-under-test'),
          width: 100,
          height: 30,
          text: 'Hint',
          hint: secondHint,
          hintStoreOverride: hintStore,
        ),
      );

      verify(hintStore.removeHint(10)).called(1);
      verify(hintStore.addHint(secondHint)).called(1);
    });

    testWidgets('Disposing while hovered removes active hint', (
      WidgetTester tester,
    ) async {
      final hintStore = MockHintStore();
      when(hintStore.addHint(any)).thenReturn(99);

      await _pumpButton(
        tester,
        Button(
          width: 100,
          height: 30,
          text: 'Hint',
          hint: <HintSection>[HintSection('click', 'Disposable')],
          hintStoreOverride: hintStore,
        ),
      );

      final TestGesture mouse = await _createMouse(tester);
      await _hoverButton(tester, mouse);
      verify(hintStore.addHint(any)).called(1);

      await _pumpHarness(tester, const SizedBox.shrink());
      verify(hintStore.removeHint(99)).called(1);
    });
  });
}

Future<void> _pumpHarness(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 300,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

Future<void> _pumpButton(WidgetTester tester, Button button) {
  return _pumpHarness(tester, button);
}

Future<TestGesture> _createMouse(
  WidgetTester tester, {
  int buttons = kPrimaryButton,
}) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
  await mouse.addPointer(location: const Offset(390, 290));
  await tester.pump();
  return mouse;
}

Future<void> _hoverButton(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(_buttonCenter(tester));
  await tester.pump();
}

Future<void> _moveMouseOutside(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(const Offset(390, 290));
  await tester.pump();
}

Offset _buttonCenter(WidgetTester tester) {
  return tester.getCenter(find.byType(Button));
}

BoxDecoration _buttonDecoration(WidgetTester tester) {
  final Finder containerFinder = find.descendant(
    of: find.byType(Button),
    matching: find.byWidgetPredicate((Widget widget) {
      return widget is Container &&
          widget.decoration is BoxDecoration &&
          widget.child is ClipRRect;
    }),
  );

  expect(containerFinder, findsOneWidget);

  final Container container = tester.widget<Container>(containerFinder);
  return container.decoration! as BoxDecoration;
}

BoxDecoration _buttonDecorationByKey(WidgetTester tester, String keyValue) {
  final Finder containerFinder = find.descendant(
    of: find.byKey(ValueKey<String>(keyValue)),
    matching: find.byWidgetPredicate((Widget widget) {
      return widget is Container &&
          widget.decoration is BoxDecoration &&
          widget.child is ClipRRect;
    }),
  );

  expect(containerFinder, findsOneWidget);

  final Container container = tester.widget<Container>(containerFinder);
  return container.decoration! as BoxDecoration;
}
