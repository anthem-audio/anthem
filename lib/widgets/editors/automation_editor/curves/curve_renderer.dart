/*
  Copyright (C) 2025 Joshua Wade

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

import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/smooth.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem_codegen/include/collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

class CoordinateBuffer {
  Float32List _buffer = Float32List(512);
  int _length = 0;
  int get coordinateCount => _length ~/ 2;

  Float32List get buffer => Float32List.sublistView(_buffer, 0, _length);
  Float32List get bufferRaw => _buffer;

  void add(double x, double y) {
    if ((_length + 2) > _buffer.length) {
      final newBuffer = Float32List(_buffer.length * 2);
      newBuffer.setRange(0, _buffer.length, _buffer);
      _buffer = newBuffer;
    }

    _buffer[_length] = x;
    _buffer[_length + 1] = y;
    _length += 2;
  }

  void clear() {
    _length = 0;
  }
}

class LineBuffer {
  Float32List _buffer = Float32List(512);
  int _length = 0;
  bool _nextIsDisjoint = true;
  int get lineCount => _length ~/ 4;

  Float32List get buffer => Float32List.sublistView(_buffer, 0, _length);
  Float32List get bufferRaw => _buffer;

  double lastX = 0.0;
  double lastY = 0.0;

  (double x1, double y1, double x2, double y2)? add(double x, double y) {
    if (_nextIsDisjoint) {
      lastX = x;
      lastY = y;
      _nextIsDisjoint = false;
      return null;
    }

    if ((_length + 4) > _buffer.length) {
      final newBuffer = Float32List(_buffer.length * 2);
      newBuffer.setRange(0, _buffer.length, _buffer);
      _buffer = newBuffer;
    }

    _buffer[_length] = lastX;
    _buffer[_length + 1] = lastY;
    _buffer[_length + 2] = x;
    _buffer[_length + 3] = y;

    final result = (lastX, lastY, x, y);

    lastX = x;
    lastY = y;

    _length += 4;

    return result;
  }

  void clear() {
    _length = 0;
    _nextIsDisjoint = true;
  }

  /// If called, the next point added will not create a line segment from the
  /// last point.
  void disconnectNext() {
    _nextIsDisjoint = true;
  }
}

/// Class to abstract the downsampling of incoming automation line points to
/// reduce the number of points drawn.
class _DownsamplingCurveBuilder {
  final LineBuffer lineBuffer;
  final CoordinateBuffer lineJoinBuffer;
  final CoordinateBuffer triCoordBuffer;

  ({double x, double y})? _curvePointA;
  ({double x, double y})? _curvePointB;
  bool _pointBIsHandle = false;

  double baseY;

  _DownsamplingCurveBuilder({
    required this.lineBuffer,
    required this.lineJoinBuffer,
    required this.triCoordBuffer,
    required this.baseY,
  });

  /// Adds a point to the downsampler.
  ///
  /// [baseY] is the y-coordinate of the bottom of the curve. It should be equal
  /// to the pixel Y value that corresponds to a normalized Y value of 0 for the
  /// automation curve.
  void addPoint(double x, double y, [bool isHandle = false]) {
    // These are used to track curvature. If the curvature at a point is below a
    // threshold, we can skip the point segment, which should significantly
    // reduce the number of line segments drawn in most cases.
    final pointA = _curvePointA;
    final pointB = _curvePointB;
    final pointC = (x: x, y: y);

    if (pointA == null) {
      _addToLineBuffer(baseY, x, y);
      _curvePointA = pointC;
      return;
    }

    if (pointB == null) {
      _curvePointB = pointC;
      return;
    }

    // We need to check the angle between AB and BC
    final angleAB = atan2approx(
      _curvePointB!.y - pointA.y,
      _curvePointB!.x - pointA.x,
    );
    final angleBC = atan2approx(pointC.y - pointB.y, pointC.x - pointB.x);
    final angleDifference = (angleBC - angleAB).abs();

    // We also get the pixel distance. As the distance grows, we must shrink the
    // angle threshold to avoid artifacts with very shallow curves (happens when
    // zooming way in).
    final double squarePixelDistance;
    {
      // AB distance squared + BC squared is just AC distance squared, so we'll
      // calculate that instead
      //
      // Technically this isn't quite right (should be ab distance + bc
      // distance), but it seems to be close enough in practice.
      final dx = pointC.x - pointA.x;
      final dy = pointC.y - pointA.y;
      squarePixelDistance = dx * dx + dy * dy;
    }

    // Adjust for aggressiveness - higher removes more points
    const double angleDistanceFactor = 0.1;
    final threshold = pi * angleDistanceFactor / sqrt(squarePixelDistance);

    const double lineJoinAngleThresholdFactor = 2.0;
    final lineJoinThreshold = threshold * lineJoinAngleThresholdFactor;

    bool addToLineJoin = false;

    // This evaluation is to determine if we should keep point B (the point from
    // the previous iteration)
    if (angleDifference < threshold ||
        // For handles, we always add them. This means that they may be
        // extremely close to the last sampled point that came through. In some
        // cases this produces nearly double the points unless we detect this
        // case.
        //
        // When we have a handle point, we manually check its distance, and if
        // it is indeed extremely close to either the point before or after it,
        // we skip it. In practice this happens quite often.
        ((isHandle || _pointBIsHandle) && squarePixelDistance < 1.0)) {
      // Skip this point
      _curvePointB = pointC;
    } else {
      _addToLineBuffer(baseY, pointB.x, pointB.y);

      if (angleDifference >= lineJoinThreshold) {
        // Add a circle at this point to simulate a round line join
        addToLineJoin = true;
      }

      _curvePointA = pointB;
      _curvePointB = pointC;
    }

    if (addToLineJoin || isHandle) {
      lineJoinBuffer.add(pointB.x, pointB.y);
    }

    if (isHandle) {
      _pointBIsHandle = true;
    } else {
      _pointBIsHandle = false;
    }
  }

  void finish() {
    final pointB = _curvePointB;

    if (pointB != null) {
      _addToLineBuffer(baseY, pointB.x, pointB.y);
    }
  }

  // Create geometry for gradient fill
  void _createTrianglesForPoints(double x1, double y1, double x2, double y2) {
    // First triangle
    triCoordBuffer.add(x1, y1);
    triCoordBuffer.add(x2, y2);
    triCoordBuffer.add(x2, baseY);

    // Second triangle
    triCoordBuffer.add(x1, y1);
    triCoordBuffer.add(x2, baseY);
    triCoordBuffer.add(x1, baseY);
  }

  void _addToLineBuffer(double baseY, double x, double y) {
    final result = lineBuffer.add(x, y);

    if (result != null) {
      final (x1, y1, x2, y2) = result;
      _createTrianglesForPoints(x1, y1, x2, y2);
    }
  }
}

typedef AutomationPoint = ({
  double offset,
  double value,
  double tension,
  AutomationCurveType curve,
});

final _lineBuffer = LineBuffer();
final _lineJoinBuffer = CoordinateBuffer();
final _triCoordBuffer = CoordinateBuffer();

Paint getLinePaint({required Color chosenColor, required double strokeWidth}) {
  return Paint()
    ..color = chosenColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    // drawRawPoints draws a bunch of straight lines with two stroke caps each.
    //
    // StrokeCap.round looks okay, but is many times slower and quickly becomes
    // a bottleneck. StrokeCap.square is free as it just lengthens the line, but
    // produces minor artifacts at each point - it looks like the line is very
    // slightly wider at each point, which is very often. StrokeCap.butt
    // produces a VERY slight gap between segments, which is annoying but less
    // noticeable.
    //
    // StrokeCap.butt does look very bad when we have very sharp curves, so the
    // final trick is that we draw a bunch of circles (drawRawPoints with
    // StrokeCap.round and PointMode.points), which is much faster than capping
    // the lines with a round cap, even if we draw a circle at every point.
    // Then, we can choose when to draw those circles based on curvature, which
    // further reduces the already small overhead, and produces a decent end
    // result.
    ..strokeCap = StrokeCap.butt;
}

/// Paint for circles that we manually add to simulate round line joins
Paint getLineJoinPaint({
  required Color chosenColor,
  required double strokeWidth,
}) {
  return Paint()
    ..color = chosenColor
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.fill;
}

Paint getGradientPaint({
  required Color chosenColor,
  required Rect drawArea,
  required double gradientStartAlpha,
  required double gradientEndAlpha,
  Color? overrideColor,
}) {
  return Paint()
    ..shader = LinearGradient(
      colors: [
        (overrideColor ?? chosenColor).withValues(alpha: gradientStartAlpha),
        (overrideColor ?? chosenColor).withValues(alpha: gradientEndAlpha),
      ],
      stops: const [0.0, 1.0],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ).createShader(drawArea)
    ..style = PaintingStyle.fill;
}

/// Caches the last accessed curve segment for _evaluateCurve.
///
/// Since we will call evaluateCurve in order, this will prevent us from
/// searching on every call, which is likely measurable in at least some cases.
(int firstIndex, int secondIndex) _currentCurveCache = (0, 1);

/// Evaluates the curve at the given time using the provided list of points.
double _evaluateCurve(double time, List<AutomationPoint> points) {
  // Floating point math is causing this to be very slightly negative sometimes
  // when rendering offset clips.
  if (time < 0.0) time = 0.0;

  assert(
    points.length >= 2,
    'At least two points are required to evaluate the curve.',
  );

  // Check if the cached segment is valid
  var (firstIndex, secondIndex) = _currentCurveCache;

  if (secondIndex >= points.length) {
    firstIndex = 0;
    secondIndex = 1;
  }

  if (time >= points[firstIndex].offset && time <= points[secondIndex].offset) {
    // Cache hit
  } else {
    // Cache miss - find the correct segment
    bool testStartingAt(int startIndex) {
      for (int i = startIndex; i < points.length - 1; i++) {
        if (time >= points[i].offset && time <= points[i + 1].offset) {
          firstIndex = i;
          secondIndex = i + 1;
          _currentCurveCache = (firstIndex, secondIndex);
          return true;
        }
      }

      return false;
    }

    // Start at the last known first index, which is most likely
    final result = testStartingAt(_currentCurveCache.$1);

    if (time > points[points.length - 1].offset) {
      firstIndex = points.length - 2;
      secondIndex = points.length - 1;
      _currentCurveCache = (firstIndex, secondIndex);
      return points.last.value;
    }

    if (!result) {
      if (time < points[0].offset) {
        firstIndex = 0;
        secondIndex = 1;
        _currentCurveCache = (firstIndex, secondIndex);
        return points.first.value;
      }

      testStartingAt(0); // Fallback to start if not found
    }
  }

  final firstPoint = points[firstIndex];
  final secondPoint = points[secondIndex];

  switch (secondPoint.curve) {
    case AutomationCurveType.smooth:
      return evaluateSmooth(
                (time - firstPoint.offset) /
                    (secondPoint.offset - firstPoint.offset),
                secondPoint.tension,
              ) *
              (secondPoint.value - firstPoint.value) +
          firstPoint.value;
    case AutomationCurveType.stairs:
      throw UnimplementedError();
    case AutomationCurveType.wave:
      throw UnimplementedError();
    case AutomationCurveType.hold:
      return firstPoint.value;
  }
}

/// Renders the automation curve given by [points] onto the provided [canvas].
///
/// See usage examples in the automation editor and arranger.
///
/// This method samples the curve at one-pixel intervals (device independent),
/// and then aggressively downsamples the resulting points, removing over 85% of
/// the points in most common cases. It then uses these points to draw the
/// curve, using Canvas.drawRawPoints for the line, and Canvas.drawVertices for
/// the gradient fill below the curve.
///
/// The result of rendering the downsampled points is nearly indistinguishable
/// from rendering with all the points. The aggressiveness of the downsampling
/// can be adjusted below.
void renderAutomationCurve({
  required Canvas canvas,
  required Size canvasSize,
  required (double, double) xDrawPositionTime,
  required (double, double) yDrawPositionPixels,
  required AnthemObservableList<AutomationPointModel> points,
  required double strokeWidth,
  Color? color,

  required double timeViewStart,
  required double timeViewEnd,

  // If this is rendering in a clip, this defines the time range of the clip view
  double? clipStart,
  double? clipEnd,

  double clipOffset = 0.0,

  LineBuffer? lineBuffer,
  CoordinateBuffer? lineJoinBuffer,
  CoordinateBuffer? triCoordBuffer,

  bool correctForClipBounds = false,
}) {
  if (points.length < 2) return;

  points.observeAllChanges();
  beginObservationBlockFor(points);

  // We don't clear incoming buffers, as they will be reused across multiple
  // clip renders. If we're using our own internal buffers, we clear them.
  //
  // If we have incoming buffers, we also do not paint in this function.
  final shouldPaintAndClear =
      lineBuffer == null || lineJoinBuffer == null || triCoordBuffer == null;

  lineBuffer ??= _lineBuffer;
  lineJoinBuffer ??= _lineJoinBuffer;
  triCoordBuffer ??= _triCoordBuffer;

  final xDrawPositionPixels = (
    timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: canvasSize.width,
      time: xDrawPositionTime.$1,
    ),
    timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: canvasSize.width,
      time: xDrawPositionTime.$2,
    ),
  );

  final drawArea = Rect.fromLTWH(
    xDrawPositionPixels.$1,
    yDrawPositionPixels.$1,
    xDrawPositionPixels.$2 - xDrawPositionPixels.$1,
    yDrawPositionPixels.$2 - yDrawPositionPixels.$1,
  );

  final baseY = drawArea.top + drawArea.height;

  if (points.isEmpty) return;

  // The hope is that these will be much better inlined than the full objects,
  // and so a lot faster to work with
  List<AutomationPoint> automationPoints = List.generate(points.length, (i) {
    final p = points[i];
    return (
      offset: p.offset.toDouble(),
      value: p.value,
      tension: p.tension,
      curve: p.curve,
    );
  });

  double startTime;
  double endTime;

  if (clipStart == null) {
    startTime = points.first.offset.toDouble() + clipOffset;
  } else {
    startTime = clipOffset;
  }

  endTime = points.last.offset.toDouble() + clipOffset - (clipStart ?? 0.0);
  if (clipStart != null && clipEnd != null) {
    endTime = min(endTime, clipEnd + clipOffset - clipStart);
  }

  // This prevents the curve from rendering slightly before the start of the
  // clip.
  if (correctForClipBounds) {
    final timePerPixel = (timeViewEnd - timeViewStart) / canvasSize.width;
    startTime += timePerPixel;
  }

  var startX = timeToPixels(
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    viewPixelWidth: canvasSize.width,
    time: startTime,
  );

  var endX = timeToPixels(
    timeViewStart: timeViewStart,
    timeViewEnd: timeViewEnd,
    viewPixelWidth: canvasSize.width,
    time: endTime,
  );

  // Whether the start of the curve is cut off by the view
  final willCutOffStart = startX < 0;

  // Whether the end of the curve is cut off by the view
  final willCutOffEnd = endX > canvasSize.width;

  if (willCutOffStart) {
    startX = 0;
    startTime = pixelsToTime(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: canvasSize.width,
      pixelOffsetFromLeft: startX,
    );
  }

  if (willCutOffEnd) {
    endX = canvasSize.width;
    endTime = pixelsToTime(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: canvasSize.width,
      pixelOffsetFromLeft: endX,
    );
  }

  double valueToY(double value) =>
      drawArea.top + drawArea.height * (1.0 - value);

  // We will use this to track if the curve has changed between evaluations. If
  // it has, then we will add an extra point that is exactly on the boundary,
  // which fixes some sampling artifacts.
  (int firstIndex, int secondIndex)? mostRecentCurve;

  final _DownsamplingCurveBuilder curveBuilder = _DownsamplingCurveBuilder(
    lineBuffer: lineBuffer,
    lineJoinBuffer: lineJoinBuffer,
    triCoordBuffer: triCoordBuffer,
    baseY: baseY,
  );

  // Sample points along the curve
  for (double x = startX; x <= endX; x += 1.0) {
    final xToTime = pixelsToTime(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: canvasSize.width,
      pixelOffsetFromLeft: x,
    );
    final timeInClip = xToTime - clipOffset + (clipStart ?? 0.0);
    final value = _evaluateCurve(timeInClip, automationPoints);
    final y = valueToY(value);

    // This adds one point for each actual handle
    if (mostRecentCurve != null && mostRecentCurve != _currentCurveCache) {
      for (var i = mostRecentCurve.$2; i < _currentCurveCache.$2; i++) {
        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: canvasSize.width,
          time: automationPoints[i].offset - (clipStart ?? 0.0) + clipOffset,
        );
        final y = valueToY(automationPoints[i].value);

        curveBuilder.addPoint(x, y, true);
        lineJoinBuffer.add(x, y);
      }
    }

    // _currentCurveCache is set by _evaluateCurve to the segment (pair of
    // points) where the most recent time was found.
    mostRecentCurve = _currentCurveCache;

    curveBuilder.addPoint(x, y);
  }

  curveBuilder.addPoint(
    endX.toDouble(),
    valueToY(
      _evaluateCurve(
        endTime - clipOffset + (clipStart ?? 0.0),
        automationPoints,
      ),
    ),
  );

  curveBuilder.finish();

  if (shouldPaintAndClear) {
    final chosenColor = color ?? AnthemTheme.primary.main;

    final linePaint = getLinePaint(
      chosenColor: chosenColor,
      strokeWidth: strokeWidth,
    );

    final lineJoinCirclePaint = getLineJoinPaint(
      chosenColor: color ?? AnthemTheme.primary.main,
      strokeWidth: strokeWidth,
    );

    const gradientStartAlpha = 0.05;
    const gradientEndAlpha = 0.25;

    final gradientPaint = getGradientPaint(
      chosenColor: chosenColor,
      drawArea: drawArea,
      gradientStartAlpha: gradientStartAlpha,
      gradientEndAlpha: gradientEndAlpha,
    );

    // This aliases on Skia, but we draw a line along the main boundary that would
    // alias, so it works out well on Skia platforms (as of writing, this is
    // Windows, Linux, and web). Also this is extremely fast.
    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, curveBuilder.triCoordBuffer.buffer),
      BlendMode.srcOver,
      gradientPaint,
    );

    canvas.drawRawPoints(
      PointMode.lines,
      curveBuilder.lineBuffer.buffer,
      linePaint,
    );

    canvas.drawRawPoints(
      PointMode.points,
      curveBuilder.lineJoinBuffer.buffer,
      lineJoinCirclePaint,
    );

    triCoordBuffer.clear();
    lineBuffer.clear();
    lineJoinBuffer.clear();
  }

  endObservationBlockFor(points);
}

const double pi4Plus0273 = pi / 4.0 + 0.273;
const double pi2 = pi / 2.0;

// Based on https://github.com/ducha-aiki/fast_atan2/blob/master/fast_atan.cpp
double atan2approx(double y, double x) {
  final double absY = y.abs();
  final double absX = x.abs();

  // In Dart, booleans can't be used as ints, so use ? 1 : 0.
  final int octant =
      ((x < 0 ? 1 : 0) << 2) +
      ((y < 0 ? 1 : 0) << 1) +
      ((absX <= absY) ? 1 : 0);

  switch (octant) {
    case 0:
      {
        if (x == 0 && y == 0) {
          return 0.0;
        }
        final double val = absY / absX;
        return (pi4Plus0273 - 0.273 * val) * val; // 1st octant
      }
    case 1:
      {
        if (x == 0 && y == 0) {
          return 0.0;
        }
        final double val = absX / absY;
        return pi2 - (pi4Plus0273 - 0.273 * val) * val; // 2nd octant
      }
    case 2:
      {
        final double val = absY / absX;
        return -(pi4Plus0273 - 0.273 * val) * val; // 8th octant
      }
    case 3:
      {
        final double val = absX / absY;
        return -pi2 + (pi4Plus0273 - 0.273 * val) * val; // 7th octant
      }
    case 4:
      {
        final double val = absY / absX;
        return pi - (pi4Plus0273 - 0.273 * val) * val; // 4th octant
      }
    case 5:
      {
        final double val = absX / absY;
        return pi2 + (pi4Plus0273 - 0.273 * val) * val; // 3rd octant
      }
    case 6:
      {
        final double val = absY / absX;
        return -pi + (pi4Plus0273 - 0.273 * val) * val; // 5th octant
      }
    case 7:
      {
        final double val = absX / absY;
        return -pi2 - (pi4Plus0273 - 0.273 * val) * val; // 6th octant
      }
    default:
      return 0.0;
  }
}
