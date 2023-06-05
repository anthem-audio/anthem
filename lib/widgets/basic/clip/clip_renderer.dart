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

import 'dart:ui';

import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/theme.dart';

import 'clip.dart';

/// Paints a clip onto the given canvas with the given position and size.
void paintClip({
  required Canvas canvas,
  required Size size,
  required PatternModel pattern,
  required ClipModel clip,
  required double x,
  required double y,
  required double width,
  required double height,
  required bool selected,
  required bool pressed,
}) {
  // Container

  final color = getBaseColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  final rectPaint = Paint()..color = color;
  final rectStrokePaint = Paint()
    ..color = Theme.grid.accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final rect = Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1);
  final rRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1),
    const Radius.circular(3),
  );

  canvas.drawRRect(rRect, rectPaint);
  canvas.drawRRect(rRect, rectStrokePaint);

  // Title

  // This is drawn in two steps into a separate layer, which is then composited
  // back into the main layer. The first step is to draw the text with our
  // preferred color. The second step is to draw over the text with a gradient
  // that fades from white to transparent, and to set the blend mode to
  // BlendMode.dstIn when we do it. This has the effect of fading the text out
  // with the same gradient, but with the text color we selected instead of
  // white.

  canvas.saveLayer(rect, Paint());

  final textColor = getTextColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  final paragraphStyle = ParagraphStyle(
    textAlign: TextAlign.left,
  );

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(color: textColor, fontSize: 11))
    ..addText(pattern.name);

  final paragraph = paragraphBuilder.build();
  final constraints = ParagraphConstraints(width: size.width);
  paragraph.layout(constraints);

  canvas.drawParagraph(
    paragraph,
    Offset(x + 3, y),
  );

  // Fade out gradient
  final textFadeOutGradient = Gradient.linear(
    Offset(x, y),
    Offset(x + width - 3, y),
    const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00000000)],
    [0, 1 - (10 / width), 1],
  );

  final textPaint = Paint()
    ..shader = textFadeOutGradient
    ..blendMode = BlendMode.dstIn;

  canvas.drawRect(Rect.fromLTWH(x, y, width, height), textPaint);

  canvas.restore();
}
