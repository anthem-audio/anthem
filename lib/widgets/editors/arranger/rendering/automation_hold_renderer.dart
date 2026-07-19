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
import 'dart:ui';

import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/sequence_automation_provider.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/rendering/automation_curve_renderer.dart';
import 'package:anthem/widgets/editors/arranger/automation_hold_segments.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_content_visibility.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_geometry.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';

const _automationStrokeWidth = 2.0;
const _automationFillAlpha = 0.16;

final _automationHoldLineBuffer = LineBuffer();
final _automationHoldFillBuffer = CoordinateBuffer();

void paintAutomationHoldSegments({
  required ProjectModel project,
  required ArrangementModel arrangement,
  required ArrangerViewModel viewModel,
  required Canvas canvas,
  required Size canvasSize,
  required double timeViewStart,
  required double timeViewEnd,
  required double renderedVerticalScrollPosition,
}) {
  final trackLayout = viewModel.trackLayout;

  for (final rowLayout in trackLayout.rowLayouts) {
    final contentBounds = _automationContentBoundsForRow(
      rowLayout: rowLayout,
      canvasSize: canvasSize,
      renderedVerticalScrollPosition: renderedVerticalScrollPosition,
    );
    if (contentBounds == null) {
      continue;
    }

    switch (rowLayout.row) {
      case ProjectTrackRow(:final trackId):
        final track = project.tracks[trackId];
        if (track == null || !track.isAutomationLane) {
          continue;
        }

        final segments = buildAutomationHoldSegmentsForTrack(
          project: project,
          arrangement: arrangement,
          trackId: trackId,
        );
        final paintSegments = segments.isNotEmpty
            ? segments
            : [
                AutomationHoldSegment(
                  startTick: timeViewStart,
                  endTick: timeViewEnd,
                  value: _automationLaneEmptyValue(track),
                ),
              ];

        _paintTrackAutomationHoldSegments(
          canvas: canvas,
          canvasSize: canvasSize,
          segments: paintSegments,
          color: track.color.colorShifter.clipBase.toColor(),
          contentTop: contentBounds.contentTop,
          contentBottom: contentBounds.contentBottom,
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
        );

      case PhantomAutomationTrackRow(:final phantomLane):
        final target = phantomLane.target;
        final value = target == null
            ? null
            : _currentAutomationTargetValue(project: project, target: target);
        final parentTrack = project.tracks[phantomLane.parentTrackId];
        if (value == null || parentTrack == null) {
          continue;
        }

        _paintTrackAutomationHoldSegments(
          canvas: canvas,
          canvasSize: canvasSize,
          segments: [
            AutomationHoldSegment(
              startTick: timeViewStart,
              endTick: timeViewEnd,
              value: value,
            ),
          ],
          color: parentTrack.color.colorShifter.clipBase.toColor(),
          contentTop: contentBounds.contentTop,
          contentBottom: contentBounds.contentBottom,
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
        );
    }
  }
}

double _automationLaneEmptyValue(TrackModel track) {
  final processor =
      track
              .requireAutomationProcessing
              .sequenceAutomationProviderNode!
              .processor
          as SequenceAutomationProviderProcessorModel;

  return processor.emptyValue;
}

({double contentTop, double contentBottom})? _automationContentBoundsForRow({
  required TrackRowLayout rowLayout,
  required Size canvasSize,
  required double renderedVerticalScrollPosition,
}) {
  final trackY = rowLayout.contentSpan.top - renderedVerticalScrollPosition;
  final trackHeight = rowLayout.contentSpan.height;
  final clipBounds = clipPaintVerticalBoundsForRow(
    rowTop: trackY,
    rowHeight: trackHeight,
  );
  final clipHeight = clipBounds.bottom - clipBounds.top;

  if (!shouldRenderClipContent(clipHeight) ||
      clipBounds.top > canvasSize.height ||
      clipBounds.bottom < 0) {
    return null;
  }

  final automationBounds = automationContentVerticalBoundsForRow(
    rowTop: trackY,
    rowHeight: trackHeight,
  );
  if (automationBounds.bottom <= automationBounds.top) {
    return null;
  }

  return (
    contentTop: automationBounds.top,
    contentBottom: automationBounds.bottom,
  );
}

double? _currentAutomationTargetValue({
  required ProjectModel project,
  required AutomationParameterTarget target,
}) {
  final node = project.processingGraph.nodes[target.nodeId];
  if (node == null) {
    return null;
  }

  final port = _findControlInputPort(node: node, portId: target.portId);
  final parameterConfig = port?.config.parameterConfig;
  if (port == null || parameterConfig == null) {
    return null;
  }

  return port.parameterValue ?? parameterConfig.defaultValue;
}

NodePortModel? _findControlInputPort({
  required NodeModel node,
  required int portId,
}) {
  for (final port in node.controlInputPorts) {
    if (port.id == portId) {
      return port;
    }
  }

  return null;
}

void _paintTrackAutomationHoldSegments({
  required Canvas canvas,
  required Size canvasSize,
  required List<AutomationHoldSegment> segments,
  required Color color,
  required double contentTop,
  required double contentBottom,
  required double timeViewStart,
  required double timeViewEnd,
}) {
  _automationHoldLineBuffer.clear();
  _automationHoldFillBuffer.clear();

  try {
    for (final segment in segments) {
      final startTick = max(segment.startTick, max(0.0, timeViewStart));
      final endTick = min(
        segment.endTick.isFinite ? segment.endTick : timeViewEnd,
        timeViewEnd,
      );

      if (endTick <= startTick) {
        continue;
      }

      final startX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: canvasSize.width,
        time: startTick,
      ).clamp(0.0, canvasSize.width).toDouble();
      final endX = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: canvasSize.width,
        time: endTick,
      ).clamp(0.0, canvasSize.width).toDouble();

      if (endX <= startX) {
        continue;
      }

      final lineY =
          contentTop + (contentBottom - contentTop) * (1.0 - segment.value);

      _addFillRect(x1: startX, x2: endX, y: lineY, baseY: contentBottom);

      _automationHoldLineBuffer.add(startX, lineY);
      _automationHoldLineBuffer.add(endX, lineY);
      _automationHoldLineBuffer.disconnectNext();
    }

    if (_automationHoldFillBuffer.coordinateCount == 0) {
      return;
    }

    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, _automationHoldFillBuffer.buffer),
      BlendMode.srcOver,
      Paint()
        ..color = color.withValues(alpha: _automationFillAlpha)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRawPoints(
      PointMode.lines,
      _automationHoldLineBuffer.buffer,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _automationStrokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  } finally {
    _automationHoldLineBuffer.clear();
    _automationHoldFillBuffer.clear();
  }
}

void _addFillRect({
  required double x1,
  required double x2,
  required double y,
  required double baseY,
}) {
  _automationHoldFillBuffer.add(x1, y);
  _automationHoldFillBuffer.add(x2, y);
  _automationHoldFillBuffer.add(x2, baseY);

  _automationHoldFillBuffer.add(x1, y);
  _automationHoldFillBuffer.add(x2, baseY);
  _automationHoldFillBuffer.add(x1, baseY);
}
