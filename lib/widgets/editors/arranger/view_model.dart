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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart' show TimeViewModel;
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

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

class AutomationParameterTarget {
  final Id ownerTrackId;
  final Id nodeId;
  final int portId;
  final String ownerName;
  final String parameterName;

  const AutomationParameterTarget({
    required this.ownerTrackId,
    required this.nodeId,
    required this.portId,
    required this.ownerName,
    required this.parameterName,
  });

  String get title => '$ownerName $parameterName';
}

class PhantomAutomationLaneInfo {
  final Id id;
  final Id parentTrackId;
  final AutomationParameterTarget? target;

  const PhantomAutomationLaneInfo({
    required this.id,
    required this.parentTrackId,
    required this.target,
  });

  String get title => target?.title ?? 'No automation selected';
}

sealed class ArrangerRow {
  final bool isSendTrack;
  final int trackDepth;

  const ArrangerRow({required this.isSendTrack, required this.trackDepth});

  Id get rowId;
}

class TrackArrangerRow extends ArrangerRow {
  final Id trackId;

  const TrackArrangerRow({
    required this.trackId,
    required super.isSendTrack,
    required super.trackDepth,
  });

  @override
  Id get rowId => trackId;
}

class PhantomAutomationArrangerRow extends ArrangerRow {
  final PhantomAutomationLaneInfo phantomLane;

  const PhantomAutomationArrangerRow({
    required this.phantomLane,
    required super.isSendTrack,
    required super.trackDepth,
  });

  @override
  Id get rowId => phantomLane.id;
}

abstract class _ArrangerViewModel with Store {
  final ProjectModel project;
  final ProjectId projectId;

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

  /// The clip that is currently being pressed, if any.
  @observable
  Id? pressedClip;

  /// The clip currently under the mouse cursor, if any.
  @observable
  Id? hoveredClip;

  /// The clip that should currently display inline automation handles, if any.
  @observable
  Id? clipWithAutomationHandles;

  /// The inline automation handle currently under the mouse cursor, if any.
  @observable
  AutomationHandleAnnotation? hoveredAutomationHandle;

  /// The inline automation handle that is being pressed, if any.
  @observable
  AutomationHandleAnnotation? pressedAutomationHandle;

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
  late final TrackPositionAndSize trackPositionCalculator;

  final visibleClips = CanvasAnnotationSet<Id>();
  final visibleResizeAreas =
      CanvasAnnotationSet<({Id id, ResizeAreaType type})>();
  final visibleAutomationHandles =
      CanvasAnnotationSet<AutomationHandleAnnotation>();

  // Project model IDs are non-negative. Phantom rows are arranger-only view
  // state, so keep them in a separate negative ID range.
  final _phantomAutomationLaneIdByParentTrackId = <Id, Id>{};
  Id _nextPhantomAutomationLaneId = -1;

