/*
  Copyright (C) 2022 - 2025 Joshua Wade

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

import 'package:anthem/color_shifter.dart';
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
  final Id? clipId;
  final Id? patternId;
  final Id? arrangementId;
  final double ticksPerPixel;
  final bool selected;
  final bool hasResizeHandles;
  final bool pressed;
  final bool hideBorder;

  /// Creates a Clip widget tied to a ClipModel
  const Clip({
    super.key,
    required this.clipId,
    required this.arrangementId,
    required this.ticksPerPixel,
    this.selected = false,
    this.hasResizeHandles = true,
    this.pressed = false,
    this.hideBorder = false,
  }) : patternId = null;

  /// Creates a Clip widget tied to a PatternModel
  const Clip.fromPattern({
    super.key,
    required this.patternId,
    required this.ticksPerPixel,
    this.hasResizeHandles = false,
    this.pressed = false,
    this.hideBorder = false,
  }) : selected = false,
       clipId = null,
       arrangementId = null;

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final clipModel =
        projectModel.sequence.arrangements[arrangementId]?.clips[clipId];
    final patternModel =
        projectModel.sequence.patterns[clipModel?.patternId ?? patternId!]!;

    return ShaderBuilder(assetKey: 'assets/shaders/automation_curve.frag', (
      context,
      shader,
      child,
    ) {
      return CustomPaintObserver(
        painterBuilder: () => ClipPainter(
          curveShader: shader,
          devicePixelRatio: View.of(context).devicePixelRatio,
          pattern: patternModel,
          hideBorder: hideBorder,
        ),
      );
    });
  }
}

class ClipPainter extends CustomPainterObserver {
  final FragmentShader curveShader;
  final double devicePixelRatio;
  final PatternModel pattern;
  final ClipModel? clip;
  final bool hideBorder;

  ClipPainter({
    required this.curveShader,
    required this.devicePixelRatio,
    required this.pattern,
    this.clip,
    this.hideBorder = false,
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
      hideBorder: hideBorder,
    );
  }

  @override
  bool shouldRepaint(ClipPainter oldDelegate) =>
      devicePixelRatio != oldDelegate.devicePixelRatio ||
      pattern != oldDelegate.pattern ||
      clip != oldDelegate.clip ||
      super.shouldRepaint(oldDelegate);
}

final _selectedColorShifter = AnthemColorShifter(
  166,
  lightnessModifier: 1.2,
  saturationModifier: 1.0,
);

Color getBaseColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final shifter = selected ? _selectedColorShifter : color.colorShifter;
  final okColor = shifter.clipBase;

  if (pressed) {
    return okColor.darker(0.15).saturate(okColor.s > 0 ? 0.1 : 0).toColor();
  }

  return okColor.toColor();
}

Color getContentColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final shifter = selected ? _selectedColorShifter : color.colorShifter;
  final okColor = shifter.clipText;

  if (pressed) {
    return okColor.darker(0.15).saturate(okColor.s > 0 ? 0.1 : 0).toColor();
  }

  return okColor.toColor();
}
