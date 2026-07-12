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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/time_range_content_source.dart';

const _timeRangeZoomScale = 0.0025;

enum TimeRangeTransition { animated, immediate }

class TimeRangeMutation {
  final int revision;
  final TimeRangeTransition transition;

  const TimeRangeMutation({required this.revision, required this.transition});
}

/// Owns the editable target time range for an editor viewport.
///
/// All horizontal viewport changes should go through this class so origin
/// clamping, content-sized zoom bounds, and animation intent stay attached to
/// the same mutation.
class TimeRangeViewport {
  final TimeRange target;
  final TimeRangeContentSource contentSource;

  int _revision = 0;
  TimeRangeMutation _lastMutation = const TimeRangeMutation(
    revision: 0,
    transition: TimeRangeTransition.immediate,
  );

  TimeRangeViewport({required this.target, required this.contentSource});

  TimeRangeMutation get lastMutation => _lastMutation;

  TimeRangeContentBounds resolveContentBounds(ProjectModel? project) {
    return contentSource.resolve(project);
  }

  void setRange({
    required double start,
    required double end,
    TimeRangeTransition transition = TimeRangeTransition.animated,
  }) {
    if (!start.isFinite || !end.isFinite) {
      return;
    }

    final constrainedRange = constrainTimeRangeStartToZero(
      start: start,
      end: end,
    );

    _setConstrainedRange(constrainedRange, transition);
  }

  void _setConstrainedRange(
    ({double start, double end}) range,
    TimeRangeTransition transition,
  ) {
    if (range.end <= range.start) {
      return;
    }

    if (target.start == range.start && target.end == range.end) {
      return;
    }

    _recordMutation(transition);
    target.start = range.start;
    target.end = range.end;
  }

  void panByTicks({
    required double delta,
    TimeRangeTransition transition = TimeRangeTransition.animated,
  }) {
    if (delta == 0) {
      return;
    }

    setRange(
      start: target.start + delta,
      end: target.end + delta,
      transition: transition,
    );
  }

  void zoomAt({
    required double delta,
    required double pointerX,
    required double viewportWidth,
    ProjectModel? project,
    TimeRangeTransition transition = TimeRangeTransition.animated,
  }) {
    final currentWidth = target.width;
    if (viewportWidth <= 0 || currentWidth <= 0) {
      return;
    }

    final nextWidth = math.exp(
      math.log(currentWidth) + delta * _timeRangeZoomScale,
    );
    final width = constrainTimeRangeWidthToContent(
      width: nextWidth,
      bounds: resolveContentBounds(project),
    );
    final anchorFraction = (pointerX / viewportWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    final anchorTime = target.start + currentWidth * anchorFraction;

    setRange(
      start: anchorTime - width * anchorFraction,
      end: anchorTime + width * (1 - anchorFraction),
      transition: transition,
    );
  }

  void resizeViewportPreservingScale({
    required double oldViewportWidth,
    required double newViewportWidth,
    ProjectModel? project,
    TimeRangeTransition transition = TimeRangeTransition.immediate,
  }) {
    final currentWidth = target.width;
    if (oldViewportWidth <= 0 || newViewportWidth <= 0 || currentWidth <= 0) {
      return;
    }

    final nextWidth = constrainTimeRangeWidthToContent(
      width: currentWidth * (newViewportWidth / oldViewportWidth),
      bounds: resolveContentBounds(project),
    );

    setRange(
      start: target.start,
      end: target.start + nextWidth,
      transition: transition,
    );
  }

  void setFromScrollbar({required double start, required double end}) {
    setRange(start: start, end: end, transition: TimeRangeTransition.immediate);
  }

  void _recordMutation(TimeRangeTransition transition) {
    _lastMutation = TimeRangeMutation(
      revision: ++_revision,
      transition: transition,
    );
  }
}
