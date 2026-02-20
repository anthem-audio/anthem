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

class ArrangerCreateClipState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  /// Convenience getter to fetch the base state machine object.
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  /// The main input data for the state machine, which is the current
  /// interaction state (e.g. what pointers are down and where, which modifier
  /// keys are pressed).
  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ProjectModel get project => arrangerStateMachine.project;
  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;
  ArrangerController get controller => arrangerStateMachine.controller;

  String? _targetTrackId;

  @override
  void onEntry({required event, required from}) {
    _resolveTargetTrackId();
    _handleMove();
  }

  @override
  void onExit({required event, required to}) {
    _targetTrackId = null;
    viewModel.clipCreateHint = null;
  }

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Cancel clip creation',
      from: ArrangerCreateClipState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Delegate drag to clip creation',
      from: ArrangerDragState,
      to: ArrangerCreateClipState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).shouldDelegateToCreateClip,
    ),
    .new(
      name: 'Clip creation fallback to drag',
      from: ArrangerCreateClipState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerCreateClipState)
              .parentState
              .shouldDelegateToCreateClip,
    ),
  ];

  ArrangerCreateClipState(super.parentState);

  @override
  void onActive({required event}) {
    if (event is EditorStateMachineSignalEvent) {
      final signal = event.signal;
      if (signal is _ArrangerPointerSignal) {
        switch (signal) {
          case _ArrangerPointerDownSignal():
            break;
          case _ArrangerPointerMoveSignal():
            _handleMove();
            break;
          case _ArrangerPointerUpSignal():
            _handleUp();
            break;
        }
      }
    }
  }

  void _resolveTargetTrackId() {
    final start = parentState.dragStartPosition;
    if (start == null) {
      _targetTrackId = null;
      return;
    }

    final fractionalTrackIndex = viewModel.trackPositionCalculator
        .getTrackIndexFromPosition(start.y);
    if (fractionalTrackIndex.isInfinite) {
      _targetTrackId = null;
      return;
    }

    _targetTrackId = viewModel.trackPositionCalculator.trackIndexToId(
      fractionalTrackIndex.floor(),
    );
  }

  void _handleMove() {
    final trackId = _targetTrackId;
    final startPosition = parentState.dragStartPosition;
    final currentPosition = parentState.dragCurrentPosition;

    if (trackId == null || startPosition == null || currentPosition == null) {
      viewModel.clipCreateHint = null;
      return;
    }

    final startOffsetRaw = pixelsToTime(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: startPosition.x,
    );
    final endOffsetRaw = max(
      0.0,
      pixelsToTime(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        viewPixelWidth: interactionState.viewSize.width,
        pixelOffsetFromLeft: currentPosition.x,
      ),
    );

    final divisionChanges = arrangerStateMachine.divisionChanges();
    final startOffset = interactionState.isAltPressed
        ? startOffsetRaw
        : getSnappedTime(
            rawTime: startOffsetRaw.round(),
            divisionChanges: divisionChanges,
            round: true,
          ).toDouble();
    final endOffset = interactionState.isAltPressed
        ? endOffsetRaw
        : getSnappedTime(
            rawTime: endOffsetRaw.round(),
            divisionChanges: divisionChanges,
            round: true,
          ).toDouble();

    final track = project.tracks[trackId];
    if (track == null) {
      viewModel.clipCreateHint = null;
      return;
    }

    viewModel.clipCreateHint = (
      trackId: trackId,
      startOffset: startOffset,
      endOffset: endOffset,
      color: track.color.colorShifter.clipBase.toColor().withValues(alpha: 0.5),
    );

    // Clear the cursor once we have a real clip create hint
    if ((endOffset - startOffset).abs() > 0) {
      viewModel.hoverIndicatorPosition = null;
    }
  }

  void _handleUp() {
    if (viewModel.clipCreateHint == null) return;

    final clipCreateHint = viewModel.clipCreateHint!;

    final start = min(clipCreateHint.startOffset, clipCreateHint.endOffset);
    final end = max(clipCreateHint.startOffset, clipCreateHint.endOffset);

    if (end - start == 0) {
      return;
    }

    controller.createClip(
      trackId: clipCreateHint.trackId,
      offset: start,
      width: end - start,
    );
  }
}
