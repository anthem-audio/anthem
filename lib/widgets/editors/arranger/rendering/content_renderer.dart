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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/arranger/rendering/clip_renderer.dart';
import 'package:anthem/widgets/editors/arranger/rendering/automation_hold_renderer.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_left_edge_border.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/time_range_animation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

/// Size of the resize handles, in pixels.
const _clipResizeHandleWidth = 12.0;

/// How far over the clip the resize handle extends, in pixels.
const _clipResizeHandleOvershoot = 2.0;

/// Computes resize handle rectangles for a clip while guaranteeing that each
/// clip has a center drag area free of resize handles.
@visibleForTesting
({Rect start, Rect end}) computeResizeHandleRects({
  required double clipX,
  required double clipY,
  required double clipWidth,
  required double clipHeight,
}) {
  final clipBodyWidth = (clipWidth - 1).clamp(1.0, double.infinity);
  final clipBodyLeft = clipX;
  final clipBodyRight = clipBodyLeft + clipBodyWidth;
  const defaultInsideOverlap =
      _clipResizeHandleWidth - _clipResizeHandleOvershoot;

  // Always preserve a center drag area
  final minDragArea = min(15.0, clipBodyWidth);
  final maxTotalHandleOverlapInside = (clipBodyWidth - minDragArea).clamp(
    0.0,
    double.infinity,
  );
  final insideOverlapPerHandle = (maxTotalHandleOverlapInside / 2).clamp(
    0.0,
    defaultInsideOverlap,
  );

  final startRight = clipBodyLeft + insideOverlapPerHandle;
  final startLeft = startRight - _clipResizeHandleWidth;
  final startRect = Rect.fromLTRB(
    startLeft,
    clipY,
    startRight,
    clipY + clipHeight - 1,
  );

  final endLeft = clipBodyRight - insideOverlapPerHandle;
  final endRight = endLeft + _clipResizeHandleWidth;
  final endRect = Rect.fromLTRB(
    endLeft,
    clipY,
    endRight,
    clipY + clipHeight - 1,
  );

  return (start: startRect, end: endRect);
}

/// Compares clips by render order.
///
/// Lower values are painted first (visually underneath later clips).
int compareClipRenderInfoForLayering(ClipRenderInfo a, ClipRenderInfo b) {
  // Clips with active timing overrides should render on top of non-overridden
  // clips while dragging/resizing.
  final overrideCompare = switch ((a.hasTimingOverride, b.hasTimingOverride)) {
    (false, true) => -1,
    (true, false) => 1,
    _ => 0,
  };
  if (overrideCompare != 0) {
    return overrideCompare;
  }

  final offsetCompare = a.clipOffset.compareTo(b.clipOffset);
  if (offsetCompare != 0) {
    return offsetCompare;
  }

  final widthCompare = a.clipWidth.compareTo(b.clipWidth);
  if (widthCompare != 0) {
    return widthCompare;
  }

  return a.clipId.compareTo(b.clipId);
}

/// Sorts clips and groups them into overlap-safe render layers.
List<List<ClipRenderInfo>> buildClipLayersForPainting(
  Iterable<ClipRenderInfo> clips,
) {
  final sortedClips = clips.toList()..sort(compareClipRenderInfoForLayering);

  final clipLayers = <List<ClipRenderInfo>>[];
  final layerBuilder = _ClipLayerBuilder();

  for (final clipInfo in sortedClips) {
    final layerIndex = layerBuilder.insertClip(
      trackId: clipInfo.trackId,
      clipStart: clipInfo.clipOffset,
      clipEnd: clipInfo.clipOffset + clipInfo.clipWidth,
    );

    while (clipLayers.length <= layerIndex) {
      clipLayers.add([]);
    }

    clipLayers[layerIndex].add(clipInfo);
  }

  return clipLayers;
}

class ArrangerContentRenderer extends StatelessObserverWidget {
  final Listenable repaint;
  final TimeRangeAnimation timeRangeAnimation;
  final Animation<double> verticalScrollPositionAnimation;
  final ArrangerViewModel viewModel;

