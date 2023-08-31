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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class ClipAutomation extends StatelessWidget {
  final PatternModel pattern;
  final ID? generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;

  const ClipAutomation({
    Key? key,
    required this.pattern,
    this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderBuilder(
      assetKey: 'assets/shaders/automation_curve.frag',
      (context, shader, child) {
        return CustomPaintObserver(
          painterBuilder: () => _ClipAutomationPainter(
            shader: shader,
            pattern: pattern,
            generatorID: generatorID,
            timeViewStart: timeViewStart,
            ticksPerPixel: ticksPerPixel,
            color: color,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        );
      },
    );
  }
}

class _ClipAutomationPainter extends CustomPainterObserver {
  final FragmentShader shader;
  final PatternModel pattern;
  final ID? generatorID;
  final double timeViewStart;
  final double ticksPerPixel;
  final Color color;
  final double devicePixelRatio;

  _ClipAutomationPainter({
    required this.shader,
    required this.pattern,
    this.generatorID,
    required this.timeViewStart,
    required this.ticksPerPixel,
    required this.color,
    required this.devicePixelRatio,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final timeViewEnd = timeViewStart + ticksPerPixel * size.width;

    for (final lane in pattern.automationLanes.values) {
      for (var i = 1; i < lane.points.length; i++) {
        final previousPoint = lane.points[i - 1];
        final thisPoint = lane.points[i];

        final lastPointX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: previousPoint.offset.toDouble(),
        );
        final pointX = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: thisPoint.offset.toDouble(),
        );

        if ((lastPointX < 0 && pointX < 0) ||
            (lastPointX > size.width && pointX > size.width)) {
          continue;
        }

        const strokeWidth = 2.0;

        final xOffset = (lastPointX - strokeWidth * 0.5);
        const yOffset = 0.0;

        drawCurve(
          canvas,
          shader,
          drawArea: Rectangle(
            xOffset,
            yOffset,
            pointX - lastPointX,
            size.height,
          ),
          devicePixelRatio: devicePixelRatio,
          firstPointValue: previousPoint.value,
          secondPointValue: thisPoint.value,
          tension: thisPoint.tension,
          strokeWidth: strokeWidth,
          color: color,
          gradientOpacityTop: 0.1,
          gradientOpacityBottom: 0.1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ClipAutomationPainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.generatorID != generatorID ||
        oldDelegate.timeViewStart != timeViewStart ||
        oldDelegate.ticksPerPixel != ticksPerPixel ||
        oldDelegate.color != color ||
        super.shouldRepaint(oldDelegate);
  }
}
