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

import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/editors/automation_editor/curves/smooth.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem_codegen/include/collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

typedef AutomationPoint = ({
  double offset,
  double value,
  double tension,
  AutomationCurveType curve,
});

var _pointBuffer = Float32List(200 * 2);
var _lineJoinBuffer = Float32List(200 * 2);
var _triCoordBuffer = Float32List(200 * 12);

void _resizeIfNeededForPointIndex(int pointIndex) {
  if (pointIndex * 2 < _pointBuffer.length) return;

  var newPointBufferSize = _pointBuffer.length;

  while (pointIndex * 2 >= newPointBufferSize) {
    newPointBufferSize *= 2;
  }

  final newPointBuffer = Float32List(newPointBufferSize);
  newPointBuffer.setRange(0, _pointBuffer.length, _pointBuffer);
  _pointBuffer = newPointBuffer;

  final newLineJoinBuffer = Float32List(newPointBufferSize);
  newLineJoinBuffer.setRange(0, _lineJoinBuffer.length, _lineJoinBuffer);
  _lineJoinBuffer = newLineJoinBuffer;

  final newTriCoordBuffer = Float32List(newPointBufferSize * 6);
  newTriCoordBuffer.setRange(0, _triCoordBuffer.length, _triCoordBuffer);
  _triCoordBuffer = newTriCoordBuffer;
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
    if (!result) {
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
void renderAutomationCurve(
  Canvas canvas,
  Size canvasSize, {
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
}) {
  if (points.length < 2) return;

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

  if (points.isEmpty) return;

  final chosenColor = color ?? AnthemTheme.primary.main;

  final linePaint = Paint()
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

  // Paint for circles that we manually add to simulate round line joins
  final lineJoinCirclePaint = Paint()
    ..color = chosenColor
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.fill;

  const gradientStartAlpha = 0.05;
  const gradientEndAlpha = 0.25;

  final gradientPaint = Paint()
    ..shader = LinearGradient(
      colors: [
        chosenColor.withValues(alpha: gradientStartAlpha),
        chosenColor.withValues(alpha: gradientEndAlpha),
      ],
      stops: const [0.0, 1.0],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ).createShader(drawArea)
    ..style = PaintingStyle.fill;

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

  var pointCount = 0;
  var lineJoinCount = 0;

  double valueToY(double value) =>
      drawArea.top + drawArea.height * (1.0 - value);

  if (!willCutOffStart) {
    _resizeIfNeededForPointIndex(pointCount + 1);
    _pointBuffer[pointCount * 2] = startX.toDouble();
    _pointBuffer[pointCount * 2 + 1] = valueToY(automationPoints.first.value);
    pointCount++;
  }

  // We will use this to track if the curve has changed between evaluations. If
  // it has, then we will add an extra point that is exactly on the boundary,
  // which fixes some sampling artifacts.
  (int firstIndex, int secondIndex)? mostRecentCurve;
  // These are used to track curvature. If the curvature at a point is below a
  // threshold, we can skip the point segment, which should significantly reduce
  // the number of line segments drawn in most cases.
  ({double x, double y}) curvePointA = (
    x: startX,
    y: valueToY(_evaluateCurve(startTime - clipOffset, automationPoints)),
  );
  ({double x, double y})? curvePointB;

  if (willCutOffStart) {
    // Add point A
    _resizeIfNeededForPointIndex(pointCount + 1);
    _pointBuffer[pointCount * 2] = curvePointA.x;
    _pointBuffer[pointCount * 2 + 1] = curvePointA.y;
    pointCount++;
  }

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
        if (curvePointB != null) {
          _resizeIfNeededForPointIndex(pointCount + 1);
          _pointBuffer[pointCount * 2] = curvePointB.x;
          _pointBuffer[pointCount * 2 + 1] = curvePointB.y;
          pointCount++;
        }

        final x = timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: canvasSize.width,
          time: automationPoints[i].offset - (clipStart ?? 0.0) + clipOffset,
        );
        final y = valueToY(automationPoints[i].value);

        _resizeIfNeededForPointIndex(pointCount + 1);
        _pointBuffer[pointCount * 2] = x;
        _pointBuffer[pointCount * 2 + 1] = y;

        _lineJoinBuffer[lineJoinCount * 2] = x;
        _lineJoinBuffer[lineJoinCount * 2 + 1] = y;

        lineJoinCount++;

        curvePointA = (x: x, y: y);
        curvePointB = null;

        pointCount++;
      }
    }

    // _currentCurveCache is set by _evaluateCurve to the segment (pair of
    // points) where the most recent time was found.
    mostRecentCurve = _currentCurveCache;

    if (curvePointB == null) {
      curvePointB = (x: x, y: y);
      continue;
    }

    ({double x, double y}) curvePointC = (x: x, y: y);

    // We need to check the angle between AB and BC
    final angleAB = atan2approx(
      curvePointB.y - curvePointA.y,
      curvePointB.x - curvePointA.x,
    );
    final angleBC = atan2approx(
      curvePointC.y - curvePointB.y,
      curvePointC.x - curvePointB.x,
    );
    final angleDifference = (angleBC - angleAB).abs();

    // We also get the pixel distance. As the distance grows, we must shrink the
    // angle threshold to avoid artifacts with very shallow curves (happens when
    // zooming way in).
    final double squarePixelDistance;
    {
      // Good ol' Pythagoras
      // AB distance squared + BC squared is just AC distance squared, so we'll
      // calculate that instead
      final dx = curvePointC.x - curvePointA.x;
      final dy = curvePointC.y - curvePointA.y;
      squarePixelDistance = dx * dx + dy * dy;
    }

    // Adjust for aggressiveness - higher removes more points
    const double angleDistanceFactor = 0.1;
    final threshold = pi * angleDistanceFactor / sqrt(squarePixelDistance);

    const double lineJoinAngleThresholdFactor = 2.0;
    final lineJoinThreshold = threshold * lineJoinAngleThresholdFactor;

    // This evaluation is to determine if we should keep point B (the point from
    // the previous iteration)
    if (angleDifference < threshold) {
      // Skip this point
      curvePointB = curvePointC;
    } else {
      final iX = pointCount * 2;
      final iY = pointCount * 2 + 1;

      _resizeIfNeededForPointIndex(pointCount + 1);
      _pointBuffer[iX] = curvePointB.x;
      _pointBuffer[iY] = curvePointB.y;

      pointCount++;

      if (angleDifference >= lineJoinThreshold) {
        // Add a circle at this point to simulate a round line join
        final ljX = lineJoinCount * 2;
        final ljY = lineJoinCount * 2 + 1;

        _lineJoinBuffer[ljX] = curvePointB.x;
        _lineJoinBuffer[ljY] = curvePointB.y;

        lineJoinCount++;
      }

      curvePointA = curvePointB;
      curvePointB = curvePointC;
    }
  }

  // If there is a remaining curve point B, add it
  if (curvePointB != null) {
    _resizeIfNeededForPointIndex(pointCount + 1);
    _pointBuffer[pointCount * 2] = curvePointB.x;
    _pointBuffer[pointCount * 2 + 1] = curvePointB.y;
    pointCount++;
  }

  _resizeIfNeededForPointIndex(pointCount + 1);
  _pointBuffer[pointCount * 2] = endX.toDouble();
  _pointBuffer[pointCount * 2 + 1] = valueToY(
    _evaluateCurve(endTime - clipOffset + (clipStart ?? 0.0), automationPoints),
  );
  pointCount++;

  // Create geometry for gradient fill
  void createTrianglesForPoints(
    double x1,
    double y1,
    double x2,
    double y2,
    int segmentIndex,
  ) {
    final baseY = drawArea.top + drawArea.height;

    final i = segmentIndex * 12;

    _triCoordBuffer[i] = x1;
    _triCoordBuffer[i + 1] = y1;
    _triCoordBuffer[i + 2] = x2;
    _triCoordBuffer[i + 3] = y2;
    _triCoordBuffer[i + 4] = x2;
    _triCoordBuffer[i + 5] = baseY;

    final j = i + 6;

    _triCoordBuffer[j] = x1;
    _triCoordBuffer[j + 1] = y1;
    _triCoordBuffer[j + 2] = x2;
    _triCoordBuffer[j + 3] = baseY;
    _triCoordBuffer[j + 4] = x1;
    _triCoordBuffer[j + 5] = baseY;
  }

  for (int i = 0; i < pointCount - 1; i++) {
    final x1 = _pointBuffer[2 * i];
    final y1 = _pointBuffer[2 * i + 1];
    final x2 = _pointBuffer[2 * (i + 1)];
    final y2 = _pointBuffer[2 * (i + 1) + 1];

    createTrianglesForPoints(x1, y1, x2, y2, i);
  }

  final segmentCount = pointCount - 1;
  final vertexFloatCount = segmentCount * 12; // 2 triangles per segment

  // This aliases on Skia, but we draw a line along the main boundary that would
  // alias, so it works out well on Skia platforms (as of writing, this is
  // Windows, Linux, and web). Also this is extremely fast.
  canvas.drawVertices(
    Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_triCoordBuffer, 0, vertexFloatCount),
    ),
    BlendMode.srcOver,
    gradientPaint,
  );

  canvas.drawRawPoints(
    PointMode.polygon,
    Float32List.sublistView(_pointBuffer, 0, pointCount * 2),
    linePaint,
  );

  canvas.drawRawPoints(
    PointMode.points,
    Float32List.sublistView(_lineJoinBuffer, 0, lineJoinCount * 2),
    lineJoinCirclePaint,
  );
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