  const ArrangerContentRenderer({
    super.key,
    required this.repaint,
    required this.timeRangeAnimation,
    required this.verticalScrollPositionAnimation,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID];

    if (arrangement == null) return const SizedBox();

    final devicePixelRatio = View.of(context).devicePixelRatio;
    viewModel.ensureRenderCachesForDevicePixelRatio(devicePixelRatio);

    return CustomPaint(
      painter: ArrangerContentPainter(
        repaint: repaint,
        timeRangeAnimation: timeRangeAnimation,
        verticalScrollPositionAnimation: verticalScrollPositionAnimation,
        project: project,
        arrangement: arrangement,
        viewModel: viewModel,
        devicePixelRatio: devicePixelRatio,
      ),
      isComplex: true,
    );
  }
}

class ArrangerContentPainter extends CustomPainterObserver {
  final TimeRangeAnimation timeRangeAnimation;
  final Animation<double> verticalScrollPositionAnimation;
  final ProjectModel project;
  final ArrangementModel arrangement;
  final ArrangerViewModel viewModel;
  final double devicePixelRatio;

  ArrangerContentPainter({
    required Listenable repaint,
    required this.timeRangeAnimation,
    required this.verticalScrollPositionAnimation,
    required this.project,
    required this.arrangement,
    required this.viewModel,
    required this.devicePixelRatio,
  }) : super(debugName: 'ArrangerContentPainter', repaint: repaint);

  double get timeViewStart => timeRangeAnimation.renderedStart;
  double get timeViewEnd => timeRangeAnimation.renderedEnd;
  double get renderedVerticalScrollPosition =>
      verticalScrollPositionAnimation.value;

  double _rowTopInViewport(int rowIndex) {
    return viewModel.trackLayout.rowLayoutAt(rowIndex).contentSpan.top -
        renderedVerticalScrollPosition;
  }

  @override
  bool shouldRepaint(ArrangerContentPainter oldDelegate) {
    return timeRangeAnimation != oldDelegate.timeRangeAnimation ||
        verticalScrollPositionAnimation !=
            oldDelegate.verticalScrollPositionAnimation ||
        project != oldDelegate.project ||
        arrangement != oldDelegate.arrangement ||
        viewModel != oldDelegate.viewModel ||
        devicePixelRatio != oldDelegate.devicePixelRatio;
  }

  @override
  void observablePaint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // This draws all the clips
    arrangement.clips.observeAllChanges();
    blockObservation(
      modelItems: [arrangement.clips],
      block: () {
        paintAutomationHoldSegments(
          project: project,
          arrangement: arrangement,
          viewModel: viewModel,
          canvas: canvas,
          canvasSize: size,
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          renderedVerticalScrollPosition: renderedVerticalScrollPosition,
        );
        _paintClips(canvas, size);
      },
    );

    paintEditorLeftEdgeBorder(canvas, size);

