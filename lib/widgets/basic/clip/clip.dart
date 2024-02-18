/*
  Copyright (C) 2022 - 2023 Joshua Wade

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

import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:provider/provider.dart';

class Clip extends StatelessWidget {
  final ID? clipID;
  final ID? patternID;
  final ID? arrangementID;
  final double ticksPerPixel;
  final bool selected;
  final bool hasResizeHandles;
  final bool pressed;

  /// Creates a Clip widget tied to a ClipModel
  const Clip({
    Key? key,
    required this.clipID,
    required this.arrangementID,
    required this.ticksPerPixel,
    this.selected = false,
    this.hasResizeHandles = true,
    this.pressed = false,
  })  : patternID = null,
        super(key: key);

  /// Creates a Clip widget tied to a PatternModel
  const Clip.fromPattern({
    Key? key,
    required this.patternID,
    required this.ticksPerPixel,
    this.hasResizeHandles = false,
    this.pressed = false,
  })  : selected = false,
        clipID = null,
        arrangementID = null,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final clipModel =
        projectModel.song.arrangements[arrangementID]?.clips[clipID];
    final patternModel =
        projectModel.song.patterns[clipModel?.patternID ?? patternID!]!;

    return ShaderBuilder(
      assetKey: 'assets/shaders/automation_curve.frag',
      (context, shader, child) {
        return CustomPaintObserver(
          painterBuilder: () => ClipPainter(
            curveShader: shader,
            devicePixelRatio: View.of(context).devicePixelRatio,
            pattern: patternModel,
          ),
        );
      },
    );
  }
}

class ClipPainter extends CustomPainterObserver {
  final FragmentShader curveShader;
  final double devicePixelRatio;
  final PatternModel pattern;
  final ClipModel? clip;

  ClipPainter({
    required this.curveShader,
    required this.devicePixelRatio,
    required this.pattern,
    this.clip,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    paintClip(
      canvas: canvas,
      curveShader: curveShader,
      canvasSize: size,
      pattern: pattern,
      x: 0,
      y: 0,
      width: size.width,
      height: size.height,
      selected: false,
      pressed: false,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  bool shouldRepaint(ClipPainter oldDelegate) =>
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      pattern != oldDelegate.pattern ||
      clip != oldDelegate.clip ||
      super.shouldRepaint(oldDelegate);
}

Color getBaseColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final hue = selected ? 166.0 : color.hue;
  var saturation =
      selected ? 0.6 : (0.28 * color.saturationMultiplier).clamp(0.0, 1.0);
  var lightness =
      selected ? 0.31 : (0.49 * color.lightnessMultiplier).clamp(0.0, 0.92);

  if (pressed) {
    saturation = (saturation * 0.9).clamp(0.0, 1.0);
    lightness = (lightness - 0.1).clamp(0.0, 1.0);
  }

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}

Color getTextColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final hue = selected ? 166.0 : color.hue;
  var saturation =
      selected ? 1.0 : (1 * color.saturationMultiplier).clamp(0.0, 1.0);
  var lightness =
      selected ? 0.92 : (0.92 * color.lightnessMultiplier).clamp(0.0, 0.92);

  if (pressed) {
    saturation = (saturation * 0.9).clamp(0.0, 1.0);
    lightness = (lightness - 0.1).clamp(0.0, 1.0);
  }

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}

Color getContentColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final hue = selected ? 166.0 : color.hue;
  var saturation =
      selected ? 0.7 : (0.7 * color.saturationMultiplier).clamp(0.0, 1.0);
  var lightness =
      selected ? 0.78 : (0.78 * color.lightnessMultiplier).clamp(0.0, 0.92);

  if (pressed) {
    saturation = (saturation * 0.9).clamp(0.0, 1.0);
    lightness = (lightness - 0.1).clamp(0.0, 1.0);
  }

  return HSLColor.fromAHSL(
    1,
    hue,
    saturation,
    lightness,
  ).toColor();
}
