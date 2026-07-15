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
import 'package:anthem/widgets/editors/arranger/rendering/clip_renderer.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Clip extends StatelessWidget {
  final Id clipId;
  final double ticksPerPixel;
  final bool selected;
  final bool hasResizeHandles;
  final bool hideBorder;

  /// Creates a Clip widget tied to a ClipModel
  const Clip({
    super.key,
    required this.clipId,
    required this.ticksPerPixel,
    this.selected = false,
    this.hasResizeHandles = true,
    this.hideBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final projectModel = Provider.of<ProjectModel>(context);
    final clipModel = projectModel.sequence.arrangement.clips[clipId]!;
    final patternModel = projectModel.sequence.patterns[clipModel.patternId]!;
    final color = projectModel.tracks[clipModel.trackId]!.color;

    return CustomPaint(
      painter: ClipPainter(
        pattern: patternModel,
        color: color,
        clip: clipModel,
        hideBorder: hideBorder,
      ),
    );
  }
}

class ClipPainter extends CustomPainterObserver {
  final PatternModel pattern;
  final AnthemColor color;
  final ClipModel? clip;
  final bool hideBorder;

  ClipPainter({
    required this.pattern,
    required this.color,
    this.clip,
    this.hideBorder = false,
  }) : super(debugName: 'ClipPainter');

  @override
  void observablePaint(Canvas canvas, Size size) {
    paintClip(
      canvas: canvas,
      canvasSize: size,
      pattern: pattern,
      color: color,
      clip: clip,
      x: 0,
      y: 0,
      width: size.width,
      height: size.height,
      selected: false,
      hideBorder: hideBorder,
      timeViewStart: 0,
      timeViewEnd: pattern.getWidth().toDouble(),
    );
  }

  @override
  bool shouldRepaint(ClipPainter oldDelegate) =>
      pattern != oldDelegate.pattern ||
      color != oldDelegate.color ||
      clip != oldDelegate.clip ||
      hideBorder != oldDelegate.hideBorder;
}

Color getBaseColor({
  required AnthemColor color,
  required bool selected,
  bool hovered = false,
}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipBase;

  if (hovered) {
    okColor = okColor.lighter(0.15);
  }

  return okColor.darker(selected ? 0.23 : 0).toColor();
}

Color getContentColor({required AnthemColor color, required bool selected}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipText;

  return okColor.darker(selected ? 0.1 : 0).toColor();
}

Color getSelectedBorderColor({required AnthemColor color}) {
  final shifter = color.colorShifter;
  var okColor = shifter.clipText;

  return okColor.lighter(0.1).toColor();
}