  _ArrangerViewModel({
    required this.project,
    required this.baseTrackHeight,
    required this.timeView,
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
    trackPositionCalculator = TrackPositionAndSize(
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

  void refreshTrackLayout(double editorHeight) {
    trackPositionCalculator.invalidate(editorHeight);
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

  int visibleSubtreeRowCount(Id rootTrackId) {
    var count = 0;

    void countTrack(Id trackId) {
      final track = project.tracks[trackId];
      if (track == null) {
        return;
      }

      count++;

      if (!track.isAutomationLane &&
          (automationExpandedByTrackId[track.id] ?? false)) {
        if (phantomAutomationLaneForTrack(track.id) != null) {
          count++;
        }

        count += track.automationLanes.length;
      }

      for (final childTrackId in track.childTracks) {
        countTrack(childTrackId);
      }
    }

    countTrack(rootTrackId);
    return count;
  }

  Iterable<ArrangerRow> getVisibleRows() sync* {
    final topLevelTracks = project.trackOrder
        .map((trackId) => (trackId, false))
        .followedBy(project.sendTrackOrder.map((trackId) => (trackId, true)));

    Iterable<ArrangerRow> yieldChildren(
      Id trackId,
      bool isSendTrack,
      int currentDepth,
    ) sync* {
      yield TrackArrangerRow(
        trackId: trackId,
        isSendTrack: isSendTrack,
        trackDepth: currentDepth,
      );

      final track = project.tracks[trackId];
      if (track == null) {
        return;
      }

      if (!track.isAutomationLane &&
          (automationExpandedByTrackId[trackId] ?? false)) {
        final phantomLane = phantomAutomationLaneForTrack(trackId);
        if (phantomLane != null) {
          yield PhantomAutomationArrangerRow(
            phantomLane: phantomLane,
            isSendTrack: isSendTrack,
            trackDepth: currentDepth + 1,
          );
        }

        for (final automationLaneId in track.automationLanes) {
          yield TrackArrangerRow(
            trackId: automationLaneId,
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
@visibleForTesting
class TrackPositionAndSize {
  static const _addButtonAreaHeight = 33.0;

  ProjectModel projectModel;
  ArrangerViewModel arrangerViewModel;

  var _cache = Float64List(0);
  final _rowIdToIndex = <Id, int>{};
  final _rowIdToRow = <Id, ArrangerRow>{};
  final _trackIdToIndex = <Id, int>{};
  final _trackIndexToId = <int, Id>{};
  final _rowIndexToRow = <int, ArrangerRow>{};
  List<ArrangerRow> _visibleRows = const [];

  TrackPositionAndSize(this.projectModel, this.arrangerViewModel);

  final layoutRevision = ValueNotifier<int>(0);

  List<ArrangerRow> get visibleRows => _visibleRows;

  int? tryRowIdToIndex(Id rowId) => _rowIdToIndex[rowId];
  int rowIdToIndex(Id rowId) => _rowIdToIndex[rowId]!;
  ArrangerRow? tryRowIdToRow(Id rowId) => _rowIdToRow[rowId];
  int? tryTrackIdToIndex(Id trackId) => _trackIdToIndex[trackId];
  int trackIdToIndex(Id trackId) => _trackIdToIndex[trackId]!;
  Id trackIndexToId(int index) => _trackIndexToId[index]!;
  Id? tryTrackIndexToId(int index) => _trackIndexToId[index];
  ArrangerRow rowAtIndex(int index) => _rowIndexToRow[index]!;
  ({int rowIndex, double fraction, ArrangerRow row})? rowAtPosition(
    double yPosition, {
    bool includeBorder = false,
  }) {
    for (int i = 0; i < _cache.length ~/ 2; i++) {
      final trackPosition = _cache[i * 2 + 1];
      final trackHeight = _cache[i * 2];
      final trackBottom = trackPosition + trackHeight;
      // The last pixel is the divider between rows.
      final hitBottom = includeBorder ? trackBottom : trackBottom - 1;

      if (yPosition >= trackPosition && yPosition < hitBottom) {
        return (
          rowIndex: i,
          fraction: (yPosition - trackPosition) / trackHeight,
          row: rowAtIndex(i),
        );
      }
    }

    return null;
  }

  double getTrackHeight(int trackIndex) => _cache[trackIndex * 2];
  double getTrackPosition(num fractionalTrackIndex) =>
      _cache[fractionalTrackIndex.floor() * 2 + 1] +
      getTrackHeight(fractionalTrackIndex.floor()) *
          fractionalTrackIndex.remainder(1.0);

  /// Gets the track index plus a [0 - 1) offset from the top of the track,
  /// given a y-offset from the top of the screen.
  double getTrackIndexFromPosition(double yPosition) {
    final rowHit = rowAtPosition(yPosition);
    return rowHit == null
        ? double.infinity
        : rowHit.rowIndex.toDouble() + rowHit.fraction;
  }

  /// To be called on build in a LayoutBuilder, as soon as we can know the
  /// height of the editor and before any further build or render work is done.
  ///
  /// This is meant to be used with a MobX observer.
  ///
  /// This also clamps the vertical scroll position after recalculating the
  /// scrollable height, then refreshes track positions again if the clamp
  /// changed the scroll position.
  void invalidate(double editorHeight) {
    arrangerViewModel.editorHeight = editorHeight;

    final visibleRows = arrangerViewModel.getVisibleRows().toList(
      growable: false,
    );
    final previousRows = _visibleRows;
    final trackCount = visibleRows.length;
    var layoutChanged = previousRows.length != trackCount;

    if (_cache.length != trackCount * 2) {
      _cache = Float64List(trackCount * 2);
    }
    _rowIdToIndex.clear();
    _rowIdToRow.clear();
    _trackIdToIndex.clear();
    _trackIndexToId.clear();
    _rowIndexToRow.clear();
    _visibleRows = visibleRows;

    var totalTrackHeight = 0.0;
    for (final (i, row) in visibleRows.indexed) {
      final heightIndex = i * 2;
      final trackHeight = switch (row) {
        TrackArrangerRow() ||
        PhantomAutomationArrangerRow() => calculateTrackHeight(
          arrangerViewModel.baseTrackHeight,
          arrangerViewModel.rowHeightModifier(row.rowId),
        ),
      };
      if (!layoutChanged) {
        layoutChanged =
            _cache[heightIndex] != trackHeight ||
            !_sameLayoutRow(previousRows[i], row);
      }
      _cache[heightIndex] = trackHeight;
      _rowIdToIndex[row.rowId] = i;
      _rowIdToRow[row.rowId] = row;
      _rowIndexToRow[i] = row;
      if (row case TrackArrangerRow(:final trackId)) {
        _trackIdToIndex[trackId] = i;
        _trackIndexToId[i] = trackId;
      }
      totalTrackHeight += trackHeight;
    }

    final trackGap = max(
      0.0,
      editorHeight - (totalTrackHeight + _addButtonAreaHeight) + 1,
    );

    if (!layoutChanged) {
      layoutChanged = arrangerViewModel.regularToSendGapHeight != trackGap;
    }

    arrangerViewModel.regularToSendGapHeight = trackGap;

    arrangerViewModel.scrollAreaHeight = _updateCachedTrackPositions(
      visibleRows,
      trackGap,
    );

    final clampedVerticalScrollPosition = arrangerViewModel
        .verticalScrollPosition
        .clamp(0.0, arrangerViewModel.maxVerticalScrollPosition);

    if (clampedVerticalScrollPosition !=
        arrangerViewModel.verticalScrollPosition) {
      arrangerViewModel.verticalScrollPosition = clampedVerticalScrollPosition;
      arrangerViewModel.scrollAreaHeight = _updateCachedTrackPositions(
        visibleRows,
        trackGap,
      );
    }

    if (layoutChanged) {
      layoutRevision.value++;
    }
  }

  bool _sameLayoutRow(ArrangerRow previousRow, ArrangerRow nextRow) {
    return previousRow.rowId == nextRow.rowId &&
        previousRow.isSendTrack == nextRow.isSendTrack &&
        previousRow.trackDepth == nextRow.trackDepth;
  }

  double _updateCachedTrackPositions(
    Iterable<ArrangerRow> allRows,
    double trackGap,
  ) {
    var lastWasSendTrack = false;
    var positionPointer = -arrangerViewModel.verticalScrollPosition;

    for (final (i, row) in allRows.indexed) {
      final heightIndex = i * 2;
      final positionIndex = heightIndex + 1;

      if (row.isSendTrack && !lastWasSendTrack) {
        lastWasSendTrack = true;
        positionPointer += trackGap + _addButtonAreaHeight;
      }

      _cache[positionIndex] = positionPointer;
      positionPointer += _cache[heightIndex];
    }

    return positionPointer + arrangerViewModel.verticalScrollPosition - 1;
  }
}
