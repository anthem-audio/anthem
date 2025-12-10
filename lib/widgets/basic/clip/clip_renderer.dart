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

import 'dart:math';
import 'dart:ui';

import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/curve_renderer.dart';

import 'clip.dart';

// For automation rendering
final _automationLineBuffer = LineBuffer();
final _automationLineJoinBuffer = CoordinateBuffer();
final _automationTriCoordBuffer = CoordinateBuffer();

// Clips that are shorter than this will not render content
const _smallSizeThreshold = 38;

const _clipTitleHeight = 16;
const _clipTitlePadding = 2;

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
  required ProjectModel project,
  required Canvas canvas,
  required Size canvasSize,
  required List<ClipRenderInfo> clipList,
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

  // Begin blend mode layer
  canvas.saveLayer(null, Paint()..blendMode = BlendMode.plus);

  final timePerPixel = (timeViewEnd - timeViewStart) / canvasSize.width;

  for (final clipEntry in clipList) {
    final pattern = clipEntry.pattern;
    final clip = clipEntry.clip;

    final clipTimeViewStart = clip.timeView?.start.toDouble() ?? 0;
    final clipTimeViewEnd =
        clip.timeView?.end.toDouble() ?? pattern.getWidth().toDouble();

    final y = clipEntry.y;
    final height = clipEntry.height;

    if (height <= _smallSizeThreshold) continue;

    for (final lane in pattern.automationLanes.values) {
      renderAutomationCurve(
        canvas: canvas,
        canvasSize: canvasSize,
        xDrawPositionTime: (
          clip.offset.toDouble(),
          (clip.offset + clip.width).toDouble(),
        ),
        yDrawPositionPixels: (y + _clipTitleHeight + 2, y + height - 2),
        points: lane.points,
        strokeWidth: 2.0,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,

        // The use of timePerPixel here scales the automation curve in the X
        // direction so that it does not draw across the clip boundary. This
        // makes the positioning very slightly incorrect, but since we can't
        // render-clip the draw call around the entire DAW clip (due to
        // performance concerns), we have to get the automation to draw within
        // the DAW clip boundaries without any render clipping.
        clipStart: clipTimeViewStart + timePerPixel * 2,
        clipEnd: clipTimeViewEnd,
        clipOffset: clip.offset.toDouble() + timePerPixel,
        color: const Color(0xFF777777),

        lineBuffer: _automationLineBuffer,
        lineJoinBuffer: _automationLineJoinBuffer,
        triCoordBuffer: _automationTriCoordBuffer,
      );

      // This avoids connecting lines between clips.
      _automationLineBuffer.disconnectNext();
    }
  }

  final automationShadedPaint = Paint()
    ..color = const Color(0x19FFFFFF)
    ..style = PaintingStyle.fill;

  final linePaint = getLinePaint(
    chosenColor: const Color(0xFF777777),
    strokeWidth: 2.0,
  );

  final lineJoinCirclePaint = getLineJoinPaint(
    chosenColor: const Color(0xFF777777),
    strokeWidth: 2.0,
  );

  final notePaint = Paint()..color = const Color(0xFF777777);

  // This aliases on Skia, but we draw a line along the main boundary that would
  // alias, so it works out well on Skia platforms (as of writing, this is
  // Windows, Linux, and web). Also this is extremely fast.
  canvas.drawVertices(
    Vertices.raw(VertexMode.triangles, _automationTriCoordBuffer.buffer),
    BlendMode.srcOver,
    automationShadedPaint,
  );

  canvas.drawRawPoints(
    PointMode.lines,
    _automationLineBuffer.buffer,
    linePaint,
  );

  canvas.drawRawPoints(
    PointMode.points,
    _automationLineJoinBuffer.buffer,
    lineJoinCirclePaint,
  );

  _automationTriCoordBuffer.clear();
  _automationLineBuffer.clear();
  _automationLineJoinBuffer.clear();

  // Title

  // Make sure we're observing necessary MobX observables
  for (var entry in clipList) {
    entry.pattern.name;
    entry.pattern.clipNotesUpdateSignal.value;
  }

  const textHeight = 15.0;

  final sequence = project.sequence;
  final spriteSheet = sequence.patternTitleTexture;

  if (spriteSheet.textureAtlas != null) {
    canvas.drawAtlas(
      spriteSheet.textureAtlas!,
      List.generate(clipList.length, (i) {
        final clipEntry = clipList[i];
        return RSTransform.fromComponents(
          rotation: 0,
          scale: 1 / devicePixelRatio,
          anchorX: 0,
          anchorY: 0,
          translateX: clipEntry.x,
          translateY:
              clipEntry.y +
              (clipEntry.height > _smallSizeThreshold
                  ? 0
                  : (clipEntry.height / 2) - (textHeight / 2)),
        );
      }, growable: false),
      List.generate(clipList.length, (i) {
        final pattern = clipList[i].pattern;
        return Rect.fromLTWH(
          pattern.clipTitleAtlasRect!.left,
          pattern.clipTitleAtlasRect!.top,
          min(
            pattern.clipTitleAtlasRect!.width,
            (clipList[i].width - _clipTitlePadding * 2) * devicePixelRatio,
          ),
          pattern.clipTitleAtlasRect!.height,
        );
      }, growable: false),
      List.generate(clipList.length, (i) {
        return const Color(0xFF777777);
      }, growable: false),
      BlendMode.dstIn,
      null,
      Paint(),
    );
  } else {
    // Fallback if the image hasn't been generated yet
    for (final clipEntry in clipList) {
      final pattern = clipEntry.pattern;
      final y = clipEntry.y;
      final height = clipEntry.height;

      final textY = height > _smallSizeThreshold
          ? y
          : y + (height / 2) - (textHeight / 2);
      final rect = Rect.fromLTWH(
        clipEntry.x,
        textY,
        clipEntry.width,
        textHeight,
      );

      final x = clipEntry.x;
      final width = clipEntry.width;
      final selected = clipEntry.selected;
      final pressed = clipEntry.pressed;
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
  }

  // Notes

  for (final clipEntry in clipList) {
    _paintClipNotes(
      canvas: canvas,
      notePaint: notePaint,
      pattern: clipEntry.pattern,
      clip: clipEntry.clip,
      x: clipEntry.x,
      y: clipEntry.y,
      width: clipEntry.width,
      height: clipEntry.height,
    );
  }

  // End blend mode layer
  canvas.restore();

  if (!hideBorder) {
    for (final clipEntry in clipList) {
      _paintContainerBorder(
        canvas: canvas,
        pattern: clipEntry.pattern,
        x: clipEntry.x,
        y: clipEntry.y,
        width: clipEntry.width,
        height: clipEntry.height,
      );
    }
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

  canvas.saveLayer(null, Paint()..blendMode = BlendMode.plus);

  // Title

  drawPatternTitle(
    canvas: canvas,
    size: canvasSize,
    clipRect: Rect.fromLTWH(x, y, width, height),
    pattern: pattern,
    x: x,
    y: y,
    width: width,
    height: height,
    selected: selected,
    pressed: pressed,
    devicePixelRatio: 1,
    overrideTextColor: const Color(0xFF777777),
  );

  // Automation

  for (final lane in pattern.automationLanes.values) {
    if (height <= _smallSizeThreshold) continue;

    renderAutomationCurve(
      canvas: canvas,
      canvasSize: canvasSize,
      xDrawPositionTime: clip != null
          ? (clip.offset.toDouble(), (clip.offset + clip.width).toDouble())
          : (0.0, 0.0),
      yDrawPositionPixels: (y + _clipTitleHeight + 2, y + height - 2),
      points: lane.points,
      strokeWidth: 2.0,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      color: const Color(0xFF777777),
    );
  }

  // Notes

  if (height > _smallSizeThreshold) {
    _paintClipNotes(
      canvas: canvas,
      notePaint: Paint()..color = const Color(0xFF777777),
      pattern: pattern,
      clip: clip,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  canvas.restore();
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

  final rect = Rect.fromLTWH(
    x + (hideBorder ? 0 : 0.5),
    y + (hideBorder ? 0 : 0.5),
    width - (hideBorder ? 0 : 1),
    height - (hideBorder ? 0 : 1),
  );

  canvas.drawRect(rect, rectPaint);
}

void _paintContainerBorder({
  required Canvas canvas,
  required PatternModel pattern,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final rect = Rect.fromLTWH(x + 0.5, y + 0.5, width - 1, height - 1);

  final rectStrokePaint = Paint()
    ..color = AnthemTheme.grid.accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  canvas.drawRect(rect, rectStrokePaint);
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
  Color? overrideTextColor,
  bool selected = false,
  bool pressed = false,
  bool saveLayer = true,
}) {
  final Color textColor;

  if (overrideTextColor != null) {
    textColor = overrideTextColor;
  } else {
    textColor = getContentColor(
      color: pattern.color,
      selected: selected,
      pressed: pressed,
    );
  }

  final paragraphStyle = ParagraphStyle(textAlign: TextAlign.left, maxLines: 1);

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(color: textColor, fontSize: 11 * devicePixelRatio))
    ..addText(pattern.name);

  final paragraph = paragraphBuilder.build();
  final constraints = ParagraphConstraints(
    width: width - _clipTitlePadding * 2 + 2,
  );
  paragraph.layout(constraints);

  canvas.drawParagraph(paragraph, Offset(x + _clipTitlePadding + 1, y));
}

(double, double) getClipTitleSize({
  required double devicePixelRatio,
  required PatternModel pattern,
}) {
  // We hardcode the height for now
  const height = _clipTitleHeight;

  // Width is based on the pattern name length
  final paragraphStyle = ParagraphStyle(
    textAlign: TextAlign.left,
    ellipsis: '...',
    maxLines: 1,
  );

  final paragraphBuilder = ParagraphBuilder(paragraphStyle)
    ..pushStyle(TextStyle(fontSize: 11 * devicePixelRatio))
    ..addText(pattern.name);

  final paragraph = paragraphBuilder.build();
  final constraints = ParagraphConstraints(width: double.infinity);
  paragraph.layout(constraints);

  final width = paragraph.maxIntrinsicWidth / devicePixelRatio + 6;

  return (width, height.toDouble());
}

void _paintClipNotes({
  required Canvas canvas,
  required Paint notePaint,
  required PatternModel pattern,
  ClipModel? clip,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  if (height <= _smallSizeThreshold) return;

  for (final clipNotesEntry in pattern.clipNotesRenderCache.values) {
    if (clipNotesEntry.renderedVertices == null) continue;

    canvas.save();

    canvas.clipRect(Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2));

    final innerHeight = height - 2;

    final dist = clipNotesEntry.highestNote - clipNotesEntry.lowestNote;
    final notePadding =
        (innerHeight - _clipTitleHeight) * (0.4 - dist * 0.05).clamp(0.1, 0.4);

    // The vertices for the notes are in a coordinate system based on notes,
    // where X is time and Y is normalized. The transformations below
    // translate this to the correct position and scale it to convert it into
    // pixel coordinates.

    final clipScaleFactor =
        (width - 1) / (clip?.width.toDouble() ?? pattern.getWidth().toDouble());

    canvas.translate(
      -(clip?.timeView?.start.toDouble() ?? 0.0) * clipScaleFactor,
      0,
    );
    canvas.translate(x + 1, y + 1 + _clipTitleHeight + notePadding);
    canvas.scale(
      clipScaleFactor,
      innerHeight - _clipTitleHeight - notePadding * 2,
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
