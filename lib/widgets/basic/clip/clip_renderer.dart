/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'clip_title_text.dart';

// For automation rendering
final _automationLineBuffer = LineBuffer();
final _automationLineJoinBuffer = CoordinateBuffer();
final _automationTriCoordBuffer = CoordinateBuffer();

// Clips that are shorter than this will not render content
const _smallSizeThreshold = 38;

const _clipTitleHeight = 16;
const _clipTitlePadding = clipTitlePadding;

const _contentBaseColor = Color(0xFF777777);

class ClipRenderInfo {
  final PatternModel pattern;
  final String clipId;
  final String trackId;
  final bool hasTimingOverride;
  final int clipOffset;
  final int clipWidth;
  final double clipTimeViewStart;
  final double clipTimeViewEnd;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool selected;
  final bool pressed;
  final bool hovered;

  ClipRenderInfo({
    required this.pattern,
    required ClipModel clip,
    required this.hasTimingOverride,
    required this.clipOffset,
    required int clipTimeViewStart,
    required int clipTimeViewEnd,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.selected,
    required this.pressed,
    required this.hovered,
  }) : assert(clipTimeViewEnd > clipTimeViewStart),
       clipId = clip.id,
       trackId = clip.trackId,
       clipWidth = clipTimeViewEnd - clipTimeViewStart,
       clipTimeViewStart = clipTimeViewStart.toDouble(),
       clipTimeViewEnd = clipTimeViewEnd.toDouble();
}

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
      hovered: clipEntry.hovered,
      hideBorder: hideBorder,
    );
  }

  // Begin blend mode layer
  canvas.saveLayer(null, Paint()..blendMode = BlendMode.plus);
  try {
    // The buffers are global for allocation efficiency, so clear before and
    // after use to avoid stale draw data if rendering throws midway through.
    _automationTriCoordBuffer.clear();
    _automationLineBuffer.clear();
    _automationLineJoinBuffer.clear();

    for (final clipEntry in clipList) {
      final pattern = clipEntry.pattern;

      final y = clipEntry.y;
      final height = clipEntry.height;

      if (height <= _smallSizeThreshold) continue;

      final lane = pattern.automation;
      renderAutomationCurve(
        canvas: canvas,
        canvasSize: canvasSize,
        xDrawPositionTime: (
          clipEntry.clipOffset.toDouble(),
          (clipEntry.clipOffset + clipEntry.clipWidth).toDouble(),
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
        clipStart: clipEntry.clipTimeViewStart,
        clipEnd: clipEntry.clipTimeViewEnd,
        clipOffset: clipEntry.clipOffset.toDouble(),
        color: _contentBaseColor,

        lineBuffer: _automationLineBuffer,
        lineJoinBuffer: _automationLineJoinBuffer,
        triCoordBuffer: _automationTriCoordBuffer,

        correctForClipBounds: true,
      );

      // This avoids connecting lines between clips.
      _automationLineBuffer.disconnectNext();
    }

    final automationShadedPaint = Paint()
      ..color = const Color(0x19FFFFFF)
      ..style = PaintingStyle.fill;

    final linePaint = getLinePaint(
      chosenColor: _contentBaseColor,
      strokeWidth: 2.0,
    );

    final lineJoinCirclePaint = getLineJoinPaint(
      chosenColor: _contentBaseColor,
      strokeWidth: 2.0,
    );

    final notePaint = Paint()..color = _contentBaseColor;

    // This aliases on Skia, but we draw a line along the main boundary that
    // would alias, so it works out well on Skia platforms (as of writing,
    // this is Windows, Linux, and web). Also this is extremely fast.
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

    // Title

    // Make sure we're observing necessary MobX observables
    for (var entry in clipList) {
      entry.pattern.name;
      entry.pattern.clipNotesUpdateSignal.value;
    }

    const textHeight = 15.0;

    final sequence = project.sequence;
    final spriteSheet = sequence.patternTitleTexture;
    final textureAtlas = spriteSheet.textureAtlas;
    final atlasRectsByPatternId = sequence.clipTitleAtlasRectsByPatternId;

    final isTextureAtlasDevicePixelRatioMatch =
        textureAtlas != null &&
        sequence.clipTitleTextureAtlasDevicePixelRatio == devicePixelRatio;

    if (isTextureAtlasDevicePixelRatioMatch) {
      var clipEntriesWithAtlasRectCount = 0;
      var hasClipEntriesWithoutAtlasRect = false;

      for (final clipEntry in clipList) {
        if (atlasRectsByPatternId[clipEntry.pattern.id] != null) {
          clipEntriesWithAtlasRectCount++;
        } else {
          hasClipEntriesWithoutAtlasRect = true;
        }
      }

      if (clipEntriesWithAtlasRectCount > 0) {
        var cursor = 0;

        ClipRenderInfo nextClipEntryWithAtlasRect() {
          while (cursor < clipList.length) {
            final clipEntry = clipList[cursor++];
            if (atlasRectsByPatternId[clipEntry.pattern.id] != null) {
              return clipEntry;
            }
          }

          throw StateError(
            'Expected clip entry with atlas rect while generating drawAtlas '
            'inputs.',
          );
        }

        final transforms = List.generate(clipEntriesWithAtlasRectCount, (i) {
          final clipEntry = nextClipEntryWithAtlasRect();
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
        }, growable: false);

        cursor = 0;
        final rects = List.generate(clipEntriesWithAtlasRectCount, (i) {
          final clipEntry = nextClipEntryWithAtlasRect();
          final rect = atlasRectsByPatternId[clipEntry.pattern.id]!;
          return Rect.fromLTWH(
            rect.left,
            rect.top,
            min(
              rect.width,
              (clipEntry.width - _clipTitlePadding * 2) * devicePixelRatio,
            ),
            rect.height,
          );
        }, growable: false);

        canvas.drawAtlas(
          textureAtlas,
          transforms,
          rects,
          List.generate(clipEntriesWithAtlasRectCount, (i) {
            return _contentBaseColor;
          }, growable: false),
          BlendMode.dstIn,
          null,
          Paint(),
        );
      }

      // A new pattern can exist in the arrangement before its title has been
      // packed into the shared atlas. In that case, fall back to direct title
      // rendering for that clip instead of crashing the entire paint pass.
      if (hasClipEntriesWithoutAtlasRect) {
        for (final clipEntry in clipList) {
          if (atlasRectsByPatternId[clipEntry.pattern.id] != null) continue;

          _drawClipTitleDirect(
            canvas: canvas,
            canvasSize: canvasSize,
            clipEntry: clipEntry,
            textHeight: textHeight,
          );
        }
      }
    } else {
      // Fallback if the atlas hasn't been generated yet, or if it was built
      // for a different device pixel ratio.
      _drawClipTitlesDirect(
        canvas: canvas,
        canvasSize: canvasSize,
        clipList: clipList,
        textHeight: textHeight,
      );
    }

    // Notes
    for (final clipEntry in clipList) {
      _paintClipNotes(
        canvas: canvas,
        notePaint: notePaint,
        pattern: clipEntry.pattern,
        clipContentWidth: clipEntry.clipWidth.toDouble(),
        clipTimeViewStart: clipEntry.clipTimeViewStart,
        x: clipEntry.x,
        y: clipEntry.y,
        width: clipEntry.width,
        height: clipEntry.height,
      );
    }
  } finally {
    _automationTriCoordBuffer.clear();
    _automationLineBuffer.clear();
    _automationLineJoinBuffer.clear();
    canvas.restore();
  }

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
  bool hovered = false,
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
    hovered: hovered,
    hideBorder: hideBorder,
  );

  canvas.saveLayer(null, Paint()..blendMode = BlendMode.plus);
  try {
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
      overrideTextColor: _contentBaseColor,
    );

    // Automation

    if (height > _smallSizeThreshold) {
      renderAutomationCurve(
        canvas: canvas,
        canvasSize: canvasSize,
        xDrawPositionTime: clip != null
            ? (clip.offset.toDouble(), (clip.offset + clip.width).toDouble())
            : (0.0, 0.0),
        yDrawPositionPixels: (y + _clipTitleHeight + 2, y + height - 2),
        points: pattern.automation.points,
        strokeWidth: 2.0,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        color: _contentBaseColor,
      );
    }

    // Notes

    if (height > _smallSizeThreshold) {
      _paintClipNotes(
        canvas: canvas,
        notePaint: Paint()..color = _contentBaseColor,
        pattern: pattern,
        clipContentWidth:
            clip?.width.toDouble() ?? pattern.getWidth().toDouble(),
        clipTimeViewStart: clip?.timeView?.start.toDouble() ?? 0.0,
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }
  } finally {
    canvas.restore();
  }
}

