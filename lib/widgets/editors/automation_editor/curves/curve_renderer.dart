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
import 'dart:ui';

import 'package:flutter_shaders/flutter_shaders.dart';

/// This function renders an automation curve on the given canvas with the given
/// parameters.
///
/// The [FragmentShader] parameter is the `automation_curve.frag` shader, which
/// can be provided in the widget tree like so:
///
/// ```dart
/// ShaderBuilder(
///   assetKey: 'assets/shaders/automation_curve.frag',
///   (context, shader, child) {
///     // 'shader' is the FragmentShader we're looking for
///   },
/// );
/// ```
///
/// As of the time of writing, this code assumes a canvas that doesn't take DPI
/// into account (e.g. a [PictureRecorder] canvas). This may need adjustments to
/// work on a regular canvas.
void drawCurve(
  Canvas canvas,
  FragmentShader shader, {
  required Rectangle<double> drawArea,
  required double devicePixelRatio,
  required double firstPointValue,
  required double secondPointValue,
  required double tension,
  required double strokeWidth,
  required Color color,
  required double gradientOpacityTop,
  required double gradientOpacityBottom,
}) {
  shader.setFloatUniforms((setter) {
    // lastPoint!;

    setter.setFloat(drawArea.width);
    setter.setFloat(drawArea.height);
    setter.setFloat(devicePixelRatio);

    setter.setFloat(drawArea.left);
    setter.setFloat(drawArea.top);

    setter.setFloat(firstPointValue);
    setter.setFloat(secondPointValue);
    setter.setFloat(tension);

    setter.setFloat(strokeWidth * 0.5);
    setter.setFloat(strokeWidth * 0.5);

    setter.setFloat(strokeWidth * 0.5);

    setter.setColor(color);
    setter.setFloat(gradientOpacityTop);
    setter.setFloat(gradientOpacityBottom);
  });

  final paint = Paint()..shader = shader;

  canvas.drawRect(
    Rect.fromLTWH(
      drawArea.left,
      drawArea.top,
      drawArea.width + 0.5 * strokeWidth * 2 * devicePixelRatio,
      drawArea.height,
    ),
    paint,
  );
}