    _drawClipCreateHint(canvas, size);
    _drawCursor(canvas, size);
  }

  void _drawClipCreateHint(Canvas canvas, Size size) {
    if (viewModel.clipCreateHint == null) {
      return;
    }

    final (:rowId, :startOffset, :endOffset, :color) =
        viewModel.clipCreateHint!;

    final startX = timeToPixels(
      time: startOffset,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: size.width,
    );
    final endX = timeToPixels(
      time: endOffset,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: size.width,
    );

    final left = (startX < endX ? startX : endX) + 1;
    final width = (endX - startX).abs() - 1;

    if (width > 0) {
      final trackIndex = _rowIdToIndex(rowId);
      if (trackIndex == null) return;

      final trackPos = _rowTopInViewport(trackIndex);
      final trackHeight = viewModel.trackLayout
          .rowLayoutAt(trackIndex)
          .contentSpan
          .height;
      final contentTop = trackPos;

      final rect = Rect.fromLTWH(left, contentTop, width, trackHeight);

      canvas.drawRect(rect, Paint()..color = color);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, .circular(1)),
        Paint()
          ..style = .stroke
          ..color = color.withAlpha(255)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawCursor(Canvas canvas, Size size) {
    if (viewModel.hoverIndicatorPosition == null) {
      return;
    }

    if (viewModel.clipCreateHint != null) {
      final clipCreateHint = viewModel.clipCreateHint!;
      final startOffset = clipCreateHint.startOffset;
      final endOffset = clipCreateHint.endOffset;

      if (startOffset != endOffset) {
        return;
      }
    }

    final (:offset, :rowId) = viewModel.hoverIndicatorPosition!;

    final trackIndex = _rowIdToIndex(rowId);
    if (trackIndex == null) return;

    final trackPos = _rowTopInViewport(trackIndex);
    final trackHeight = viewModel.trackLayout
        .rowLayoutAt(trackIndex)
        .contentSpan
        .height;
    final contentTop = trackPos;

    final rect = Rect.fromLTWH(
      timeToPixels(
        time: offset,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
      ),
      contentTop,
      1.0,
      trackHeight,
    );

    canvas.drawRect(rect, Paint()..color = AnthemTheme.editors.playheadLine);
  }

  int? _rowIdToIndex(Id rowId) {
    return viewModel.trackLayout.tryRowIdToIndex(rowId);
  }

  ClipRenderInfo? _buildClipRenderInfo({
    required Id clipId,
    required Id trackId,
    required PatternModel pattern,
    required bool hasTimingOverride,
    required int clipOffset,
    required int clipTimeViewStart,
    required int clipTimeViewEnd,
    required Size size,
  }) {
    if (clipTimeViewEnd <= clipTimeViewStart) {
      return null;
    }

    final clipWidth = clipTimeViewEnd - clipTimeViewStart;

    final x = timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: size.width,
      time: clipOffset.toDouble(),
    );
    final width =
        timeToPixels(
          timeViewStart: timeViewStart,
          timeViewEnd: timeViewEnd,
          viewPixelWidth: size.width,
          time: clipOffset.toDouble() + clipWidth,
        ) -
        x +
        1;

    if (x > size.width || x + width < 0) return null;

    final trackIndex = viewModel.trackLayout.tryTrackIdToIndex(trackId);
    if (trackIndex == null) return null;

    final rowLayout = viewModel.trackLayout.rowLayoutAt(trackIndex);
    final y = rowLayout.contentSpan.top - renderedVerticalScrollPosition;
    final trackHeight = rowLayout.contentSpan.height;

    if (y > size.height || y + trackHeight < 0) return null;

    final track = project.tracks[trackId];
    if (track == null) return null;

    return ClipRenderInfo(
      pattern: pattern,
      color: track.color,
      clipId: clipId,
      trackId: trackId,
      hasTimingOverride: hasTimingOverride,
      clipOffset: clipOffset,
      clipTimeViewStart: clipTimeViewStart,
      clipTimeViewEnd: clipTimeViewEnd,
      x: x,
      y: y,
      width: width,
      height: trackHeight,
      selected: viewModel.selectedClips.contains(clipId),
      hovered: viewModel.hoveredClip == clipId,
      showAutomationHandles: viewModel.clipWithAutomationHandles == clipId,
    );
  }

  /// Paints the clips onto the arranger canvas.
  void _paintClips(Canvas canvas, Size size) {
    viewModel.visibleClips.clear();
    viewModel.visibleResizeAreas.clear();
    viewModel.visibleAutomationHandles.clear();

    // We render each clip in multiple stages to optimize draw calls. For
    // example, automation curves from all visible clips are rendered all at
    // once, which significantly reduces raster time for the associated draw
    // calls over drawing one clip at a time.
    //
    // In order to achieve this from a coloring standpoint, we draw clip content
    // into a separate layer in gray, and use blend modes to overlay this on
    // colorful clip backgrounds.
    //
    // Since we draw all the backgrounds first, then the content, we cannot draw
    // all clips in a single pass if any of them overlay each other.
    //
    // We solve this by detecting overlaps. If clips A and B overlap, B is on
    // top, and we have additional clips C, D and E do not overlap with
    // anything, we will draw two layers. The first layer will contain A, C, D,
    // and E, and the second layer will contain B. Within each layer, we will
    // draw all backgrounds first, then all content.
    //
    // Note that if we ever disallow overlapping clips in the arranger, then we
    // could simplify this logic.

    final realClips = arrangement.clips.values.map<ClipRenderInfo?>((clip) {
      final pattern = project.sequence.patterns[clip.patternId];
      if (pattern == null) {
        return null;
      }

      final baseClipTimeViewStart = clip.timeView?.start ?? 0;
      final baseClipTimeViewEnd = baseClipTimeViewStart + clip.width;
      final clipTimingOverride = viewModel.clipTimingOverrides[clip.id];

      return _buildClipRenderInfo(
        clipId: clip.id,
        trackId: clip.trackId,
        pattern: pattern,
        hasTimingOverride: clipTimingOverride != null,
        clipOffset: clipTimingOverride?.offset ?? clip.offset,
        clipTimeViewStart:
            clipTimingOverride?.timeViewStart ?? baseClipTimeViewStart,
        clipTimeViewEnd: clipTimingOverride?.timeViewEnd ?? baseClipTimeViewEnd,
        size: size,
      );
    }).nonNulls;

    final previewClips = viewModel.previewClips.values.map<ClipRenderInfo?>((
      preview,
    ) {
      return _buildClipRenderInfo(
        clipId: preview.clipId,
        trackId: preview.trackId,
        pattern: preview.pattern,
        hasTimingOverride: true,
        clipOffset: preview.offset,
        clipTimeViewStart: preview.timeViewStart,
        clipTimeViewEnd: preview.timeViewEnd,
        size: size,
      );
    }).nonNulls;

    final allClips = realClips.followedBy(previewClips).toList();

    final clipLayers = buildClipLayersForPainting(allClips);

    for (final clipList in clipLayers) {
      paintClipList(
        project: project,
        canvas: canvas,
        canvasSize: size,
        automationHandleAnnotations: viewModel.visibleAutomationHandles,
        hoveredAutomationHandle: viewModel.hoveredAutomationHandle,
        clipList: clipList,
        devicePixelRatio: devicePixelRatio,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
      );

      for (final clipEntry in clipList) {
        final x = clipEntry.x;
        final y = clipEntry.y;
        final width = clipEntry.width;
        final trackHeight = clipEntry.height;

        viewModel.visibleClips.add(
          rect: Rect.fromLTWH(x, y, width - 1, trackHeight - 1),
          metadata: clipEntry.clipId,
        );

        final (
          start: startResizeHandleRect,
          end: endResizeHandleRect,
        ) = computeResizeHandleRects(
          clipX: x,
          clipY: y,
          clipWidth: width,
          clipHeight: trackHeight,
        );
        viewModel.visibleResizeAreas.add(
          rect: startResizeHandleRect,
          metadata: (id: clipEntry.clipId, type: ResizeAreaType.start),
        );

        viewModel.visibleResizeAreas.add(
          rect: endResizeHandleRect,
          metadata: (id: clipEntry.clipId, type: ResizeAreaType.end),
        );
      }
    }
  }
}