void _drawClipTitlesDirect({
  required Canvas canvas,
  required Size canvasSize,
  required List<ClipRenderInfo> clipList,
  required double textHeight,
}) {
  for (final clipEntry in clipList) {
    _drawClipTitleDirect(
      canvas: canvas,
      canvasSize: canvasSize,
      clipEntry: clipEntry,
      textHeight: textHeight,
    );
  }
}

void _drawClipTitleDirect({
  required Canvas canvas,
  required Size canvasSize,
  required ClipRenderInfo clipEntry,
  required double textHeight,
}) {
  final pattern = clipEntry.pattern;
  final y = clipEntry.y;
  final height = clipEntry.height;

  final textY = height > _smallSizeThreshold
      ? y
      : y + (height / 2) - (textHeight / 2);
  final rect = Rect.fromLTWH(clipEntry.x, textY, clipEntry.width, textHeight);

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
    // Match the atlas render path tint to avoid visible color shifts while
    // a title is waiting to be packed into the shared atlas.
    overrideTextColor: _contentBaseColor,
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
  required bool hovered,
  bool hideBorder = false,
}) {
  final baseColor = getBaseColor(
    color: pattern.color,
    selected: selected,
    pressed: pressed,
    hovered: hovered,
  );

  final rectPaint = Paint()..color = baseColor;

  final rect = Rect.fromLTWH(
    x + (hideBorder ? 0 : 0.5),
    y + (hideBorder ? 0 : 0.5),
    width - (hideBorder ? 0 : 1),
    height - (hideBorder ? 0 : 1),
  );

  canvas.drawRect(rect, rectPaint);

  if (selected) {
    final strokeColor = getSelectedBorderColor(color: pattern.color);

    final selectedRectPaint = Paint()
      ..color = strokeColor
      ..style = .stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), .circular(1)),
      selectedRectPaint,
    );
  }
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

  drawClipTitleText(
    canvas: canvas,
    title: pattern.name,
    x: x,
    y: y,
    width: width,
    devicePixelRatio: devicePixelRatio,
    textColor: textColor,
  );
}

(double, double) getClipTitleSize({
  required double devicePixelRatio,
  required PatternModel pattern,
}) {
  return getClipTitleTextSize(
    devicePixelRatio: devicePixelRatio,
    title: pattern.name,
  );
}

void _paintClipNotes({
  required Canvas canvas,
  required Paint notePaint,
  required PatternModel pattern,
  required double clipContentWidth,
  required double clipTimeViewStart,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  if (height <= _smallSizeThreshold) return;

  final clipNotesEntry = pattern.clipNotesRenderCache;
  if (clipNotesEntry.renderedVertices == null) return;

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

  final clipScaleFactor = (width - 1) / clipContentWidth;

  canvas.translate(-clipTimeViewStart * clipScaleFactor, 0);
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
