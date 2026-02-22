/*
  Copyright (C) 2022 - 2026 Joshua Wade

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
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:flutter/widgets.dart';
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

    return CustomPaintObserver(
      painterBuilder: () => ClipPainter(
        devicePixelRatio: View.of(context).devicePixelRatio,
        pattern: patternModel,
        hideBorder: hideBorder,
      ),
    );
  }
}

class ClipPainter extends CustomPainterObserver {
  final double devicePixelRatio;
  final PatternModel pattern;
  final ClipModel? clip;
  final bool hideBorder;

  ClipPainter({
    required this.devicePixelRatio,
    required this.pattern,
    this.clip,
    this.hideBorder = false,
  });

  @override
  void observablePaint(Canvas canvas, Size size) {
    paintClip(
      canvas: canvas,
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
      timeViewStart: 0,
      timeViewEnd: pattern.getWidth().toDouble(),
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
  bool hovered = false,
}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipBase;

  if (pressed) {
    okColor = okColor.darker(0.15).saturate(okColor.s > 0 ? 0.1 : 0);
  } else if (hovered) {
    okColor = okColor.lighter(0.15);
  }

  return okColor.darker(selected ? 0.23 : 0).toColor();
}

Color getContentColor({
  required AnthemColor color,
  required bool selected,
  required bool pressed,
}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipText;

  if (pressed) {
    okColor = okColor.darker(0.15).saturate(okColor.s > 0 ? 0.1 : 0);
  }

  return okColor.darker(selected ? 0.1 : 0).toColor();
}

Color getSelectedBorderColor({required AnthemColor color}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipText;

  return okColor.lighter(0.1).toColor();
}
