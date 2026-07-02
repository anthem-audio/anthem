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
import 'package:anthem/widgets/basic/checkbox.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a 16x16 custom-painted checkbox', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(tester, const AnthemCheckbox(value: true));

    expect(find.byType(CustomPaint), findsOneWidget);
    expect(
      tester.getSize(find.byType(CustomPaint)),
      equals(const Size(16, 16)),
    );
  });

  testWidgets('renders optional label with themed 12px text', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      const AnthemCheckbox(value: true, label: 'Snap to grid'),
    );

    final text = tester.widget<Text>(find.text('Snap to grid'));

    expect(text.style?.color, equals(AnthemTheme.text.main));
    expect(text.style?.fontSize, equals(12));
  });

  testWidgets('renders disabled label with themed disabled text', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      const AnthemCheckbox(value: true, label: 'Snap to grid', disabled: true),
    );

    final text = tester.widget<Text>(find.text('Snap to grid'));

    expect(text.style?.color, equals(AnthemTheme.text.disabled));
    expect(text.style?.fontSize, equals(12));
  });

  testWidgets('disabled checked checkbox paints disabled palette', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      const AnthemCheckbox(value: true, disabled: true),
    );

    expect(
      find.byType(CustomPaint),
      paints
        ..rrect(color: AnthemTheme.panel.backgroundLight)
        ..rrect(color: AnthemTheme.panel.border)
        ..path(color: AnthemTheme.text.disabled),
    );
  });

  testWidgets('tap reports the inverted value', (WidgetTester tester) async {
    final values = <bool>[];

    await _pumpHarness(
      tester,
      AnthemCheckbox(value: false, label: 'Enabled', onChanged: values.add),
    );

    await tester.tap(find.text('Enabled'));
    await tester.pump();

    expect(values, equals([true]));
  });

  testWidgets('disabled checkbox does not report changes', (
    WidgetTester tester,
  ) async {
    final values = <bool>[];

    await _pumpHarness(
      tester,
      AnthemCheckbox(
        value: false,
        label: 'Enabled',
        disabled: true,
        onChanged: values.add,
      ),
    );

    await tester.tap(find.text('Enabled'));
    await tester.pump();

    expect(values, isEmpty);
  });

  testWidgets('read-only checkbox does not consume parent taps', (
    WidgetTester tester,
  ) async {
    var parentTapCount = 0;

    await _pumpHarness(
      tester,
      GestureDetector(
        onTap: () => parentTapCount += 1,
        child: const AnthemCheckbox(value: true, label: 'Read-only'),
      ),
    );

    await tester.tap(find.text('Read-only'));
    await tester.pump();

    expect(parentTapCount, equals(1));
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
