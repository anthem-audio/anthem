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

import 'package:anthem/widgets/basic/controls/control_mouse_handler.dart';
import 'package:anthem/widgets/basic/controls/knob.dart';
import 'package:anthem/widgets/basic/controls/slider.dart' as anthem;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.stylus]) {
    testWidgets(
      '$kind adjusts knobs and sliders without native pointer lock',
      (tester) async {
        var nativeCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('pointer_lock'),
          (_) async {
            nativeCalls++;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('pointer_lock'),
            null,
          ),
        );
        final values = <double>[];
        var starts = 0;
        var ends = 0;

        for (final control in [
          Knob(
            value: 0.5,
            width: 100,
            height: 100,
            onValueChanged: values.add,
            onValueChangeStart: () => starts++,
            onValueChangeEnd: (_) => ends++,
          ),
          anthem.Slider(
            value: 0.5,
            width: 30,
            height: 100,
            axis: anthem.SliderAxis.vertical,
            onValueChanged: values.add,
            onValueChangeStart: () => starts++,
            onValueChangeEnd: (_) => ends++,
          ),
        ]) {
          values.clear();
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(alignment: Alignment.center, child: control),
            ),
          );
          final pointer = await tester.startGesture(
            tester.getCenter(find.byType(ControlMouseHandler)),
            kind: kind,
          );
          expect(values, isEmpty);
          await pointer.moveBy(const Offset(0, -30));
          expect(values.single, closeTo(0.6, 0.000001));
          await pointer.cancel();
          await tester.pumpAndSettle();
        }
        expect(starts, 2);
        expect(ends, 2);
        expect(nativeCalls, 0);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  }

  testWidgets('canceling a touch does not count toward double-tap reset', (
    tester,
  ) async {
    var resets = 0;
    final ends = <ControlMouseEvent>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ControlMouseHandler(
          onDoubleClick: () => resets++,
          onChange: (_) {},
          onEnd: ends.add,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final first = await tester.startGesture(const Offset(50, 50));
    await first.moveBy(const Offset(0, -10));
    await first.cancel();
    expect(ends.single.absolute, const Offset(0, 10));
    await tester.tapAt(const Offset(50, 50));
    expect(resets, 0);
    await tester.tapAt(const Offset(50, 50));
    expect(resets, 1);
  });
}
