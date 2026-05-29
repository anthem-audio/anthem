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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/rendering/automation_smooth_curve.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem_codegen/include/collections.dart';
import 'package:flutter/foundation.dart';

@immutable
class AutomationHoldSegment {
  final double startTick;
  final double endTick;
  final double value;

  const AutomationHoldSegment({
    required this.startTick,
    required this.endTick,
    required this.value,
  });
}

class _ResolvedClip {
  final Id id;
  final double offset;
  final double width;
  final double sourceStart;
  final double sourceEnd;
  final AnthemObservableList<AutomationPointModel> automationPoints;

  const _ResolvedClip({
    required this.id,
    required this.offset,
    required this.width,
    required this.sourceStart,
    required this.sourceEnd,
    required this.automationPoints,
  });

  bool get hasAutomation => automationPoints.isNotEmpty;
}

List<AutomationHoldSegment> buildAutomationHoldSegmentsForTrack({
  required ProjectModel project,
  required ArrangementModel arrangement,
  required Id trackId,
}) {
  if (!arrangement.hasClipsForTrack(trackId)) {
    return const [];
  }

  final clipTimingOverrides = ServiceRegistry.forProject(
    project.id,
  ).arrangerViewModel.clipTimingOverrides;

  final clips = arrangement
      .getClipIdsForTrack(trackId)
      .map((clipId) => arrangement.clips[clipId])
      .whereType<ClipModel>()
      .where((clip) => project.sequence.patterns[clip.patternId] != null);

  return buildAutomationHoldSegments(
    project: project,
    clips: clips,
    clipTimingOverrides: clipTimingOverrides,
  );
}

@visibleForTesting
List<AutomationHoldSegment> buildAutomationHoldSegments({
  required ProjectModel project,
  required Iterable<ClipModel> clips,
  Map<Id, ClipTimingOverride> clipTimingOverrides =
      const <Id, ClipTimingOverride>{},
}) {
  final sortedClips =
      clips
          .map(
            (clip) => _resolveClip(
              project: project,
              clip: clip,
              clipTimingOverrides: clipTimingOverrides,
            ),
          )
          .nonNulls
          .toList(growable: false)
        ..sort((left, right) {
          final offsetCompare = left.offset.compareTo(right.offset);
          if (offsetCompare != 0) {
            return offsetCompare;
          }

          return left.id.compareTo(right.id);
        });

  for (final clip in sortedClips) {
    clip.automationPoints.observeAllChanges();
  }

  for (final clip in sortedClips) {
    beginObservationBlockFor(clip.automationPoints);
  }

  try {
    return _buildAutomationHoldSegmentsFromResolvedClips(sortedClips);
  } finally {
    for (final clip in sortedClips.reversed) {
      endObservationBlockFor(clip.automationPoints);
    }
  }
}

List<AutomationHoldSegment> _buildAutomationHoldSegmentsFromResolvedClips(
  List<_ResolvedClip> sortedClips,
) {
  final firstAutomationClip = _firstContributingAutomationClip(sortedClips);
  if (firstAutomationClip == null) {
    return const [];
  }

  var currentValue = evaluateAutomationHoldValueAtSourceTick(
    firstAutomationClip.automationPoints,
    firstAutomationClip.sourceStart,
  );
  var previousBlockedEnd = 0.0;
  final segments = <AutomationHoldSegment>[];

  for (final (clipIndex, clip) in sortedClips.indexed) {
    final clipStart = max(0.0, clip.offset);
    final clipEnd = max(clipStart, clip.offset + clip.width);

    if (clipStart > previousBlockedEnd) {
      segments.add(
        AutomationHoldSegment(
          startTick: previousBlockedEnd,
          endTick: clipStart,
          value: currentValue,
        ),
      );
    }

    if (clip.hasAutomation) {
      final nextClipStart = clipIndex + 1 < sortedClips.length
          ? sortedClips[clipIndex + 1].offset
          : double.infinity;

      if (nextClipStart > clip.offset) {
        currentValue = _evaluateClipEndValue(
          clip: clip,
          nextClipStart: nextClipStart,
        );
      }
    }

    if (clipEnd > previousBlockedEnd) {
      previousBlockedEnd = clipEnd;
    }
  }

  segments.add(
    AutomationHoldSegment(
      startTick: previousBlockedEnd,
      endTick: double.infinity,
      value: currentValue,
    ),
  );

  return List.unmodifiable(segments);
}

