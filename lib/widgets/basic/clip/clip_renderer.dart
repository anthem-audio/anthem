/*
  Copyright (C) 2023 - 2025 Joshua Wade

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
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';

import 'clip.dart';

// Clips that are shorter than this will not render content
const smallSizeThreshold = 38;

const clipTitleHeight = 16;

typedef ClipRenderInfo = ({
  PatternModel pattern,
  ClipModel clip,
  double x,
  double y,
  double width,
  double height,
  bool selected,
  bool pressed,
});

void paintClipList({
  required Canvas canvas,
  required Size canvasSize,
  required Iterable<ClipRenderInfo> clipList,
  required double devicePixelRatio,
  required double timeViewStart,
  required double timeViewEnd,
  bool hideBorder = false,
}) {
  for (final clipEntry in clipList) {
    _paintContainer(
      canvas: canvas,
      pattern: clipEntry.pattern,
      x: clipEntry.x,
      y: clipEntry.y,
      width: clipEntry.width,
      height: clipEntry.height,
      selected: clipEntry.selected,
      pressed: clipEntry.pressed,
      hideBorder: hideBorder,
    );
  }

  for (final clipEntry in clipList) {
    _paintRestOfClip(
      canvas: canvas,
      canvasSize: canvasSize,
      pattern: clipEntry.pattern,
      clip: clipEntry.clip,
      x: clipEntry.x,
      y: clipEntry.y,
      width: clipEntry.width,
      height: clipEntry.height,
      selected: clipEntry.selected,
      pressed: clipEntry.pressed,
      devicePixelRatio: devicePixelRatio,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      hideBorder: hideBorder,
    );
  }
}

/// Paints a clip onto the given canvas with the given position and size.
void paintClip({
  required Canvas canvas,
  required Size canvasSize,
  required PatternModel pattern,
  ClipModel? clip,
  required double x,
  required double y,
  required double width,
  required double height,
  required bool selected,
  required bool pressed,
  required double devicePixelRatio,
  required double timeViewStart,
  required double timeViewEnd,
  bool hideBorder = false,
}) {
  _paintContainer(
    canvas: canvas,
    pattern: pattern,
    x: x,
    y: y,
    width: width,
    height: height,
    selected: selected,
    pressed: pressed,
    hideBorder: hideBorder,
  );

  _paintRestOfClip(
    canvas: canvas,
    canvasSize: canvasSize,
    pattern: pattern,
    x: x,
    y: y,
    width: width,
    height: height,
    selected: selected,
    pressed: pressed,
    devicePixelRatio: devicePixelRatio,
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
  );
}

void _paintContainer({
  required Canvas canvas,
  required PatternModel pattern,
  required double x,
  required double y,
  required double width,
  required double height,
  required bool selected,
  required bool pressed,
  bool hideBorder = false,
}) {
  final baseColor = getBaseColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  final rectPaint = Paint()..color = baseColor;
  final rectStrokePaint = Paint()
    ..color = AnthemTheme.grid.accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final rect = Rect.fromLTWH(
    x + (hideBorder ? 0 : 0.5),
    y + (hideBorder ? 0 : 0.5),
    width - (hideBorder ? 0 : 1),
    height - (hideBorder ? 0 : 1),
  );

  canvas.drawRect(rect, rectPaint);

  if (!hideBorder) {
    canvas.drawRect(rect, rectStrokePaint);
  }
}

void _paintRestOfClip({
  required Canvas canvas,
  required Size canvasSize,
  required PatternModel pattern,
  ClipModel? clip,
  required double x,
  required double y,
  required double width,
  required double height,
  required bool selected,
  required bool pressed,
  required double devicePixelRatio,
  required double timeViewStart,
  required double timeViewEnd,
  bool hideBorder = false,
}) {
  final baseColor = getBaseColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  final rect = Rect.fromLTWH(
    x + (hideBorder ? 0 : 0.5),
    y + (hideBorder ? 0 : 0.5),
    width - (hideBorder ? 0 : 1),
    height - (hideBorder ? 0 : 1),
  );

  final contentColor = getContentColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
  );

  // Title

  // Make sure we're observing both the name and the image cache
  final titleImage = pattern.renderedTitle;
  pattern.name;

  const textHeight = 15.0;
  final textY = height > smallSizeThreshold
      ? y
      : y + (height / 2) - (textHeight / 2);

  if (titleImage != null) {
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
      [contentColor],
      BlendMode.dstIn,
      null,
      Paint(),
    );
  } else {
    // Fallback if the image hasn't been generated yet
    drawPatternTitle(
      canvas: canvas,
      size: canvasSize,
      clipRect: rect,
      pattern: pattern,
      x: x,
      y: textY,
      width: width,
      height: height,
      selected: selected,
      pressed: pressed,
      // We don't need to manually handle device pixel ratio here since we're
      // drawing directly to the canvas, which already accounts for it.
      devicePixelRatio: 1,
    );
  }

  final transparentColor = baseColor.withAlpha(0);

  // Fade out gradient
  final textFadeOutGradient = Gradient.linear(
    Offset(x, textY),
    Offset(x + width - 3, textY),
    [transparentColor, transparentColor, baseColor],
    [0, 1 - (10 / width), 1],
  );

  final textFadeOutPaint = Paint()..shader = textFadeOutGradient;

  canvas.drawRect(
    Rect.fromLTWH(x, textY + 1, width - 1.5, textHeight),
    textFadeOutPaint,
  );

  // Notes

  // Subscribes to the update signal for notes in this pattern
  pattern.clipNotesUpdateSignal.value;

  if (height > smallSizeThreshold) {
    final contentColor = getContentColor(
      color: pattern.color,
      selected: selected,
      pressed: pressed,
    );

    final notePaint = Paint()..color = contentColor;

    for (final clipNotesEntry in pattern.clipNotesRenderCache.values) {
      if (clipNotesEntry.renderedVertices == null) continue;

      canvas.save();

      canvas.clipRect(Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2));

      final innerHeight = height - 2;

      final dist = clipNotesEntry.highestNote - clipNotesEntry.lowestNote;
      final notePadding =
          (innerHeight - clipTitleHeight) * (0.4 - dist * 0.05).clamp(0.1, 0.4);

      // The vertices for the notes are in a coordinate system based on notes,
      // where X is time and Y is normalized. The transformations below
      // translate this to the correct position and scale it to convert it into
      // pixel coordinates.

      final clipScaleFactor =
          (width - 1) /
          (clip?.width.toDouble() ?? pattern.getWidth().toDouble());

      canvas.translate(
        -(clip?.timeView?.start.toDouble() ?? 0.0) * clipScaleFactor,
        0,
      );
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

    canvas.save();

    // final timePerPixel = (timeViewEnd - timeViewStart) / canvasSize.width;

    final clipTimeViewStart = clip?.timeView?.start.toDouble() ?? 0;
    final clipTimeViewEnd =
        clip?.timeView?.end.toDouble() ?? pattern.getWidth().toDouble();

    canvas.saveLayer(null, Paint()..blendMode = BlendMode.plus);

    canvas.clipRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    for (final lane in pattern.automationLanes.values) {
      renderAutomationCurve(
        canvas,
        canvasSize,
        xDrawPositionTime: (
          (clip?.offset.toDouble() ?? 0.0),
          ((clip?.offset ?? 0) + (clip?.width ?? 0)).toDouble(),
        ),
        yDrawPositionPixels: (y + clipTitleHeight + 1, y + height - 1),
        points: lane.points,
        strokeWidth: 2.0,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        clipStart: clipTimeViewStart,
        clipEnd: clipTimeViewEnd,
        clipOffset: clip?.offset.toDouble() ?? 0.0,
        color: const Color(0xFF777777),
      );
    }

    canvas.restore();

    canvas.restore();
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
    textColor = getContentColor(
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

  canvas.drawParagraph(paragraph, Offset(x + 3, y));
}
