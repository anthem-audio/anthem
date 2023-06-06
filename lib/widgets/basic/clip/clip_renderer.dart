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
  required double devicePixelRatio,
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

  // Make sure we're observing both the name and the image cache
  final titleImage = pattern.renderedTitle;
  pattern.name;

  if (titleImage != null) {
    final textColor = getTextColor(
      color: pattern.color,
      selected: selected,
      pressed: pressed,
    );

    final rect = Rect.fromLTWH(0, 0, (width - 2) * devicePixelRatio, height);

    canvas.drawAtlas(
      titleImage,
      [
        RSTransform.fromComponents(
          rotation: 0,
          scale: 1 / devicePixelRatio,
          anchorX: 0,
          anchorY: 0,
          translateX: x,
          translateY: y,
        ),
      ],
      [rect],
      [textColor],
      BlendMode.dstIn,
      null,
      Paint(),
    );

    final transparentColor = color.withAlpha(0);

    // Fade out gradient
    final textFadeOutGradient = Gradient.linear(
      Offset(x, y),
      Offset(x + width - 3, y),
      [transparentColor, transparentColor, color],
      [0, 1 - (10 / width), 1],
    );

    final textFadeOutPaint = Paint()..shader = textFadeOutGradient;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y + 1, width - 1, 15),
        topRight: const Radius.circular(3),
      ),
      textFadeOutPaint,
    );
  } else {
    // Fallback if the image hasn't been generated yet
    drawPatternTitle(
      canvas: canvas,
      size: size,
      clipRect: rect,
      pattern: pattern,
      x: x,
      y: y,
      width: width,
      height: height,
      selected: selected,
      pressed: pressed,
      devicePixelRatio: devicePixelRatio,
    );
  }
}

void drawPatternTitle({
  required Canvas canvas,
  required Size size,
  required Rect clipRect,
  required PatternModel pattern,
  required double x,
  required double y,
  required double width,
  required double height,
  required double devicePixelRatio,
  bool whiteText = false,
  bool selected = false,
  bool pressed = false,
  bool saveLayer = true,
}) {
  final Color textColor;
  if (whiteText) {
    textColor = const Color(0xFFFFFFFF);
  } else {
    textColor = getTextColor(
      color: pattern.color,
      selected: selected,
      pressed: pressed,
    );
  }

  final paragraphStyle = ParagraphStyle(
    textAlign: TextAlign.left,
    ellipsis: '...',
    maxLines: 1,
  );

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(color: textColor, fontSize: 11 * devicePixelRatio))
    ..addText(pattern.name);

  final paragraph = paragraphBuilder.build();
  final constraints = ParagraphConstraints(width: width);
  paragraph.layout(constraints);

  canvas.drawParagraph(
    paragraph,
    Offset(x + 3, y),
  );
}
