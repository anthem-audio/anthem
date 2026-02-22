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

import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/button_group.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ButtonGroup', () {
    testWidgets('horizontal group inserts vertical dividers', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(
        tester,
        const ButtonGroup(
          children: [
            Button(width: 40, height: 24, text: 'A'),
            Button(width: 40, height: 24, text: 'B'),
            Button(width: 40, height: 24, text: 'C'),
          ],
        ),
      );

      final dividerFinder = find.byWidgetPredicate((Widget widget) {
        return widget is Container &&
            widget.constraints?.minWidth == 1 &&
            widget.constraints?.maxWidth == 1 &&
            widget.color == AnthemTheme.panel.border;
      });

      expect(dividerFinder, findsNWidgets(2));
    });

    testWidgets('vertical group inserts horizontal dividers', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(
        tester,
        const SizedBox(
          width: 80,
          child: ButtonGroup(
            axis: Axis.vertical,
            children: [
              Button(height: 24, text: 'A'),
              Button(height: 24, text: 'B'),
              Button(height: 24, text: 'C'),
            ],
          ),
        ),
      );

      final dividerFinder = find.byWidgetPredicate((Widget widget) {
        return widget is Container &&
            widget.constraints?.minHeight == 1 &&
            widget.constraints?.maxHeight == 1 &&
            widget.color == AnthemTheme.panel.border;
      });

      expect(dividerFinder, findsNWidgets(2));
    });

    testWidgets('group applies border and child defaults', (
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

      final groupContainerFinder = find.byWidgetPredicate((Widget widget) {
        if (widget is! Container || widget.decoration is! BoxDecoration) {
          return false;
        }

        final decoration = widget.decoration! as BoxDecoration;
        return decoration.border ==
                Border.all(color: AnthemTheme.panel.border) &&
            decoration.borderRadius == BorderRadius.circular(4);
      });
      expect(groupContainerFinder, findsOneWidget);
      final groupContainer = tester.widget<Container>(groupContainerFinder);

      final groupDecoration = groupContainer.decoration! as BoxDecoration;
      expect(
        groupDecoration.border,
        equals(Border.all(color: AnthemTheme.panel.border)),
      );
      expect(groupDecoration.borderRadius, equals(BorderRadius.circular(4)));

      expect(_buttonDecorationForKey(tester, 'first').border, isNull);
      expect(
        _buttonDecorationForKey(tester, 'first').borderRadius,
        equals(const BorderRadius.horizontal(left: Radius.circular(3))),
      );

      expect(_buttonDecorationForKey(tester, 'middle').border, isNull);
      expect(
        _buttonDecorationForKey(tester, 'middle').borderRadius,
        equals(BorderRadius.zero),
      );

      expect(_buttonDecorationForKey(tester, 'last').border, isNull);
      expect(
        _buttonDecorationForKey(tester, 'last').borderRadius,
        equals(const BorderRadius.horizontal(right: Radius.circular(3))),
      );
    });

    testWidgets('expandChildren wraps each child in Expanded', (
      WidgetTester tester,
    ) async {
      await _pumpHarness(
        tester,
        const SizedBox(
          width: 200,
          child: ButtonGroup(
            expandChildren: true,
            children: [
              Button(width: 40, height: 24, text: 'A'),
              Button(width: 40, height: 24, text: 'B'),
              Button(width: 40, height: 24, text: 'C'),
            ],
          ),
        ),
      );

      final expandedFinder = find.byType(Expanded);
      expect(expandedFinder, findsNWidgets(3));
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

BoxDecoration _buttonDecorationForKey(WidgetTester tester, String keyValue) {
  final buttonFinder = find.byKey(ValueKey<String>(keyValue));
  final containerFinder = find.descendant(
    of: buttonFinder,
    matching: find.byWidgetPredicate((Widget widget) {
      return widget is Container &&
          widget.decoration is BoxDecoration &&
          widget.child is ClipRRect;
    }),
  );

  expect(containerFinder, findsOneWidget);
  final container = tester.widget<Container>(containerFinder);
  return container.decoration! as BoxDecoration;
}
