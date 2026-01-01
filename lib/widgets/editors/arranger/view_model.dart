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
import 'dart:typed_data';
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:mobx/mobx.dart';

part 'view_model.g.dart';

// ignore: library_private_types_in_public_api
class ArrangerViewModel = _ArrangerViewModel with _$ArrangerViewModel;

enum ResizeAreaType { start, end }

abstract class _ArrangerViewModel with Store {
  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  TimeRange timeView;

  @observable
  double baseTrackHeight;

  /// Per-track modifier that is multiplied by baseTrackHeight and clamped to
  /// get the actual height for each track
  @observable
  ObservableMap<Id, double> trackHeightModifiers;

  /// Vertical scroll position, in pixels.
  @observable
  double verticalScrollPosition = 0;

  /// Current pattern that will be placed when the user places a pattern.
  @observable
  Id? cursorPattern;

  /// Time range for cursor pattern.
  @observable
  TimeViewModel? cursorTimeRange;

  @observable
  Rectangle<double>? selectionBox;

  @observable
  ObservableSet<Id> selectedClips = ObservableSet();

  @observable
  Id? pressedClip;

  late final _TrackPositionAndSize trackPositionCalculator;

  final visibleClips = CanvasAnnotationSet<({Id id})>();
  final visibleResizeAreas =
      CanvasAnnotationSet<({Id id, ResizeAreaType type})>();

  _ArrangerViewModel({
    required ProjectModel project,
    required this.baseTrackHeight,
    required this.timeView,
  }) : trackHeightModifiers = ObservableMap.of(
         project.tracks.nonObservableInner.map(
           (key, value) => MapEntry(key, 1),
         ),
       ) {
    trackPositionCalculator = _TrackPositionAndSize(
      project,
      this as ArrangerViewModel,
    );
  }

  /// Total height of the entire scrollable region
  @observable
  double scrollAreaHeight = 0.0;

  /// The current height of the editor canvas, which should be calculated during
  /// layout.
  ///
  /// Careful not to accidentally use this while calculating the editor height.
  @observable
  double editorHeight = 0.0;

  /// The current gap between regular tracks and send tracks, NOT including the
  /// add track button.
  ///
  /// This will be zero if there is any vertical scroll available in the
  /// arranger.
  @observable
  double regularToSendGapHeight = 0.0;

  double get maxVerticalScrollPosition =>
      (scrollAreaHeight - editorHeight).clamp(0, double.infinity);

  /// Calculates the clip and resize handle under the cursor, if there is one.
  ({
    CanvasAnnotation<({Id id})>? clip,
    CanvasAnnotation<({Id id, ResizeAreaType type})>? resizeHandle,
  })
  getContentUnderCursor(Offset pos) {
    final clipUnderCursor = visibleClips.hitTest(pos);
    final resizeHandleUnderCursor = visibleResizeAreas
        .hitTestAll(pos)
        // We only report a resize handle if the cursor is also over the
        // associated clip, or if the cursor is over no clip. This makes the
        // behavior for clip resizing a bit more predictable, as it then doesn't
        // depend on the Z-ordering of clips for clips that are right next to
        // each other.
        .firstWhereOrNull(
          (element) =>
              clipUnderCursor == null ||
              element.metadata.id == clipUnderCursor.metadata.id,
        );
    return (clip: clipUnderCursor, resizeHandle: resizeHandleUnderCursor);
  }

  void registerTrack(Id trackId) {
    trackHeightModifiers[trackId] = 1;
  }

  void unregisterTrack(Id trackId) {
    trackHeightModifiers.remove(trackId);
  }
}

/// Calculates and caches the size and position of tracks in the current view.
///
/// The position of each track is dependent on the height of each track above it
/// plus the vertical scroll position, and the height of the scrollable area
/// depends on the height of all tracks.
///
/// The arranger uses this to calculate which track headers are on screen and
/// where they are, and to determine how to render the scrollbar. The clip
/// renderer uses this to determine the y position and size of each clip.
///
/// The values are cached in a typed array to improve memory locality and reduce
/// allocation and GC pressure.
class _TrackPositionAndSize {
  ProjectModel projectModel;
  ArrangerViewModel arrangerViewModel;

  var _cache = Float64List(0);
  final _trackIdToIndex = <String, int>{};

  _TrackPositionAndSize(this.projectModel, this.arrangerViewModel);

  int trackIdToIndex(String trackId) => _trackIdToIndex[trackId]!;

  double getTrackHeight(int trackIndex) => _cache[trackIndex * 2];
  double getTrackPosition(int trackIndex) => _cache[trackIndex * 2 + 1];

  /// Gets the track index plus a [0 - 1) offset from the top of the track,
  /// given a y-offset from the top of the screen.
  double getTrackIndexFromPosition(double yPosition) {
    for (int i = 0; i < _cache.length ~/ 2; i++) {
      final trackPosition = _cache[i * 2 + 1];
      final trackHeight = _cache[i * 2];

      if (yPosition >= trackPosition &&
          yPosition <= trackPosition + trackHeight) {
        return i.toDouble() + (yPosition - trackPosition) / trackHeight;
      }
    }

    return double.infinity;
  }

  /// To be called on build in a LayoutBuilder, as soon as we can know the
  /// height of the editor and before any further build or render work is done.
  ///
  /// This is meant to be used with a MobX observer.
  void invalidate(double editorHeight) {
    final trackCount =
        projectModel.trackOrder.length + projectModel.sendTrackOrder.length;

    final allTracksIterable = projectModel.trackOrder
        .map((t) => (t, false))
        .followedBy(projectModel.sendTrackOrder.map((t) => (t, true)));

    if (trackCount != projectModel.tracks.length) {
      throw StateError(
        'Track order lists and track list do not have the same size',
      );
    }

    if (_cache.length != trackCount * 2) {
      _cache = Float64List(trackCount * 2);
      _trackIdToIndex.clear();
    }

    var totalTrackHeight = 0.0;
    const addButtonAreaHeight = 33.0;

    for (final (i, (trackId, _)) in allTracksIterable.indexed) {
      final heightIndex = i * 2;
      final trackHeight = calculateTrackHeight(
        arrangerViewModel.baseTrackHeight,
        arrangerViewModel.trackHeightModifiers[trackId]!,
      );
      _cache[heightIndex] = trackHeight;
      _trackIdToIndex[trackId] = i;
      totalTrackHeight += trackHeight;
    }

    final trackGap = max(
      0.0,
      editorHeight - (totalTrackHeight + addButtonAreaHeight),
    );

    arrangerViewModel.regularToSendGapHeight = trackGap;

    var lastWasSendTrack = false;
    var positionPointer = -arrangerViewModel.verticalScrollPosition;

    for (final (i, (_, isSendTrack)) in allTracksIterable.indexed) {
      final heightIndex = i * 2;
      final positionIndex = heightIndex + 1;

      if (isSendTrack && !lastWasSendTrack) {
        lastWasSendTrack = true;
        positionPointer += trackGap + addButtonAreaHeight;
      }

      _cache[positionIndex] = positionPointer;
      positionPointer += _cache[heightIndex];
    }

    arrangerViewModel.scrollAreaHeight =
        positionPointer + arrangerViewModel.verticalScrollPosition;
  }
}
