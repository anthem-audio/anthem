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

import 'package:anthem/widgets/basic/controls/slider.dart' as anthem;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Slider direct input', () {
    testWidgets('clicking the horizontal track snaps to the pointer', (
      tester,
    ) async {
      final value = ValueNotifier(0.25);

      await _pumpDirectSlider(tester, value);

      final mouse = await _createMouse(tester);
      await mouse.down(_sliderTopLeft(tester) + const Offset(75, 10));
      await tester.pump();

      expect(value.value, closeTo(0.75, 0.000001));

      await mouse.up();
    });

    testWidgets('dragging the horizontal handle preserves the pointer offset', (
      tester,
    ) async {
      final value = ValueNotifier(0.5);

      await _pumpDirectSlider(tester, value);

      final mouse = await _createMouse(tester);
      await mouse.down(_sliderTopLeft(tester) + const Offset(52, 10));
      await tester.pump();

      expect(value.value, closeTo(0.5, 0.000001));

      await mouse.moveTo(_sliderTopLeft(tester) + const Offset(72, 10));
      await tester.pump();

      expect(value.value, closeTo(0.7, 0.000001));

      await mouse.up();
    });

    testWidgets('clicking the vertical track snaps to the pointer', (
      tester,
    ) async {
      final value = ValueNotifier(0.2);

      await _pumpDirectSlider(
        tester,
        value,
        axis: anthem.SliderAxis.vertical,
        width: 20,
        height: 100,
      );

      final mouse = await _createMouse(tester);
      await mouse.down(_sliderTopLeft(tester) + const Offset(10, 25));
      await tester.pump();

      expect(value.value, closeTo(0.75, 0.000001));

      await mouse.up();
    });

    testWidgets('direct handle drags still capture sticky points', (
      tester,
    ) async {
      final value = ValueNotifier(0.4);

      await _pumpDirectSlider(tester, value, stickyPoints: const [0.5]);

      final mouse = await _createMouse(tester);
      await mouse.down(_sliderTopLeft(tester) + const Offset(40, 10));
      await tester.pump();

      await mouse.moveTo(_sliderTopLeft(tester) + const Offset(60, 10));
      await tester.pump();

      expect(value.value, closeTo(0.5, 0.000001));

      await mouse.up();
    });
  });
}

Future<void> _pumpDirectSlider(
  WidgetTester tester,
  ValueNotifier<double> value, {
  anthem.SliderAxis axis = anthem.SliderAxis.horizontal,
  double width = 100,
  double height = 20,
  List<double> stickyPoints = const [],
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 300,
        height: 300,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: value,
            builder: (context, sliderValue, _) {
              return anthem.Slider(
                width: width,
                height: height,
                axis: axis,
                noBackground: true,
                usePointerLock: false,
                value: sliderValue,
                stickyPoints: stickyPoints,
                onValueChanged: (newValue) {
                  value.value = newValue;
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _createMouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(250, 250));
  await tester.pump();
  return mouse;
}

Offset _sliderTopLeft(WidgetTester tester) {
  return tester.getTopLeft(find.byType(anthem.Slider));
}
