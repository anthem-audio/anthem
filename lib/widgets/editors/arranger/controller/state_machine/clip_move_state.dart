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

class ArrangerClipMoveState extends _ArrangerLeafState {
  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  /// The IDs of clips that are being moved by this operation.
  Set<Id>? _movingClipIds;

  ReconstructedArrangerClipBatch? _duplicatedClipBatch;

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
          (currentState as ArrangerDragState).interactionFamily ==
          ArrangerInteractionFamily.clipMove,
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
    if (movingClipIds == null) {
      return;
    }

    if (_duplicatedClipBatch != null) {
      _commitDuplicatedMoveSession();
      return;
    }

    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }

    final arrangementClips = arrangementData.clips;
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

    project.execute(MoveClipsCommand(clipMoves: clipMoves));
  }

  void _commitDuplicatedMoveSession() {
    final duplicatedClipBatch = _duplicatedClipBatch;
    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (duplicatedClipBatch == null || arrangementData == null) {
      return;
    }

    final previewClips = viewModel.previewClips.nonObservableInner;
    final clipsToCommit = duplicatedClipBatch.clips
        .where((clip) => previewClips.containsKey(clip.id))
        .toList(growable: false);

    if (clipsToCommit.isEmpty) {
      return;
    }

    for (final clip in clipsToCommit) {
      clip.offset = previewClips[clip.id]!.offset;
    }

    final usedPatternIds = clipsToCommit.map((clip) => clip.patternId).toSet();
    final patternsToCommit = duplicatedClipBatch.patterns
        .where((pattern) => usedPatternIds.contains(pattern.id))
        .toList(growable: false);

    project.startUndoGroup();
    for (final pattern in patternsToCommit) {
      project.execute(PatternAddRemoveCommand.add(pattern: pattern));
    }
    for (final clip in clipsToCommit) {
      project.execute(ClipAddRemoveCommand.add(clip: clip));
    }
    project.commitUndoGroup();
  }

  ({int start, int end}) _timeViewBoundsForClip(ClipModel clip) {
    final timeViewStart = clip.timeView?.start ?? 0;
    final timeViewEnd = clip.timeView?.end ?? clip.width;
    assert(timeViewEnd > timeViewStart);

    return (start: timeViewStart, end: timeViewEnd);
  }

  bool _initializeTimingOverridesForMovingClips() {
    final movingClipIds = _movingClipIds;
    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (movingClipIds == null || arrangementData == null) {
      return false;
    }

    final arrangementClips = arrangementData.clips;
    int? smallestStartOffset;
    var hasAnyOverrides = false;

    for (final clipId in movingClipIds) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        continue;
      }

      hasAnyOverrides = true;
      final timeViewBounds = _timeViewBoundsForClip(clip);

      viewModel.clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: clip.offset,
        timeViewStart: timeViewBounds.start,
        timeViewEnd: timeViewBounds.end,
      );

      if (smallestStartOffset == null || clip.offset < smallestStartOffset) {
        smallestStartOffset = clip.offset;
      }
    }

    if (!hasAnyOverrides) {
      return false;
    }

    _minimumMoveDelta = -(smallestStartOffset ?? 0);
    return true;
  }

  bool _initializeDuplicatedMoveSession({
    required Map<Id, ClipModel> arrangementClips,
    required Set<Id> sourceMovingClipIds,
  }) {
    final sourceClips = <ClipModel>[];
    final patternsById = <Id, PatternModel>{};

    for (final clipId in sourceMovingClipIds) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        continue;
      }

      final pattern = project.sequence.patterns[clip.patternId];
      if (pattern == null) {
        continue;
      }

      sourceClips.add(clip);
      patternsById[pattern.id] = pattern;
    }

    if (sourceClips.isEmpty) {
      return false;
    }

    var anchorOffset = sourceClips.first.offset;
    for (final clip in sourceClips.skip(1)) {
      if (clip.offset < anchorOffset) {
        anchorOffset = clip.offset;
      }
    }

    final duplicatedClipBatch =
        SerializedArrangerClipBatch(
          anchorOffset: anchorOffset,
          clips: sourceClips,
          patterns: patternsById.values,
        ).reconstruct(
          idAllocator: ServiceRegistry.forProject(project.id).idAllocator,
          newAnchorOffset: anchorOffset,
          availableTrackIds: project.tracks.keys.toSet(),
        );

    if (duplicatedClipBatch.clips.isEmpty) {
      return false;
    }

    final patternById = {
      for (final pattern in duplicatedClipBatch.patterns) pattern.id: pattern,
    };
    final previewPatternById = {
      for (final entry in patternById.entries)
        entry.key: PatternModel.fromJson(entry.value.toJson()),
    };
    final sourceClipById = {for (final clip in sourceClips) clip.id: clip};
    final sourceClipIdByCloneId = {
      for (final entry in duplicatedClipBatch.clipIdBySourceId.entries)
        entry.value: entry.key,
    };
    final previewClipIds = <Id>{};

    for (final clip in duplicatedClipBatch.clips) {
      final pattern = previewPatternById[clip.patternId];
      final sourceClip = sourceClipById[sourceClipIdByCloneId[clip.id]];
      if (pattern == null || sourceClip == null) {
        continue;
      }

      final timeViewBounds = _timeViewBoundsForClip(sourceClip);
      viewModel.previewClips[clip.id] = ArrangerClipPreview(
        clipId: clip.id,
        sourceClipId: sourceClip.id,
        trackId: clip.trackId,
        offset: clip.offset,
        pattern: pattern,
        timeViewStart: timeViewBounds.start,
        timeViewEnd: timeViewBounds.end,
      );
      previewClipIds.add(clip.id);
    }

    if (previewClipIds.isEmpty) {
      viewModel.previewClips.clear();
      return false;
    }

    _duplicatedClipBatch = duplicatedClipBatch;
    _movingClipIds = Set<Id>.unmodifiable(previewClipIds);
    _minimumMoveDelta = -duplicatedClipBatch.clips
        .where((clip) => previewClipIds.contains(clip.id))
        .map((clip) => clip.offset)
        .reduce(min);

    viewModel.selectedClips
      ..clear()
      ..addAll(previewClipIds);

    return true;
  }

  void _initializeMoveSession() {
    _movingClipIds = null;
    _duplicatedClipBatch = null;
    _minimumMoveDelta = 0;
    final clipTimingOverrides = viewModel.clipTimingOverrides;
    clipTimingOverrides.clear();
    viewModel.previewClips.clear();

    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }
    final arrangementClips = arrangementData.clips;

    final dragStartClipId = parentState.dragStartContext?.movableClipId;
    if (dragStartClipId == null) {
      return;
    }

    final dragStartClip = arrangementClips[dragStartClipId];
    if (dragStartClip == null) {
      return;
    }

    final selectedClips = viewModel.selectedClips;
    var selectedClipIds = selectedClips.nonObservableInner;
    if (!selectedClipIds.contains(dragStartClip.id)) {
      selectedClips.clear();
      selectedClipIds = selectedClips.nonObservableInner;
    }

    final movingClipIds = selectedClipIds.contains(dragStartClip.id)
        ? selectedClipIds.toSet()
        : <Id>{dragStartClip.id};

    if (interactionState.isShiftPressed) {
      _initializeDuplicatedMoveSession(
        arrangementClips: arrangementClips,
        sourceMovingClipIds: movingClipIds,
      );
      return;
    }

    _movingClipIds = Set<Id>.unmodifiable(movingClipIds);

    if (!_initializeTimingOverridesForMovingClips()) {
      _movingClipIds = null;
    }
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

    var movedDistance = resolveSnappedDragDelta(
      startPx: dragStartPosition.x,
      currentPx: dragCurrentPosition.x,
      snapOverridden: interactionState.isAltPressed,
    ).delta;

    if (movedDistance < _minimumMoveDelta) {
      movedDistance = _minimumMoveDelta;
    }

    if (_duplicatedClipBatch != null) {
      _syncDuplicatedClipPreviews(movedDistance: movedDistance);
      return;
    }

    final arrangementData = arrangerStateMachine.activeArrangementWithClips();
    if (arrangementData == null) {
      return;
    }
    final arrangementClips = arrangementData.clips;
    final clipTimingOverrides = viewModel.clipTimingOverrides;

    for (final clipId in movingClipIds) {
      final clip = arrangementClips[clipId];
      if (clip == null) {
        clipTimingOverrides.remove(clipId);
        continue;
      }

      final timeViewBounds = _timeViewBoundsForClip(clip);
      final nextOffset = clip.offset + movedDistance;

      final currentOverride = clipTimingOverrides.nonObservableInner[clip.id];
      if (currentOverride != null &&
          currentOverride.offset == nextOffset &&
          currentOverride.timeViewStart == timeViewBounds.start &&
          currentOverride.timeViewEnd == timeViewBounds.end) {
        continue;
      }

      clipTimingOverrides[clip.id] = ClipTimingOverride(
        offset: nextOffset,
        timeViewStart: timeViewBounds.start,
        timeViewEnd: timeViewBounds.end,
      );
    }
  }

  void _syncDuplicatedClipPreviews({required int movedDistance}) {
    final movingClipIds = _movingClipIds;
    final duplicatedClipBatch = _duplicatedClipBatch;
    if (movingClipIds == null || duplicatedClipBatch == null) {
      return;
    }

    final previewClips = viewModel.previewClips;
    final duplicatedClipsById = {
      for (final clip in duplicatedClipBatch.clips) clip.id: clip,
    };

    for (final clipId in movingClipIds) {
      final preview = previewClips.nonObservableInner[clipId];
      final duplicatedClip = duplicatedClipsById[clipId];
      if (preview == null || duplicatedClip == null) {
        previewClips.remove(clipId);
        continue;
      }

      final nextOffset = duplicatedClip.offset + movedDistance;
      if (preview.offset == nextOffset) {
        continue;
      }

      previewClips[clipId] = preview.copyWith(offset: nextOffset);
    }
  }

  void _clearMoveSession() {
    _movingClipIds = null;
    _duplicatedClipBatch = null;
    _minimumMoveDelta = 0;
    viewModel.clipTimingOverrides.clear();
    viewModel.previewClips.clear();
  }
}
