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

part of 'arranger_state_machine.dart';

/// Immutable snapshot of a clip's timing at the moment a resize session
/// begins. We freeze these at session start and resolve every preview tick
/// from them - the underlying [ClipModel] isn't mutated during the drag, so
/// using the baseline (rather than re-reading the clip) keeps the delta math
/// stable even if the UI redraws mid-drag.
class _ClipResizeBaseline {
  final int oldOffset;
  final TimeViewModel? oldTimeView;
  final int oldTimeViewStart;
  final int oldTimeViewEnd;

  const _ClipResizeBaseline({
    required this.oldOffset,
    required this.oldTimeView,
    required this.oldTimeViewStart,
    required this.oldTimeViewEnd,
  });

  int get oldWidth => oldTimeViewEnd - oldTimeViewStart;
}

class ArrangerClipResizeState extends _ArrangerLeafState {
  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  Set<Id>? _resizingClipIds;
  final Map<Id, _ClipResizeBaseline> _resizeBaselines = {};
  ResizeAreaType? _resizeAreaType;

  /// The min/max delta that keeps every participating clip in a valid state,
  /// cached once in [_initializeResizeSession]. Baselines don't change during
  /// a session, so this range doesn't need to be recomputed per move event.
  ({int minDelta, int maxDelta}) _validResizeDeltaRange = (
    minDelta: 0,
    maxDelta: 0,
  );

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to clip resize',
      from: ArrangerDragState,
      to: ArrangerClipResizeState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).interactionFamily ==
          ArrangerInteractionFamily.clipResize,
    ),
    .new(
      name: 'Cancel clip resize',
      from: ArrangerClipResizeState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Clip resize fallback to drag',
      from: ArrangerClipResizeState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerClipResizeState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerClipResizeState(super.parentState);

  @override
  void onEntry({required event, required from}) {
    _initializeResizeSession();
    _syncClipOverrides();
  }

  @override
  void onActive({required event}) {
    _syncClipOverrides();
  }

  @override
  void onExit({required event, required to}) {
    _commitResizeSessionIfNeeded(event: event);
    _clearResizeSession();
  }

  void _initializeResizeSession() {
    _resizingClipIds = null;
    _resizeBaselines.clear();
    _resizeAreaType = null;
    _validResizeDeltaRange = (minDelta: 0, maxDelta: 0);
    final clipTimingOverrides = viewModel.clipTimingOverrides;
    clipTimingOverrides.clear();

    final arrangementData = activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }
    final arrangementClips = arrangementData.clips;

    final pressedClipId = parentState.dragStartResizeHandleClipId;
    final resizeAreaType = parentState.dragStartResizeAreaType;
    if (pressedClipId == null || resizeAreaType == null) {
      return;
    }

    final pressedClip = arrangementClips[pressedClipId];
    if (pressedClip == null) {
      return;
    }

    _resizeAreaType = resizeAreaType;
    viewModel.pressedClip = pressedClip.id;

    final selectedClips = viewModel.selectedClips;
    var selectedClipIds = selectedClips.nonObservableInner;
    if (!selectedClipIds.contains(pressedClip.id)) {
      selectedClips.clear();
      selectedClipIds = selectedClips.nonObservableInner;
    }

    final resizingClipIds = selectedClipIds.contains(pressedClip.id)
        ? selectedClipIds.toSet()
        : <Id>{pressedClip.id};
    _resizingClipIds = Set<Id>.unmodifiable(resizingClipIds);

    var hasAnyOverrides = false;
    for (final clipId in _resizingClipIds!) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        continue;
      }

      hasAnyOverrides = true;
      final oldTimeViewStart = clip.timeView?.start ?? 0;
      final oldTimeViewEnd = clip.timeView?.end ?? clip.width;

      _resizeBaselines[clip.id] = _ClipResizeBaseline(
        oldOffset: clip.offset,
        oldTimeView: clip.timeView?.clone(),
        oldTimeViewStart: oldTimeViewStart,
        oldTimeViewEnd: oldTimeViewEnd,
      );

      clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: clip.offset,
        timeViewStart: oldTimeViewStart,
        timeViewEnd: oldTimeViewEnd,
      );
    }

    if (!hasAnyOverrides) {
      _resizingClipIds = null;
      _resizeAreaType = null;
      _validResizeDeltaRange = (minDelta: 0, maxDelta: 0);
      return;
    }

    _validResizeDeltaRange = _getValidResizeDeltaRange();
  }

  void _syncClipOverrides() {
    final resizingClipIds = _resizingClipIds;
    final resizeAreaType = _resizeAreaType;
    final dragStartPosition = parentState.dragStartPosition;
    final dragCurrentPosition = parentState.dragCurrentPosition;
    if (resizingClipIds == null ||
        resizeAreaType == null ||
        dragStartPosition == null ||
        dragCurrentPosition == null) {
      return;
    }

    final arrangementData = activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }
    final arrangementClips = arrangementData.clips;

    final snappedDelta = resolveSnappedDragDelta(
      startPx: dragStartPosition.x,
      currentPx: dragCurrentPosition.x,
      snapOverridden: interactionState.isAltPressed,
    );
    var resizeDelta = snappedDelta.delta;
    final divisionChanges = arrangerStateMachine.divisionChanges();
    if (!interactionState.isAltPressed) {
      resizeDelta = _clampSnappedDeltaToValidRange(
        startTime: snappedDelta.startTime,
        resizeDelta: resizeDelta,
        divisionChanges: divisionChanges,
      );
    } else {
      resizeDelta = _clampDeltaToValidRange(resizeDelta);
    }

    final clipTimingOverrides = viewModel.clipTimingOverrides;

    for (final clipId in resizingClipIds) {
      final clip = arrangementClips[clipId];
      final baseline = _resizeBaselines[clipId];
      if (clip == null || baseline == null) {
        clipTimingOverrides.remove(clipId);
        continue;
      }

      var nextOffset = baseline.oldOffset;
      var nextTimeViewStart = baseline.oldTimeViewStart;
      var nextTimeViewEnd = baseline.oldTimeViewEnd;

      if (resizeAreaType == ResizeAreaType.start) {
        nextOffset += resizeDelta;
        nextTimeViewStart += resizeDelta;
      } else {
        nextTimeViewEnd += resizeDelta;
      }

      final currentOverride = clipTimingOverrides.nonObservableInner[clip.id];
      if (currentOverride != null &&
          currentOverride.offset == nextOffset &&
          currentOverride.timeViewStart == nextTimeViewStart &&
          currentOverride.timeViewEnd == nextTimeViewEnd) {
        continue;
      }

      clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: nextOffset,
        timeViewStart: nextTimeViewStart,
        timeViewEnd: nextTimeViewEnd,
      );
    }
  }

  /// Pulls [resizeDelta] back into [_validResizeDeltaRange] one snap interval
  /// at a time.
  ///
  /// The snap interval can change when the time signature changes. If the snap
  /// interval were guaranteed to be the same everywhere, then this would be
  /// much simpler; but due to time signature change markers, we can have
  /// multiple grids active across a given time range. This stepping approach
  /// allows us to handle snapping correctly across any number of weird time
  /// signature markers.
  int _clampSnappedDeltaToValidRange({
    required int startTime,
    required int resizeDelta,
    required List<DivisionChange> divisionChanges,
  }) {
    final (:minDelta, :maxDelta) = _validResizeDeltaRange;
    var guardedDelta = resizeDelta;
    while (guardedDelta < minDelta || guardedDelta > maxDelta) {
      guardedDelta = stepSnappedDragDeltaTowardZero(
        startTime: startTime,
        snappedDelta: guardedDelta,
        divisionChanges: divisionChanges,
      );
    }
    return guardedDelta;
  }

  int _clampDeltaToValidRange(int resizeDelta) {
    final (:minDelta, :maxDelta) = _validResizeDeltaRange;
    if (resizeDelta < minDelta) {
      return minDelta;
    }

    if (resizeDelta > maxDelta) {
      return maxDelta;
    }

    return resizeDelta;
  }

  /// Computes the delta range that keeps every participating clip valid.
  ///
  /// "Valid" means:
  /// - Clip width stays greater than zero.
  /// - Clip offset stays non-negative (only relevant for the start handle,
  ///   since moving the start handle left shifts the offset).
  ///
  /// Called once at session start; the cached result is stored in
  /// [_validResizeDeltaRange] for reuse on every move event.
  ({int minDelta, int maxDelta}) _getValidResizeDeltaRange() {
    final resizeAreaType = _resizeAreaType;
    if (resizeAreaType == null) {
      return (minDelta: 0, maxDelta: 0);
    }

    const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;
    var minDelta = -maxSafeIntWeb;
    var maxDelta = maxSafeIntWeb;

    for (final baseline in _resizeBaselines.values) {
      if (resizeAreaType == ResizeAreaType.start) {
        minDelta = max(minDelta, -baseline.oldOffset);
        minDelta = max(minDelta, -baseline.oldTimeViewStart);
        maxDelta = min(maxDelta, baseline.oldWidth - 1);
      } else {
        minDelta = max(minDelta, 1 - baseline.oldWidth);
      }
    }

    return (minDelta: minDelta, maxDelta: maxDelta);
  }

  void _commitResizeSessionIfNeeded({required EditorStateMachineEvent event}) {
    if (isArrangerCancelSignal(event)) {
      return;
    }

    if (event is! EditorStateMachineSignalEvent) {
      return;
    }

    final signal = event.signal;
    if (signal is! _ArrangerPointerUpSignal ||
        signal.event is PointerCancelEvent) {
      return;
    }

    final resizingClipIds = _resizingClipIds;
    final arrangementData = activeArrangementWithClips();
    if (resizingClipIds == null || arrangementData == null) {
      return;
    }

    final arrangement = arrangementData.arrangement;
    final arrangementClips = arrangementData.clips;
    final clipTimingOverrides =
        viewModel.clipTimingOverrides.nonObservableInner;
    final clipResizes =
        <
          ({
            Id clipID,
            int oldOffset,
            TimeViewModel? oldTimeView,
            int newOffset,
            TimeViewModel newTimeView,
          })
        >[];

    for (final clipId in resizingClipIds) {
      final clip = arrangementClips[clipId];
      final baseline = _resizeBaselines[clipId];
      final clipTimingOverride = clipTimingOverrides[clipId];
      if (clip == null || baseline == null || clipTimingOverride == null) {
        continue;
      }

      final oldOffset = baseline.oldOffset;
      final oldTimeViewStart = baseline.oldTimeViewStart;
      final oldTimeViewEnd = baseline.oldTimeViewEnd;
      final newOffset = clipTimingOverride.offset;
      final newTimeViewStart = clipTimingOverride.timeViewStart;
      final newTimeViewEnd = clipTimingOverride.timeViewEnd;

      if (oldOffset == newOffset &&
          oldTimeViewStart == newTimeViewStart &&
          oldTimeViewEnd == newTimeViewEnd) {
        continue;
      }

      clipResizes.add((
        clipID: clip.id,
        oldOffset: oldOffset,
        oldTimeView: baseline.oldTimeView?.clone(),
        newOffset: newOffset,
        newTimeView: TimeViewModel(
          start: newTimeViewStart,
          end: newTimeViewEnd,
        ),
      ));
    }

    if (clipResizes.isEmpty) {
      return;
    }

    project.execute(
      ResizeClipsCommand(
        arrangementID: arrangement.id,
        clipResizes: clipResizes,
      ),
    );
  }

  void _clearResizeSession() {
    _resizingClipIds = null;
    _resizeBaselines.clear();
    _resizeAreaType = null;
    _validResizeDeltaRange = (minDelta: 0, maxDelta: 0);
    viewModel.clipTimingOverrides.clear();
    viewModel.pressedClip = null;
  }
}
