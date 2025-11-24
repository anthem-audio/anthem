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

import 'package:anthem/model/anthem_model_mobx_helpers.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/invalidation_range_collector.dart';
import 'package:anthem/widgets/basic/clip/clip_renderer.dart';
import 'package:anthem/widgets/basic/mobx_custom_painter.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

/// Size of the resize handles, in pixels.
const _clipResizeHandleWidth = 12.0;

/// How far over the clip the resize handle extends, in pixels.
const _clipResizeHandleOvershoot = 2.0;

/// There will be at least this much clickable area on a clip. Resize handles
/// will shrink to make room for this if necessary.
const _minimumClickableClipArea = 30;

class ArrangerContentRenderer extends StatelessObserverWidget {
  final double timeViewStart;
  final double timeViewEnd;
  final double verticalScrollPosition;
  final ArrangerViewModel viewModel;

  const ArrangerContentRenderer({
    super.key,
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.verticalScrollPosition,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final project = Provider.of<ProjectModel>(context);
    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID];

    if (arrangement == null) return const SizedBox();

    return CustomPaintObserver(
      painterBuilder: () => ArrangerContentPainter(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        verticalScrollPosition: verticalScrollPosition,
        project: project,
        arrangement: arrangement,
        viewModel: viewModel,
        devicePixelRatio: View.of(context).devicePixelRatio,
      ),
      isComplex: true,
    );
  }
}

class ArrangerContentPainter extends CustomPainterObserver {
  final double timeViewStart;
  final double timeViewEnd;
  final double verticalScrollPosition;
  final ProjectModel project;
  final ArrangementModel arrangement;
  final ArrangerViewModel viewModel;
  final double devicePixelRatio;

  ArrangerContentPainter({
    required this.timeViewStart,
    required this.timeViewEnd,
    required this.verticalScrollPosition,
    required this.project,
    required this.arrangement,
    required this.viewModel,
    required this.devicePixelRatio,
  });

  @override
  bool shouldRepaint(ArrangerContentPainter oldDelegate) {
    return timeViewStart != oldDelegate.timeViewStart ||
        timeViewEnd != oldDelegate.timeViewEnd ||
        verticalScrollPosition != oldDelegate.verticalScrollPosition ||
        project != oldDelegate.project ||
        arrangement != oldDelegate.arrangement ||
        viewModel != oldDelegate.viewModel ||
        devicePixelRatio != oldDelegate.devicePixelRatio ||
        super.shouldRepaint(oldDelegate);
  }

  @override
  void observablePaint(Canvas canvas, Size size) {
    arrangement.clips.observeAllChanges();

    blockObservation(
      modelItems: [arrangement.clips],
      block: () => _paintClips(canvas, size),
    );
  }

  /// Paints the clips onto the arranger canvas.
  void _paintClips(Canvas canvas, Size size) {
    viewModel.visibleClips.clear();
    viewModel.visibleResizeAreas.clear();

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

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final allClips = arrangement.clips.keys.map<ClipRenderInfo?>((clipId) {
      final clip = arrangement.clips[clipId]!;
      final pattern = project.sequence.patterns[clip.patternId]!;

      final x = timeToPixels(
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
        viewPixelWidth: size.width,
        time: clip.offset.toDouble(),
      );
      final width =
          timeToPixels(
            timeViewStart: timeViewStart,
            timeViewEnd: timeViewEnd,
            viewPixelWidth: size.width,
            time: clip.offset.toDouble() + clip.width,
          ) -
          x +
          1;

      if (x > size.width || x + width < 0) return null;

      final y =
          trackIndexToPos(
            trackIndex: project.sequence.trackOrder
                .indexWhere((trackID) => trackID == clip.trackId)
                .toDouble(),
            baseTrackHeight: viewModel.baseTrackHeight,
            trackOrder: project.sequence.trackOrder,
            trackHeightModifiers: viewModel.trackHeightModifiers,
            scrollPosition: verticalScrollPosition,
          ) -
          1;
      final trackHeight =
          getTrackHeight(
            viewModel.baseTrackHeight,
            viewModel.trackHeightModifiers[clip.trackId]!,
          ) +
          1;

      if (y > size.height || y + trackHeight < 0) return null;

      return (
        pattern: pattern,
        clip: clip,
        x: x,
        y: y,
        width: width,
        height: trackHeight,
        selected: viewModel.selectedClips.contains(clip.id),
        pressed: viewModel.pressedClip == clip.id,
      );
    }).nonNulls;

    List<List<ClipRenderInfo>> clipLayers = [];
    final layerBuilder = _ClipLayerBuilder();

    for (final clipInfo in allClips) {
      final layerIndex = layerBuilder.insertClip(
        trackId: clipInfo.clip.trackId,
        clipStart: clipInfo.clip.offset,
        clipEnd: clipInfo.clip.offset + clipInfo.clip.width,
      );

      while (clipLayers.length <= layerIndex) {
        clipLayers.add([]);
      }

      clipLayers[layerIndex].add(clipInfo);
    }

    for (final clipList in clipLayers) {
      paintClipList(
        canvas: canvas,
        canvasSize: size,
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
        final clip = clipEntry.clip;

        viewModel.visibleClips.add(
          rect: Rect.fromLTWH(x, y, width - 1, trackHeight - 1),
          metadata: (id: clip.id),
        );

        final startResizeHandleRect = Rect.fromLTWH(
          x - _clipResizeHandleOvershoot,
          y,
          _clipResizeHandleWidth
              // Ensures there's a bit of the clip still showing
              -
              (_minimumClickableClipArea - width).clamp(
                0,
                (_clipResizeHandleWidth - _clipResizeHandleOvershoot),
              ),
          trackHeight - 1,
        );
        viewModel.visibleResizeAreas.add(
          rect: startResizeHandleRect,
          metadata: (id: clip.id, type: ResizeAreaType.start),
        );

        // Notice this is fromLTRB. We generally use fromLTWH elsewhere.
        final endResizeHandleRect = Rect.fromLTRB(
          x +
              (width - (_clipResizeHandleWidth - _clipResizeHandleOvershoot))
                  // Ensures there's a bit of the clip still showing
                  .clamp(_minimumClickableClipArea, double.infinity)
                  .clamp(0, width),
          y,
          x + width + _clipResizeHandleOvershoot,
          y + trackHeight - 1,
        );
        viewModel.visibleResizeAreas.add(
          rect: endResizeHandleRect,
          metadata: (id: clip.id, type: ResizeAreaType.end),
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
  final List<Map<String, InvalidationRangeCollector>> _invalidationCollectors =
      [{}];

  /// Adds a clip to the appropriate layer, creating a new layer if necessary.
  ///
  /// Returns the layer index the clip was added to.
  int insertClip({
    required String trackId,
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
