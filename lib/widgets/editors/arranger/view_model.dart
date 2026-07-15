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
import 'package:anthem/model/arrangement/clip.dart' show TimeViewModel;
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/track_layout.dart';
import 'package:anthem/widgets/editors/arranger/track_row.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/time_range_content_source.dart';
import 'package:anthem/widgets/editors/shared/time_range_viewport.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

export 'track_layout.dart';
export 'track_row.dart';

part 'view_model.g.dart';

// ignore: library_private_types_in_public_api
class ArrangerViewModel = _ArrangerViewModel with _$ArrangerViewModel;

enum ResizeAreaType { start, end }

class ClipTimingOverride {
  final int offset;
  final int timeViewStart;
  final int timeViewEnd;

  const ClipTimingOverride({
    required this.offset,
    required this.timeViewStart,
    required this.timeViewEnd,
  }) : assert(timeViewEnd > timeViewStart);
}

class ArrangerClipPreview {
  final Id clipId;
  final Id sourceClipId;
  final Id trackId;
  final int offset;
  final PatternModel pattern;
  final int timeViewStart;
  final int timeViewEnd;

  const ArrangerClipPreview({
    required this.clipId,
    required this.sourceClipId,
    required this.trackId,
    required this.offset,
    required this.pattern,
    required this.timeViewStart,
    required this.timeViewEnd,
  }) : assert(timeViewEnd > timeViewStart);

  ArrangerClipPreview copyWith({int? offset}) {
    return ArrangerClipPreview(
      clipId: clipId,
      sourceClipId: sourceClipId,
      trackId: trackId,
      offset: offset ?? this.offset,
      pattern: pattern,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }
}

class ArrangerHitTestResult {
  final CanvasAnnotationHit<Id>? clip;
  final CanvasAnnotation<({Id id, ResizeAreaType type})>? resizeHandle;
  final CanvasAnnotation<AutomationHandleAnnotation>? automationHandle;

  const ArrangerHitTestResult({
    this.clip,
    this.resizeHandle,
    this.automationHandle,
  });
}

abstract class _ArrangerViewModel with Store {
  final ProjectModel project;
  final ProjectId projectId;

  @observable
  EditorTool tool = EditorTool.pencil;

  @observable
  TimeRange timeRange;

  TimeRangeViewport? _timeRangeViewport;

  TimeRangeViewport get timeRangeViewport {
    final timeRangeViewport = _timeRangeViewport;
    if (timeRangeViewport != null &&
        identical(timeRangeViewport.target, timeRange)) {
      return timeRangeViewport;
    }

    return _timeRangeViewport = TimeRangeViewport(
      target: timeRange,
      contentSource: const TimeRangeContentSource.arrangement(),
    );
  }

  @observable
  double baseTrackHeight;

  /// Per-track modifier that is multiplied by baseTrackHeight and clamped to
  /// get the actual height for each track
  @observable
  ObservableMap<Id, double> trackHeightModifiers;

  /// Whether each track's automation lanes are expanded in the arranger.
  final ObservableMap<Id, bool> automationExpandedByTrackId;

  /// Most recent automatable parameter changed by user/plugin interaction.
  @observable
  AutomationParameterTarget? lastTweakedAutomationTarget;

  /// Vertical scroll position, in pixels.
  @observable
  double verticalScrollPosition = 0;

  /// Current pattern that will be placed when the user places a pattern.
  @observable
  Id? cursorPattern;

  /// Time range for cursor pattern.
  @observable
  TimeViewModel? cursorTimeRange;

  /// Selection box in raw view-space coordinates relative to the top-left of
  /// the arranger canvas.
  @observable
  Rectangle<double>? selectionBox;

  @observable
  ObservableSet<Id> selectedTracks = ObservableSet();

  Id? lastToggledTrack;

  ({List<Id> selected, List<Id> notSelected})? lastShiftClickRange;

  @observable
  ObservableSet<Id> selectedClips = ObservableSet();

  final ObservableMap<Id, ClipTimingOverride> clipTimingOverrides =
      ObservableMap();

  final ObservableMap<Id, ArrangerClipPreview> previewClips = ObservableMap();

  /// The clip currently under the mouse cursor, if any.
  @observable
  Id? hoveredClip;

  /// The clip that should currently display inline automation handles, if any.
  @observable
  Id? clipWithAutomationHandles;

  /// The inline automation handle currently under the mouse cursor, if any.
  @observable
  AutomationHandleAnnotation? hoveredAutomationHandle;

  /// Used to preserve automation point tension when adding points inline.
  double? lastInteractedAutomationTension;

