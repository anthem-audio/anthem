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

class ArrangerClipMoveState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ProjectModel get project => arrangerStateMachine.project;
  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;

  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  /// The IDs of clips that are being moved by this operation.
  Set<Id>? _movingClipIds;

  /// At the start of the drag, this represents the distance between the
  /// left-most selected clip and the start of the arrangement.
  ///
  /// This is calculated because we cannot move clips any further than this,
  /// otherwise at least one of them would start before the start of the
  /// arrangement.
  int _minimumMoveDelta = 0;

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to clip move',
      from: ArrangerDragState,
      to: ArrangerClipMoveState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).shouldDelegateToClipMove,
    ),
    .new(
      name: 'Cancel clip move',
      from: ArrangerClipMoveState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Clip move fallback to drag',
      from: ArrangerClipMoveState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerClipMoveState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerClipMoveState(super.parentState);

  @override
  void onEntry({required event, required from}) {
    _initializeMoveSession();
    _syncClipOverrides();
  }

  @override
  void onActive({required event}) {
    _syncClipOverrides();
  }

  @override
  void onExit({required event, required to}) {
    _commitMoveSessionIfNeeded(event: event);
    _clearMoveSession();
  }

  void _commitMoveSessionIfNeeded({required EditorStateMachineEvent event}) {
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

    final movingClipIds = _movingClipIds;
    final arrangementId = project.sequence.activeArrangementID;
    if (movingClipIds == null || arrangementId == null) {
      return;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    if (arrangement == null) {
      return;
    }

    final arrangementClips = arrangement.clips.nonObservableInner;
    final clipTimingOverrides =
        viewModel.clipTimingOverrides.nonObservableInner;
    final clipMoves = <({Id clipID, int oldOffset, int newOffset})>[];

    for (final clipId in movingClipIds) {
      final clip = arrangementClips[clipId];
      final clipTimingOverride = clipTimingOverrides[clipId];
      if (clip == null || clipTimingOverride == null) {
        continue;
      }

      final oldOffset = clip.offset;
      final newOffset = clipTimingOverride.offset;
      if (oldOffset == newOffset) {
        continue;
      }

      clipMoves.add((
        clipID: clip.id,
        oldOffset: oldOffset,
        newOffset: newOffset,
      ));
    }

    if (clipMoves.isEmpty) {
      return;
    }

    project.execute(
      MoveClipsCommand(arrangementID: arrangement.id, clipMoves: clipMoves),
    );
  }

  void _initializeMoveSession() {
    _movingClipIds = null;
    _minimumMoveDelta = 0;
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

    final pressedClipId = parentState.dragStartClipId;
    if (pressedClipId == null) {
      return;
    }

    final pressedClip = arrangementClips[pressedClipId];
    if (pressedClip == null) {
      return;
    }

    viewModel.pressedClip = pressedClip.id;

    final selectedClips = viewModel.selectedClips;
    var selectedClipIds = selectedClips.nonObservableInner;
    if (!selectedClipIds.contains(pressedClip.id)) {
      selectedClips.clear();
      selectedClipIds = selectedClips.nonObservableInner;
    }

    final movingClipIds = selectedClipIds.contains(pressedClip.id)
        ? selectedClipIds.toSet()
        : <Id>{pressedClip.id};
    _movingClipIds = Set<Id>.unmodifiable(movingClipIds);

    int? smallestStartOffset;
    var hasAnyOverrides = false;

    for (final clipId in _movingClipIds!) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        continue;
      }
      hasAnyOverrides = true;

      final timeViewStart = clip.timeView?.start ?? 0;
      final timeViewEnd = clip.timeView?.end ?? clip.width;

      clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: clip.offset,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
      );

      if (smallestStartOffset == null || clip.offset < smallestStartOffset) {
        smallestStartOffset = clip.offset;
      }
    }

    if (!hasAnyOverrides) {
      _movingClipIds = null;
      return;
    }

    _minimumMoveDelta = -(smallestStartOffset ?? 0);
  }

  void _syncClipOverrides() {
    final movingClipIds = _movingClipIds;
    final dragStartPosition = parentState.dragStartPosition;
    final dragCurrentPosition = parentState.dragCurrentPosition;
    if (movingClipIds == null ||
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
    final arrangementClips = arrangement.clips.nonObservableInner;

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
    var movedDistance = currentTimeRounded - startTimeRounded;

    if (!interactionState.isAltPressed) {
      movedDistance = getSnappedDragDelta(
        startTime: startTimeRounded,
        currentTime: currentTimeRounded,
        divisionChanges: arrangerStateMachine.divisionChanges(),
      );
    }

    if (movedDistance < _minimumMoveDelta) {
      movedDistance = _minimumMoveDelta;
    }

    final clipTimingOverrides = viewModel.clipTimingOverrides;

    for (final clipId in movingClipIds) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        clipTimingOverrides.remove(clipId);
        continue;
      }

      final timeViewStart = clip.timeView?.start ?? 0;
      final timeViewEnd = clip.timeView?.end ?? clip.width;
      final nextOffset = clip.offset + movedDistance;

      final currentOverride = clipTimingOverrides.nonObservableInner[clip.id];
      if (currentOverride != null &&
          currentOverride.offset == nextOffset &&
          currentOverride.timeViewStart == timeViewStart &&
          currentOverride.timeViewEnd == timeViewEnd) {
        continue;
      }

      clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: nextOffset,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
      );
    }
  }

  void _clearMoveSession() {
    _movingClipIds = null;
    _minimumMoveDelta = 0;
    viewModel.clipTimingOverrides.clear();
    viewModel.pressedClip = null;
  }
}
