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

// Clips that are shorter than this will not render content
const smallSizeThreshold = 38;

const clipTitleHeight = 16;

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

  const textHeight = 15.0;
  final textY =
      height > smallSizeThreshold ? y : y + (height / 2) - (textHeight / 2);

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
          translateY: textY,
        ),
      ],
      [rect],
      [textColor],
      BlendMode.dstIn,
      null,
      Paint(),
    );
  } else {
    // Fallback if the image hasn't been generated yet
    drawPatternTitle(
      canvas: canvas,
      size: size,
      clipRect: rect,
      pattern: pattern,
      x: x,
      y: textY,
      width: width,
      height: height,
      selected: selected,
      pressed: pressed,
      devicePixelRatio: devicePixelRatio,
    );
  }

  final transparentColor = color.withAlpha(0);

  // Fade out gradient
  final textFadeOutGradient = Gradient.linear(
    Offset(x, textY),
    Offset(x + width - 3, textY),
    [transparentColor, transparentColor, color],
    [0, 1 - (10 / width), 1],
  );

  final textFadeOutPaint = Paint()..shader = textFadeOutGradient;

  canvas.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(x, textY + 1, width - 1.5, textHeight),
      topRight: const Radius.circular(3),
    ),
    textFadeOutPaint,
  );

  // Notes

  // Subscribes to the update signal for notes in this pattern
  pattern.clipNotesUpdateSignal.value;

  if (height > smallSizeThreshold) {
    final noteColor = getTextColor(
      color: pattern.color,
      selected: selected,
      pressed: pressed,
    );

    final notePaint = Paint()..color = noteColor;

    for (final clipNotesEntry in pattern.clipNotesRenderCache.values) {
      if (clipNotesEntry.renderedVertices == null) continue;

      canvas.save();

      canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2),
        const Radius.circular(3),
      ));

      final innerHeight = height - 2;

      final dist = clipNotesEntry.highestNote - clipNotesEntry.lowestNote;
      final notePadding =
          (innerHeight - clipTitleHeight) * (0.4 - dist * 0.05).clamp(0.1, 0.4);

      // The vertices for the notes are in a coordinate system based on notes,
      // where X is time and Y is normalized. The transformations below
      // translate this to the correct position and scale it to convert it into
      // pixel coordnates.

      final clipScaleFactor =
          (width - 1) / clip.getWidth(pattern.project).toDouble();

      canvas.translate(
          -(clip.timeView?.start.toDouble() ?? 0.0) * clipScaleFactor, 0);
      canvas.translate(x + 1, y + 1 + clipTitleHeight + notePadding);
      canvas.scale(
        clipScaleFactor,
        innerHeight - clipTitleHeight - notePadding * 2,
      );

      // The clip may not start at the beginning, which we account for here.

      canvas.drawVertices(
        clipNotesEntry.renderedVertices!,
        BlendMode.srcOver,
        notePaint,
      );

      canvas.restore();
    }
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