  /// The position of the cursor that shows when you hover over a row.
  @observable
  ({double offset, Id rowId})? hoverIndicatorPosition;

  /// The current mouse cursor for the arranger canvas.
  @observable
  MouseCursor mouseCursor = MouseCursor.defer;

  /// The box that shows to indicate where a new clip will be created while
  /// creating a clip.
  @observable
  ({Id rowId, double startOffset, double endOffset, Color color})?
  clipCreateHint;

  /// Calculates and caches the size and position of tracks in the current view.
  late final TrackLayout trackLayout;

  final visibleClips = CanvasAnnotationSet<Id>();
  final visibleResizeAreas =
      CanvasAnnotationSet<({Id id, ResizeAreaType type})>();
  final visibleAutomationHandles =
      CanvasAnnotationSet<AutomationHandleAnnotation>();

  double? _renderCacheDevicePixelRatio;

  // Project model IDs are non-negative. Phantom rows are arranger-only view
  // state, so keep them in a separate negative ID range.
  final _phantomAutomationLaneIdByParentTrackId = <Id, Id>{};
  Id _nextPhantomAutomationLaneId = -1;

  _ArrangerViewModel({
    required this.project,
    required this.baseTrackHeight,
    required this.timeRange,
  }) : projectId = project.id,
       trackHeightModifiers = ObservableMap.of(
         project.tracks.nonObservableInner.map(
           (key, value) => MapEntry(key, 1),
         ),
       ),
       automationExpandedByTrackId = ObservableMap.of(
         project.tracks.nonObservableInner.map(
           (key, value) => MapEntry(key, false),
         ),
       ) {
    trackLayout = TrackLayout();
  }

