/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:math' as math;

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';

const _defaultMinWidth = 10.0;
const _defaultEndOverscrollFraction = 0.5;
const _defaultPatternFallbackBars = 16;
const _defaultArrangementFallbackBars = 4;

class TimeRangeContentBounds {
  final double start;
  final double end;
  final double minWidth;
  final double endOverscrollFraction;

  const TimeRangeContentBounds({
    this.start = 0,
    required this.end,
    this.minWidth = _defaultMinWidth,
    this.endOverscrollFraction = _defaultEndOverscrollFraction,
  }) : assert(end >= start),
       assert(minWidth > 0),
       assert(endOverscrollFraction >= 0),
       assert(endOverscrollFraction < 1);

  double get width => end - start;
}

enum _TimeRangeContentSourceKind { fixed, activePattern, pattern, arrangement }

class TimeRangeContentSource {
  final _TimeRangeContentSourceKind _kind;
  final Id? _sequenceId;
  final double _fixedStart;
  final double? _fixedEnd;
  final int fallbackBars;
  final double minWidth;
  final double endOverscrollFraction;

  const TimeRangeContentSource.fixed({
    double start = 0,
    required double end,
    this.minWidth = _defaultMinWidth,
    this.endOverscrollFraction = _defaultEndOverscrollFraction,
  }) : _kind = _TimeRangeContentSourceKind.fixed,
       _sequenceId = null,
       _fixedStart = start,
       _fixedEnd = end,
       fallbackBars = 0;

  const TimeRangeContentSource.activePattern({
    this.fallbackBars = _defaultPatternFallbackBars,
    this.minWidth = _defaultMinWidth,
    this.endOverscrollFraction = _defaultEndOverscrollFraction,
  }) : _kind = _TimeRangeContentSourceKind.activePattern,
       _sequenceId = null,
       _fixedStart = 0,
       _fixedEnd = null;

  const TimeRangeContentSource.pattern(
    Id? patternId, {
    this.fallbackBars = _defaultPatternFallbackBars,
    this.minWidth = _defaultMinWidth,
    this.endOverscrollFraction = _defaultEndOverscrollFraction,
  }) : _kind = _TimeRangeContentSourceKind.pattern,
       _sequenceId = patternId,
       _fixedStart = 0,
       _fixedEnd = null;

  const TimeRangeContentSource.arrangement({
    this.fallbackBars = _defaultArrangementFallbackBars,
    this.minWidth = _defaultMinWidth,
    this.endOverscrollFraction = _defaultEndOverscrollFraction,
  }) : _kind = _TimeRangeContentSourceKind.arrangement,
       _sequenceId = null,
       _fixedStart = 0,
       _fixedEnd = null;

  bool get requiresProject => _kind != _TimeRangeContentSourceKind.fixed;

  TimeRangeContentBounds resolve(ProjectModel? project) {
    if (_kind == _TimeRangeContentSourceKind.fixed) {
      return TimeRangeContentBounds(
        start: _fixedStart,
        end: _fixedEnd!,
        minWidth: minWidth,
        endOverscrollFraction: endOverscrollFraction,
      );
    }

    if (project == null) {
      throw StateError(
        'A ProjectModel is required to resolve this TimeRangeContentSource.',
      );
    }

    final end = switch (_kind) {
      _TimeRangeContentSourceKind.activePattern => _resolvePatternEnd(
        project,
        project.sequence.activePatternID,
      ),
      _TimeRangeContentSourceKind.pattern => _resolvePatternEnd(
        project,
        _sequenceId,
      ),
      _TimeRangeContentSourceKind.arrangement => _resolveArrangementEnd(
        project,
      ),
      _TimeRangeContentSourceKind.fixed => throw StateError(
        'Fixed TimeRangeContentSource should have returned before switch.',
      ),
    };

    return TimeRangeContentBounds(
      end: end,
      minWidth: minWidth,
      endOverscrollFraction: endOverscrollFraction,
    );
  }

  double _resolvePatternEnd(ProjectModel project, Id? patternId) {
    final pattern = project.sequence.patterns[patternId];
    final fallbackEnd = (project.sequence.ticksPerQuarter * 4 * fallbackBars)
        .toDouble();

    return pattern?.lastContent.toDouble() ?? fallbackEnd;
  }

  double _resolveArrangementEnd(ProjectModel project) {
    final arrangement = project.sequence.arrangement;

    return arrangement.viewWidth.toDouble();
  }
}

double constrainTimeRangeWidthToContent({
  required double width,
  required TimeRangeContentBounds bounds,
}) {
  final overscrollFraction = bounds.endOverscrollFraction.clamp(0.0, 0.999999);
  final proposedWidth = math.max(bounds.minWidth, width);
  final contentWidth = math.max(bounds.minWidth, bounds.width);
  final maxWidth = math.max(
    bounds.minWidth,
    contentWidth / (1 - overscrollFraction),
  );

  return proposedWidth.clamp(bounds.minWidth, maxWidth).toDouble();
}

({double start, double end}) constrainTimeRangeStartToZero({
  required double start,
  required double end,
}) {
  if (start >= 0) {
    return (start: start, end: end);
  }

  return (start: 0, end: end - start);
}