@visibleForTesting
double evaluateAutomationHoldValueAtSourceTick(
  List<AutomationPointModel> points,
  double tick,
) {
  if (points.isEmpty) {
    return 0.0;
  }

  if (points.length == 1 || tick <= points.first.offset) {
    return points.first.value;
  }

  if (tick > points.last.offset) {
    return points.last.value;
  }

  final pointIndex = _findPointIndexAtOrAfterTick(points, tick);

  final firstPoint = points[pointIndex - 1];
  final secondPoint = points[pointIndex];

  if (tick == secondPoint.offset) {
    return secondPoint.value;
  }

  if (secondPoint.offset <= firstPoint.offset) {
    return firstPoint.value;
  }

  final normalizedPosition =
      (tick - firstPoint.offset) / (secondPoint.offset - firstPoint.offset);

  return _evaluateAutomationSpanAtNormalizedPosition(
    firstPoint: firstPoint,
    secondPoint: secondPoint,
    normalizedPosition: normalizedPosition,
  );
}

_ResolvedClip? _firstContributingAutomationClip(List<_ResolvedClip> clips) {
  for (final (clipIndex, clip) in clips.indexed) {
    final nextClipStart = clipIndex + 1 < clips.length
        ? clips[clipIndex + 1].offset
        : double.infinity;

    if (clip.hasAutomation && nextClipStart > clip.offset) {
      return clip;
    }
  }

  return null;
}

double _evaluateClipEndValue({
  required _ResolvedClip clip,
  required double nextClipStart,
}) {
  var sourceEnd = clip.sourceEnd;
  final sourceStart = clip.sourceStart;

  if (sourceEnd < sourceStart) {
    sourceEnd = sourceStart;
  }

  if (nextClipStart.isFinite) {
    sourceEnd = min(
      sourceEnd,
      sourceStart + max(0.0, nextClipStart - clip.offset),
    );
  }

  return evaluateAutomationHoldValueAtSourceTick(
    clip.automationPoints,
    sourceEnd,
  );
}

double _evaluateAutomationSpanAtNormalizedPosition({
  required AutomationPointModel firstPoint,
  required AutomationPointModel secondPoint,
  required double normalizedPosition,
}) {
  final curveValue = switch (secondPoint.curve) {
    AutomationCurveType.smooth => evaluateSmooth(
      normalizedPosition.clamp(0.0, 1.0).toDouble(),
      secondPoint.tension,
    ),
    AutomationCurveType.stairs ||
    AutomationCurveType.wave ||
    AutomationCurveType.hold => 0.0,
  };

  return firstPoint.value + curveValue * (secondPoint.value - firstPoint.value);
}

int _findPointIndexAtOrAfterTick(
  List<AutomationPointModel> points,
  double tick,
) {
  var min = 0;
  var max = points.length;

  while (min < max) {
    final mid = min + ((max - min) >> 1);
    if (points[mid].offset < tick) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }

  return min;
}

_ResolvedClip? _resolveClip({
  required ProjectModel project,
  required ClipModel clip,
  required Map<Id, ClipTimingOverride> clipTimingOverrides,
}) {
  final pattern = project.sequence.patterns[clip.patternId];
  if (pattern == null) {
    return null;
  }

  final baseTimeViewStart = clip.timeView?.start ?? 0;
  final baseTimeViewEnd = clip.timeView?.end ?? clip.width;
  final clipTimingOverride = clipTimingOverrides[clip.id];
  final clipTimeViewStart =
      clipTimingOverride?.timeViewStart ?? baseTimeViewStart;
  final clipTimeViewEnd = clipTimingOverride?.timeViewEnd ?? baseTimeViewEnd;

  final points = pattern.automation.points;

  return _ResolvedClip(
    id: clip.id,
    offset: (clipTimingOverride?.offset ?? clip.offset).toDouble(),
    width: max(0, clipTimeViewEnd - clipTimeViewStart).toDouble(),
    sourceStart: clipTimeViewStart.toDouble(),
    sourceEnd: clipTimeViewEnd.toDouble(),
    automationPoints: points,
  );
}
