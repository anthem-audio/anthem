/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';
import 'package:flutter/widgets.dart';

class GeneratorRowAutomation extends StatelessWidget {
  final PatternModel pattern;
  final Id generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  const GeneratorRowAutomation({
    super.key,
    required this.pattern,
    required this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaintObserver(
      painterBuilder: () => _GeneratorRowAutomationPainter(
        pattern: pattern,
        generatorID: generatorID,
        timeViewStart: timeViewStart,
        ticksPerPixel: ticksPerPixel,
        color: color,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }
}

class _GeneratorRowAutomationPainter extends CustomPainterObserver {
  final PatternModel pattern;
  final Id generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;
  final double devicePixelRatio;

  _GeneratorRowAutomationPainter({
    required this.pattern,
    required this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
    required this.devicePixelRatio,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final timeViewEnd = timeViewStart + ticksPerPixel * size.width;

    final lane = pattern.automationLanes[generatorID]!;

    renderAutomationCurve(
      canvas: canvas,
      canvasSize: size,
      xDrawPositionTime: (timeViewStart, timeViewEnd),
      yDrawPositionPixels: (0, size.height),
      points: lane.points,
      strokeWidth: 2.0,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      clipStart: timeViewStart,
      clipEnd: timeViewEnd,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_GeneratorRowAutomationPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.generatorID != generatorID ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.ticksPerPixel != ticksPerPixel ||
        oldDelegate.color != color ||
        super.shouldRepaint(oldDelegate);
  }
}
