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

class ArrangerClipResizeState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ProjectModel get project => arrangerStateMachine.project;
  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;

  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  Set<Id>? _resizingClipIds;
  final Map<Id, _ClipResizeBaseline> _resizeBaselines = {};
  ResizeAreaType? _resizeAreaType;

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
    final clipTimingOverrides = viewModel.clipTimingOverrides;
    clipTimingOverrides.clear();

    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    if (arrangement == null) {
      return;
    }
    final arrangementClips = arrangement.clips.nonObservableInner;

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
    }
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

    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    if (arrangement == null) {
      return;
    }

    final startTime = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: dragStartPosition.x,
    );
    final currentTime = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: dragCurrentPosition.x,
    );

    final startTimeRounded = startTime.round();
    final currentTimeRounded = currentTime.round();
    var resizeDelta = currentTimeRounded - startTimeRounded;
    final divisionChanges = arrangerStateMachine.divisionChanges();
    if (!interactionState.isAltPressed) {
      resizeDelta = getSnappedDragDelta(
        startTime: startTimeRounded,
        currentTime: currentTimeRounded,
        divisionChanges: divisionChanges,
      );
      resizeDelta = _clampSnappedDeltaToValidRange(
        startTime: startTimeRounded,
        resizeDelta: resizeDelta,
        divisionChanges: divisionChanges,
      );
    } else {
      resizeDelta = _clampDeltaToValidRange(resizeDelta);
    }

    final clipTimingOverrides = viewModel.clipTimingOverrides;

    for (final clipId in resizingClipIds) {
      final clip = arrangement.clips.nonObservableInner[clipId];
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

  int _clampSnappedDeltaToValidRange({
    required int startTime,
    required int resizeDelta,
    required List<DivisionChange> divisionChanges,
  }) {
    if (_isResizeDeltaValid(resizeDelta)) {
      return resizeDelta;
    }

    var guardedDelta = resizeDelta;
    if (guardedDelta == 0) {
      return guardedDelta;
    }

    // Keep stepping one snap interval toward zero until we reach a valid
    // snapped size. This prevents stepping to the next snap when that would
    // make any clip zero/negative width.
    var loopCount = 0;
    while (!_isResizeDeltaValid(guardedDelta) &&
        guardedDelta != 0 &&
        loopCount < 8192) {
      guardedDelta = stepSnappedDragDeltaTowardZero(
        startTime: startTime,
        snappedDelta: guardedDelta,
        divisionChanges: divisionChanges,
      );

      loopCount++;
    }

    if (_isResizeDeltaValid(guardedDelta)) {
      return guardedDelta;
    }

    return _clampDeltaToValidRange(resizeDelta);
  }

  int _clampDeltaToValidRange(int resizeDelta) {
    final (minDelta, maxDelta) = _getValidResizeDeltaRange();
    if (resizeDelta < minDelta) {
      return minDelta;
    }

    if (resizeDelta > maxDelta) {
      return maxDelta;
    }

    return resizeDelta;
  }

  /// Looks at all resized clips and the current resize side, then determines
  /// the range of delta values that keep every clip in a valid state. Valid
  /// state in this case means:
  /// - Clip size is greater than 0
  /// - Clip offset is greater than or equal to 0 (for start-handle resize)
  (int minDelta, int maxDelta) _getValidResizeDeltaRange() {
    final resizeAreaType = _resizeAreaType;
    if (resizeAreaType == null) {
      return (0, 0);
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

    return (minDelta, maxDelta);
  }

  bool _isResizeDeltaValid(int resizeDelta) {
    if (_resizeAreaType == null) {
      return false;
    }

    final (minDelta, maxDelta) = _getValidResizeDeltaRange();
    return resizeDelta >= minDelta && resizeDelta <= maxDelta;
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
    final arrangementId = project.sequence.activeArrangementID;
    if (resizingClipIds == null || arrangementId == null) {
      return;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    if (arrangement == null) {
      return;
    }

    final arrangementClips = arrangement.clips.nonObservableInner;
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
    viewModel.clipTimingOverrides.clear();
    viewModel.pressedClip = null;
  }
}
