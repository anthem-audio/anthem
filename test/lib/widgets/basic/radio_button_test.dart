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
import 'package:anthem/widgets/basic/radio_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a 16x16 custom-painted radio button', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(tester, const AnthemRadioButton(selected: true));

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
      const AnthemRadioButton(selected: true, label: 'Stereo'),
    );

    final text = tester.widget<Text>(find.text('Stereo'));

    expect(text.style?.color, equals(AnthemTheme.text.main));
    expect(text.style?.fontSize, equals(12));
  });

  testWidgets('renders disabled label with themed disabled text', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      const AnthemRadioButton(selected: true, label: 'Stereo', disabled: true),
    );

    final text = tester.widget<Text>(find.text('Stereo'));

    expect(text.style?.color, equals(AnthemTheme.text.disabled));
    expect(text.style?.fontSize, equals(12));
  });

  testWidgets('disabled selected radio button paints disabled palette', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      const AnthemRadioButton(selected: true, disabled: true),
    );

    expect(
      find.byType(CustomPaint),
      paints
        ..circle(color: AnthemTheme.panel.border)
        ..circle(color: AnthemTheme.text.disabled)
        ..circle(color: AnthemTheme.panel.backgroundLight)
        ..circle(color: AnthemTheme.text.disabled),
    );
  });

  testWidgets('tap calls onSelected', (WidgetTester tester) async {
    var selectedCalls = 0;

    await _pumpHarness(
      tester,
      AnthemRadioButton(
        selected: false,
        label: 'Stereo',
        onSelected: () {
          selectedCalls += 1;
        },
      ),
    );

    await tester.tap(find.text('Stereo'));
    await tester.pump();

    expect(selectedCalls, equals(1));
  });

  testWidgets('disabled radio button does not call onSelected', (
    WidgetTester tester,
  ) async {
    var selectedCalls = 0;

    await _pumpHarness(
      tester,
      AnthemRadioButton(
        selected: false,
        label: 'Stereo',
        disabled: true,
        onSelected: () {
          selectedCalls += 1;
        },
      ),
    );

    await tester.tap(find.text('Stereo'));
    await tester.pump();

    expect(selectedCalls, equals(0));
  });

  testWidgets('read-only radio button does not consume parent taps', (
    WidgetTester tester,
  ) async {
    var parentTapCount = 0;

    await _pumpHarness(
      tester,
      GestureDetector(
        onTap: () => parentTapCount += 1,
        child: const AnthemRadioButton(selected: true, label: 'Read-only'),
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