/// Takes clips and sorts them into layers based on overlap.
class _ClipLayerBuilder {
  /// List of layers, where each layer is a map of track IDs to invalidation
  /// range collectors.
  ///
  /// Invalidation range collectors are used when editing sequences to track
  /// which regions in a sequence are no longer valid if the playhead is
  /// currently in that region. The goal of the collectors is that we may throw
  /// thousands of start-end ranges at them per mouse event during editing, and
  /// it should be able to very quickly reduce that into a merged set of ranges.
  ///
  /// If an invalidation range collector receives the following ranges:
  /// (0, 10), (5, 15), (20, 25)
  ///
  /// It will produce:
  /// (0, 15), (20, 25)
  ///
  /// The range collector has a fixed upper bound size. It degrades after this
  /// by merging adjacent ranges, which takes speed over accuracy.
  ///
  /// This is a perfect tool for building clip layers. The problem we have is
  /// that we need to track where clips are overlapping, and we need to do so
  /// for all on-screen clips every frame. We repurpose the invalidation range
  /// collectors to track overlapping clips instead.
  ///
  /// In order to do this, we add an additional method to the invalidation range
  /// collector that allows us to test whether a given range overlaps with any of
  /// the existing ranges. If it does, we know the clip overlaps with another
  /// clip in this layer, and we need to start a new layer.
  final List<Map<Id, InvalidationRangeCollector>> _invalidationCollectors = [
    {},
  ];

  /// Adds a clip to the appropriate layer, creating a new layer if necessary.
  ///
  /// Returns the layer index the clip was added to.
  int insertClip({
    required Id trackId,
    required int clipStart,
    required int clipEnd,
  }) {
    var layerIndexToModify = _invalidationCollectors.length;

    for (var i = layerIndexToModify - 1; i >= 0; i--) {
      final layer = _invalidationCollectors[i];
      if (layer[trackId] == null ||
          !layer[trackId]!.overlapsRange(clipStart, clipEnd, false)) {
        layerIndexToModify = i;
      } else {
        break;
      }
    }

    if (layerIndexToModify == _invalidationCollectors.length) {
      // Need to create a new layer
      _invalidationCollectors.add({});
    }

    final layer = _invalidationCollectors[layerIndexToModify];
    layer.putIfAbsent(trackId, () => InvalidationRangeCollector(256));
    layer[trackId]!.addRange(clipStart, clipEnd);
    return layerIndexToModify;
  }
}