  void ensureRenderCachesForDevicePixelRatio(double devicePixelRatio) {
    if (_renderCacheDevicePixelRatio != devicePixelRatio) {
      _renderCacheDevicePixelRatio = devicePixelRatio;
      project.sequence.scheduleClipTitleTextureAtlasUpdate();
    }
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

  void refreshTrackLayout(
    double editorHeight, {
    double headerWidth = TrackLayout.defaultHeaderWidth,
  }) {
    this.editorHeight = editorHeight;

    trackLayout.recalculate(
      rows: getVisibleTrackRows(),
      rowHeightFor: (row) =>
          calculateTrackHeight(baseTrackHeight, rowHeightModifier(row.rowId)),
      headerWidth: headerWidth,
      viewportHeight: editorHeight,
    );

    regularToSendGapHeight = trackLayout.regularToSendGapSpan.height;
    scrollAreaHeight = trackLayout.contentHeight;
    verticalScrollPosition = verticalScrollPosition.clamp(
      0.0,
      maxVerticalScrollPosition,
    );
  }

  void applyVerticalScrollDelta(double pixelDelta) {
    verticalScrollPosition =
        (verticalScrollPosition +
                pixelDelta *
                    0.01 *
                    baseTrackHeight.clamp(minTrackHeight, maxTrackHeight))
            .clamp(0.0, maxVerticalScrollPosition);
  }

  /// Calculates the clip and inline handles under the cursor, if there are any.
  ArrangerHitTestResult hitTestContent(Offset pos) {
    final clipUnderCursor = visibleClips.hitTest(pos);
    final clipUnderCursorId = clipUnderCursor?.annotation.metadata;
    final automationHandleCandidates = visibleAutomationHandles
        .hitTestAll(pos)
        .where((element) => element.metadata.clipId == clipUnderCursorId);
    final automationHandleUnderCursor =
        automationHandleCandidates.firstWhereOrNull(
          (element) => element.metadata.kind == AutomationHandleKind.point,
        ) ??
        automationHandleCandidates.firstOrNull;
    final resizeHandleCandidates = visibleResizeAreas
        .hitTestAll(pos)
        // We only report a resize handle if the cursor is also over the
        // associated clip, or if the cursor is over no clip. This makes the
        // behavior for clip resizing a bit more predictable, as it then doesn't
        // depend on the Z-ordering of clips for clips that are right next to
        // each other.
        .where(
          (element) =>
              clipUnderCursorId == null ||
              element.metadata.id == clipUnderCursorId,
        );
    final resizeHandleUnderCursor =
        resizeHandleCandidates.firstWhereOrNull(
          (element) => element.metadata.type == ResizeAreaType.end,
        ) ??
        resizeHandleCandidates.firstOrNull;
    return ArrangerHitTestResult(
      clip: clipUnderCursor,
      resizeHandle: resizeHandleUnderCursor,
      automationHandle: automationHandleUnderCursor,
    );
  }

  void registerTrack(Id trackId) {
    trackHeightModifiers[trackId] = 1;
    automationExpandedByTrackId[trackId] = false;
  }

  void unregisterTrack(Id trackId) {
    trackHeightModifiers.remove(trackId);
    automationExpandedByTrackId.remove(trackId);
    final phantomLaneId = _phantomAutomationLaneIdByParentTrackId.remove(
      trackId,
    );
    if (phantomLaneId != null) {
      trackHeightModifiers.remove(phantomLaneId);
    }
  }

  double rowHeightModifier(Id rowId) => trackHeightModifiers[rowId] ?? 1;

  void setRowHeightModifier(Id rowId, double modifier) {
    trackHeightModifiers[rowId] = modifier;
  }

  void resetRowHeightModifier(Id rowId) {
    setRowHeightModifier(rowId, 1);
  }

  Id _phantomAutomationLaneIdForTrack(Id trackId) {
    return _phantomAutomationLaneIdByParentTrackId.putIfAbsent(
      trackId,
      () => _nextPhantomAutomationLaneId--,
    );
  }

  Id? automationLaneIdForTarget(AutomationParameterTarget target) {
    final parentTrack = project.tracks[target.ownerTrackId];
    if (parentTrack == null) {
      return null;
    }

    for (final automationLaneId in parentTrack.automationLanes) {
      final lane = project.tracks[automationLaneId];
      final laneTarget = lane?.automationTarget;
      if (laneTarget == null) {
        continue;
      }

      if (laneTarget.nodeId == target.nodeId &&
          laneTarget.portId == target.portId) {
        return automationLaneId;
      }
    }

    return null;
  }

  bool hasAutomationLaneForTarget(AutomationParameterTarget target) =>
      automationLaneIdForTarget(target) != null;

  PhantomAutomationLaneInfo? phantomAutomationLaneForTrack(Id trackId) {
    final track = project.tracks[trackId];
    if (track == null || track.isAutomationLane) {
      return null;
    }

    if (!(automationExpandedByTrackId[trackId] ?? false)) {
      return null;
    }

    final lastTweakedTarget = lastTweakedAutomationTarget;
    if (lastTweakedTarget?.ownerTrackId == trackId &&
        !hasAutomationLaneForTarget(lastTweakedTarget!)) {
      return PhantomAutomationLaneInfo(
        id: _phantomAutomationLaneIdForTrack(trackId),
        parentTrackId: trackId,
        target: lastTweakedTarget,
      );
    }

    if (track.automationLanes.isEmpty) {
      return PhantomAutomationLaneInfo(
        id: _phantomAutomationLaneIdForTrack(trackId),
        parentTrackId: trackId,
        target: null,
      );
    }

    return null;
  }

  Iterable<TrackRow> getVisibleTrackRows() sync* {
    final topLevelTracks = project.trackOrder
        .map((trackId) => (trackId, false))
        .followedBy(project.sendTrackOrder.map((trackId) => (trackId, true)));

    Iterable<TrackRow> yieldChildren(
      Id trackId,
      bool isSendTrack,
      int currentDepth,
    ) sync* {
      final track = project.tracks[trackId];
      yield ProjectTrackRow(
        trackId: trackId,
        rowKind: track?.isAutomationLane == true
            ? TrackRowKind.automationLane
            : TrackRowKind.track,
        isSendTrack: isSendTrack,
        trackDepth: currentDepth,
      );

      if (track == null) {
        return;
      }

      if (!track.isAutomationLane &&
          (automationExpandedByTrackId[trackId] ?? false)) {
        final phantomLane = phantomAutomationLaneForTrack(trackId);
        if (phantomLane != null) {
          yield PhantomAutomationTrackRow(
            phantomLane: phantomLane,
            isSendTrack: isSendTrack,
            trackDepth: currentDepth + 1,
          );
        }

        for (final automationLaneId in track.automationLanes) {
          yield ProjectTrackRow(
            trackId: automationLaneId,
            rowKind: TrackRowKind.automationLane,
            isSendTrack: isSendTrack,
            trackDepth: currentDepth + 1,
          );
        }
      }

      for (final childTrackId in track.childTracks) {
        yield* yieldChildren(childTrackId, isSendTrack, currentDepth + 1);
      }
    }

    for (final topLevelTrack in topLevelTracks) {
      yield* yieldChildren(topLevelTrack.$1, topLevelTrack.$2, 0);
    }
  }
}
