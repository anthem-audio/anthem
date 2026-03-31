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

import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

void main() {
  testWidgets(
    'observable invalidation repaints without rebuilding child subtree',
    (tester) async {
      final observedValue = Observable(0);
      var paintCount = 0;
      var childBuildCount = 0;

      await tester.pumpWidget(
        SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _TestPainter(
              observedValue: observedValue,
              onPaint: () {
                paintCount++;
              },
            ),
            child: _BuildCounter(
              onBuild: () {
                childBuildCount++;
              },
            ),
          ),
        ),
      );

      final initialPaintCount = paintCount;

      expect(initialPaintCount, greaterThan(0));
      expect(childBuildCount, 1);

      runInAction(() {
        observedValue.value = 1;
      });

      await tester.pump();
      await tester.pump();

      expect(paintCount, greaterThan(initialPaintCount));
      expect(childBuildCount, 1);
    },
  );

  testWidgets(
    'external repaint listenable repaints without rebuilding child subtree',
    (tester) async {
      final repaintSignal = ValueNotifier(0);
      var paintCount = 0;
      var childBuildCount = 0;

      await tester.pumpWidget(
        SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _ExternalRepaintPainter(
              repaintSignal: repaintSignal,
              onPaint: () {
                paintCount++;
              },
            ),
            child: _BuildCounter(
              onBuild: () {
                childBuildCount++;
              },
            ),
          ),
        ),
      );

      final initialPaintCount = paintCount;

      expect(initialPaintCount, greaterThan(0));
      expect(childBuildCount, 1);

      repaintSignal.value++;
      await tester.pump();

      expect(paintCount, greaterThan(initialPaintCount));
      expect(childBuildCount, 1);
    },
  );
}

class _TestPainter extends CustomPainterObserver {
  _TestPainter({required this.observedValue, required this.onPaint})
    : super(debugName: '_TestPainter');

  final Observable<int> observedValue;
  final VoidCallback onPaint;

  @override
  void observablePaint(Canvas canvas, Size size) {
    onPaint();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = observedValue.value == 0
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
    );
  }
}

class _ExternalRepaintPainter extends CustomPainterObserver {
  _ExternalRepaintPainter({required this.repaintSignal, required this.onPaint})
    : super(debugName: '_ExternalRepaintPainter', repaint: repaintSignal);

  final ValueNotifier<int> repaintSignal;
  final VoidCallback onPaint;

  @override
  void observablePaint(Canvas canvas, Size size) {
    onPaint();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = repaintSignal.value.isEven
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
    );
  }
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox.expand();
  }
}
