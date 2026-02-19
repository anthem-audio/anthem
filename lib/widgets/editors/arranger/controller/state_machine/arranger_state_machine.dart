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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

enum ArrangerModifierKey { ctrl, alt, shift }

enum ArrangerCancelTrigger { escapeKey }

sealed class _ArrangerPointerSignal {
  final PointerEvent event;

  const _ArrangerPointerSignal(this.event);
}

class _ArrangerPointerDownSignal extends _ArrangerPointerSignal {
  const _ArrangerPointerDownSignal(super.event);
}

class _ArrangerPointerMoveSignal extends _ArrangerPointerSignal {
  const _ArrangerPointerMoveSignal(super.event);
}

class _ArrangerPointerUpSignal extends _ArrangerPointerSignal {
  const _ArrangerPointerUpSignal(super.event);
}

class _ArrangerViewTransformChangedSignal {
  const _ArrangerViewTransformChangedSignal();
}

class _ArrangerTrackLayoutChangedSignal {
  const _ArrangerTrackLayoutChangedSignal();
}

class _ArrangerCancelSignal {
  final ArrangerCancelTrigger trigger;

  const _ArrangerCancelSignal(this.trigger);
}

bool isArrangerCancelSignal(EditorStateMachineEvent event) {
  return event is EditorStateMachineSignalEvent &&
      event.signal is _ArrangerCancelSignal;
}

/// A state machine to manage user interactions in the arranger.
///
/// This is the primary state machine for the arranger. It converts incoming
/// pointer and key events into useful actions.
///
/// Individual states contain most of the logic. The idle state is the base
/// "nothing is currently happening" state, and everything branches from there.
class ArrangerStateMachine
    extends EditorStateMachine<ArrangerStateMachineData> {
  ProjectModel project;
  ArrangerViewModel viewModel;
  ArrangerController controller;

  void onPointerDown(PointerEvent event) {
    data.handlePointerDown(event);
    emitSignal(_ArrangerPointerDownSignal(event));
    notifyDataUpdated();
  }

  void onPointerMove(PointerEvent event) {
    data.handlePointerMove(event);
    emitSignal(_ArrangerPointerMoveSignal(event));
    notifyDataUpdated();
  }

  void onPointerUp(PointerEvent event) {
    final activePrimaryPointerId = data.activePrimaryPointerId;

    data.handlePointerUp(event);
    emitSignal(_ArrangerPointerUpSignal(event));
    notifyDataUpdated();

    if (activePrimaryPointerId == event.pointer) {
      data.clearInteractionCancellation();
    }
  }

  void onEnter(PointerEnterEvent event) {
    data.handleEnter(event);
    notifyDataUpdated();
  }

  void onExit(PointerExitEvent event) {
    data.handleExit(event);
    notifyDataUpdated();
  }

  void onHover(PointerHoverEvent event) {
    data.handleHover(event);
    notifyDataUpdated();
  }

  void onViewSizeChanged(Size viewSize) {
    data.viewSize = viewSize;
    notifyDataUpdated();
  }

  void modifierPressed(ArrangerModifierKey modifier) {
    if (data.isModifierPressed(modifier)) {
      return;
    }

    data.setModifier(modifier, true);
    notifyDataUpdated();
  }

  void modifierReleased(ArrangerModifierKey modifier) {
    if (!data.isModifierPressed(modifier)) {
      return;
    }

    data.setModifier(modifier, false);
    notifyDataUpdated();
  }

  void onRenderedViewTransformChanged({
    required double timeViewStart,
    required double timeViewEnd,
    required double verticalScrollPosition,
  }) {
    if (data.renderedTimeViewStart == timeViewStart &&
        data.renderedTimeViewEnd == timeViewEnd &&
        data.renderedVerticalScrollPosition == verticalScrollPosition) {
      return;
    }

    data.renderedTimeViewStart = timeViewStart;
    data.renderedTimeViewEnd = timeViewEnd;
    data.renderedVerticalScrollPosition = verticalScrollPosition;

    emitSignal(const _ArrangerViewTransformChangedSignal());
    notifyDataUpdated();
  }

  void onTrackLayoutChanged() {
    emitSignal(const _ArrangerTrackLayoutChangedSignal());
  }

  void cancelInteraction({required ArrangerCancelTrigger trigger}) {
    data.requestInteractionCancellation();
    emitSignal(_ArrangerCancelSignal(trigger));
  }

  List<DivisionChange> divisionChanges() {
    return getDivisionChanges(
      viewWidthInPixels: data.viewSize.width,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: [],
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: data.renderedTimeViewStart,
      timeViewEnd: data.renderedTimeViewEnd,
    );
  }

  ArrangerStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
    required this.controller,
  });

  factory ArrangerStateMachine.create({
    required ProjectModel project,
    required ArrangerViewModel viewModel,
    required ArrangerController controller,
  }) {
    final data = ArrangerStateMachineData()
      ..renderedTimeViewStart = viewModel.timeView.start
      ..renderedTimeViewEnd = viewModel.timeView.end
      ..renderedVerticalScrollPosition = viewModel.verticalScrollPosition;
    final idleState = ArrangerIdleState();
    final dragState = ArrangerDragState(idleState);
    final createClipState = ArrangerCreateClipState(dragState);
    final clipMoveState = ArrangerClipMoveState(dragState);
    final selectionBoxState = ArrangerSelectionBoxState(dragState);
    final states = [
      idleState,
      dragState,
      createClipState,
      clipMoveState,
      selectionBoxState,
    ];

    return ArrangerStateMachine._(
      data: data,
      idleState: idleState,
      states: states,
      project: project,
      viewModel: viewModel,
      controller: controller,
    );
  }
}

class ActivePointer {
  double x;
  double y;

  ActivePointer(this.x, this.y);

  ActivePointer clone() => ActivePointer(x, y);

  @override
  operator ==(Object other) =>
      other is ActivePointer && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class ArrangerStateMachineData {
  bool isCtrlPressed = false;
  bool isAltPressed = false;
  bool isShiftPressed = false;

  Size viewSize = Size.zero;

  Map<int, ActivePointer> pointers = {};
  ActivePointer? hoveredPointer;
  int? activePrimaryPointerId;
  ActivePointer? activePrimaryPointerDownPosition;

  double renderedTimeViewStart = 0;
  double renderedTimeViewEnd = 0;
  double renderedVerticalScrollPosition = 0;
  bool isCurrentInteractionCanceled = false;

  ActivePointer? get activePrimaryPointer {
    final pointerId = activePrimaryPointerId;
    if (pointerId == null) {
      return null;
    }

    return pointers[pointerId];
  }

  bool isModifierPressed(ArrangerModifierKey modifier) {
    return switch (modifier) {
      ArrangerModifierKey.ctrl => isCtrlPressed,
      ArrangerModifierKey.alt => isAltPressed,
      ArrangerModifierKey.shift => isShiftPressed,
    };
  }

  void setModifier(ArrangerModifierKey modifier, bool isPressed) {
    switch (modifier) {
      case ArrangerModifierKey.ctrl:
        isCtrlPressed = isPressed;
      case ArrangerModifierKey.alt:
        isAltPressed = isPressed;
      case ArrangerModifierKey.shift:
        isShiftPressed = isPressed;
    }
  }

  void handlePointerDown(PointerEvent pointerEvent) {
    final pos = pointerEvent.localPosition;
    pointers[pointerEvent.pointer] = .new(pos.dx, pos.dy);

    if (pointerEvent is PointerDownEvent &&
        pointerEvent.buttons & kPrimaryMouseButton == kPrimaryMouseButton) {
      activePrimaryPointerId = pointerEvent.pointer;
      activePrimaryPointerDownPosition = ActivePointer(pos.dx, pos.dy);
      clearInteractionCancellation();
    }
  }

  void handlePointerMove(PointerEvent event) {
    final pointer = pointers[event.pointer];
    if (pointer == null) return;

    final pos = event.localPosition;
    pointer.x = pos.dx;
    pointer.y = pos.dy;
  }

  void handlePointerUp(PointerEvent event) {
    if (event is! PointerCancelEvent) {
      final pos = event.localPosition;
      final isInView =
          pos.dx >= 0 &&
          pos.dy >= 0 &&
          pos.dx <= viewSize.width &&
          pos.dy <= viewSize.height;
      if (isInView) {
        hoveredPointer ??= ActivePointer(pos.dx, pos.dy);
        hoveredPointer!.x = pos.dx;
        hoveredPointer!.y = pos.dy;
      }
    }

    final pointerId = event.pointer;
    pointers.remove(pointerId);

    if (activePrimaryPointerId == pointerId) {
      activePrimaryPointerId = null;
      activePrimaryPointerDownPosition = null;
    }
  }

  void handleEnter(PointerEnterEvent e) {}

  void handleExit(PointerExitEvent e) {
    hoveredPointer = null;
  }

  void handleHover(PointerHoverEvent e) {
    hoveredPointer ??= .new(e.localPosition.dx, e.localPosition.dy);
    hoveredPointer!.x = e.localPosition.dx;
    hoveredPointer!.y = e.localPosition.dy;
  }

  void requestInteractionCancellation() {
    isCurrentInteractionCanceled = true;
  }

  void clearInteractionCancellation() {
    isCurrentInteractionCanceled = false;
  }
}

class ArrangerIdleState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  static const Duration _doubleClickThreshold = Duration(milliseconds: 500);
  static const double _maxClickTravelDistance = 8;
  static const double _maxDoubleClickDistance = 8;

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

  ActivePointer? lastHoveredPointer;

  int? _activePrimaryPointerId;
  Offset? _activePrimaryPointerDownPosition;

  DateTime? _lastPrimaryClickTimestamp;
  Offset? _lastPrimaryClickPosition;

  bool doubleClickPressed = false;

  /// Updates the current mouse hover position with a new one from
  /// [interactionState].
  void updateHover() {
    lastHoveredPointer = interactionState.hoveredPointer?.clone();

    final coordinates = lastHoveredPointer == null
        ? null
        : (lastHoveredPointer!.x, lastHoveredPointer!.y);
    updateArrangerCursor(coordinates);
    updateSystemMouseCursor(coordinates);
  }

  void updateArrangerCursor((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.cursorLocation = null;
      return;
    }

    final (x, y) = coordinates;
    final contentUnderCursor = viewModel.getContentUnderCursor(Offset(x, y));
    if (contentUnderCursor.clip != null ||
        contentUnderCursor.resizeHandle != null) {
      viewModel.cursorLocation = null;
      return;
    }

    final adjustedY =
        y +
        interactionState.renderedVerticalScrollPosition -
        viewModel.verticalScrollPosition;

    final fractionalTrackIndex = viewModel.trackPositionCalculator
        .getTrackIndexFromPosition(adjustedY);

    if (fractionalTrackIndex.isInfinite) {
      viewModel.cursorLocation = null;
      return;
    }

    final trackId = viewModel.trackPositionCalculator.trackIndexToId(
      fractionalTrackIndex.floor(),
    );

    final offset = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: x,
    );

    final targetTime = interactionState.isAltPressed
        ? offset
        : getSnappedTime(
            rawTime: offset.round(),
            divisionChanges: arrangerStateMachine.divisionChanges(),
            round: true,
          );

    viewModel.cursorLocation = (targetTime.toDouble(), trackId);
  }

  void updateSystemMouseCursor((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.canvasCursor = MouseCursor.defer;
      return;
    }

    final (x, y) = coordinates;
    final contentUnderCursor = viewModel.getContentUnderCursor(Offset(x, y));
    final newCursor = contentUnderCursor.resizeHandle != null
        ? SystemMouseCursors.resizeLeftRight
        : contentUnderCursor.clip != null
        ? SystemMouseCursors.move
        : MouseCursor.defer;

    if (viewModel.canvasCursor != newCursor) {
      viewModel.canvasCursor = newCursor;
    }
  }

  void _clearActivePrimaryPointerTracking() {
    _activePrimaryPointerId = null;
    _activePrimaryPointerDownPosition = null;
  }

  void _handlePointerDownSignal(_ArrangerPointerDownSignal signal) {
    final pointerEvent = signal.event;
    if (pointerEvent is! PointerDownEvent) {
      return;
    }

    final isPrimaryClick =
        pointerEvent.buttons & kPrimaryMouseButton == kPrimaryMouseButton;
    if (!isPrimaryClick) {
      return;
    }

    final clickTimestamp = DateTime.now();
    final lastClickTimestamp = _lastPrimaryClickTimestamp;

    final clickPosition = pointerEvent.localPosition;
    final lastClickPosition = _lastPrimaryClickPosition;

    final isDoubleClick =
        lastClickTimestamp != null &&
        clickTimestamp.difference(lastClickTimestamp) <=
            _doubleClickThreshold &&
        lastClickPosition != null &&
        (clickPosition - lastClickPosition).distance <= _maxDoubleClickDistance;

    if (isDoubleClick) {
      doubleClickPressed = true;
    }

    _activePrimaryPointerId = pointerEvent.pointer;
    _activePrimaryPointerDownPosition = pointerEvent.localPosition;
  }

  void _handlePointerUpSignal(_ArrangerPointerUpSignal signal) {
    final wasDoubleClickPressed = doubleClickPressed;

    final pointerEvent = signal.event;
    if (pointerEvent is PointerCancelEvent) {
      doubleClickPressed = false;
      _clearActivePrimaryPointerTracking();
      return;
    }

    if (pointerEvent is! PointerUpEvent) {
      return;
    }

    final activePointerId = _activePrimaryPointerId;
    final pointerDownPosition = _activePrimaryPointerDownPosition;
    if (activePointerId == null || pointerDownPosition == null) {
      return;
    }

    if (activePointerId != pointerEvent.pointer) {
      return;
    }

    doubleClickPressed = false;

    final clickPosition = pointerEvent.localPosition;
    final clickTravelDistance = (clickPosition - pointerDownPosition).distance;
    _clearActivePrimaryPointerTracking();

    if (clickTravelDistance > _maxClickTravelDistance) {
      return;
    }

    final clickTimestamp = DateTime.now();

    if (wasDoubleClickPressed) {
      _lastPrimaryClickTimestamp = null;
      _lastPrimaryClickPosition = null;
      handleDoubleClick(pointerEvent);
      return;
    }

    _lastPrimaryClickTimestamp = clickTimestamp;
    _lastPrimaryClickPosition = clickPosition;
    handleSingleClick(pointerEvent);
  }

  void handleSingleClick(PointerEvent event) {
    final contentUnderCursor = viewModel.getContentUnderCursor(
      event.localPosition,
    );
    final clipId = contentUnderCursor.clip?.metadata;

    if (contentUnderCursor.clip != null &&
        viewModel.selectedClips.contains(clipId)) {
      return;
    }

    viewModel.selectedClips.clear();
  }

  void handleDoubleClick(PointerEvent event) {}

  @override
  void onActive({required EditorStateMachineEvent event}) {
    var shouldUpdateHover =
        lastHoveredPointer != interactionState.hoveredPointer;

    if (event is EditorStateMachineSignalEvent) {
      final signal = event.signal;
      if (signal is _ArrangerViewTransformChangedSignal) {
        shouldUpdateHover = true;
      }
      if (signal is _ArrangerTrackLayoutChangedSignal) {
        shouldUpdateHover = true;
      }
      if (signal is _ArrangerPointerDownSignal) {
        _handlePointerDownSignal(signal);
      }
      if (signal is _ArrangerPointerUpSignal) {
        _handlePointerUpSignal(signal);
        if (signal.event is! PointerCancelEvent) {
          shouldUpdateHover = true;
        }
      }
    }

    if (shouldUpdateHover) {
      updateHover();
    }
  }
}

class ArrangerDragState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  static const double _dragActivationDistance = 4;

  /// Convenience getter to fetch the base state machine object.
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  /// The main input data for the state machine, which is the current
  /// interaction state (e.g. what pointers are down and where, which modifier
  /// keys are pressed).
  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;
  ArrangerController get controller => arrangerStateMachine.controller;

  @override
  ArrangerIdleState get parentState => super.parentState as ArrangerIdleState;

  int? activePointerId;
  ActivePointer? dragStartPosition;
  ActivePointer? dragCurrentPosition;
  ArrangerContentUnderCursor? dragStartContentUnderCursor;
  bool hasCrossedActivationDistance = false;

  bool get isDragPointerActive =>
      interactionState.activePrimaryPointerId != null;

  bool get _isDragStartOverResizeHandle =>
      dragStartContentUnderCursor?.resizeHandle != null;

  bool get _isDragStartOverClip => dragStartContentUnderCursor?.clip != null;

  Id? get dragStartClipId => dragStartContentUnderCursor?.clip?.metadata;

  bool get shouldDelegateToSelectionBox =>
      isDragPointerActive &&
      hasCrossedActivationDistance &&
      !interactionState.isCurrentInteractionCanceled &&
      (interactionState.isCtrlPressed || viewModel.tool == EditorTool.select);

  bool get shouldDelegateToCreateClip =>
      isDragPointerActive &&
      parentState.doubleClickPressed &&
      hasCrossedActivationDistance &&
      !interactionState.isCurrentInteractionCanceled &&
      !shouldDelegateToSelectionBox &&
      !_isDragStartOverClip &&
      !_isDragStartOverResizeHandle &&
      viewModel.tool == EditorTool.pencil;

  bool get shouldDelegateToClipMove =>
      isDragPointerActive &&
      hasCrossedActivationDistance &&
      !interactionState.isCurrentInteractionCanceled &&
      !shouldDelegateToSelectionBox &&
      !shouldDelegateToCreateClip &&
      !_isDragStartOverResizeHandle &&
      _isDragStartOverClip;

  bool get _isSelectionModeActive =>
      interactionState.isCtrlPressed || viewModel.tool == EditorTool.select;

  bool get _isClipPressEligible =>
      isDragPointerActive &&
      !interactionState.isCurrentInteractionCanceled &&
      !_isSelectionModeActive &&
      !_isDragStartOverResizeHandle &&
      _isDragStartOverClip;

  Id? get _pressedClipCandidateId =>
      dragStartContentUnderCursor?.clip?.metadata;

  void _syncPressedClip() {
    final nextPressedClip = _isClipPressEligible
        ? _pressedClipCandidateId
        : null;
    if (viewModel.pressedClip != nextPressedClip) {
      viewModel.pressedClip = nextPressedClip;
    }
  }

  void _syncDragParameters() {
    final nextActivePointerId = interactionState.activePrimaryPointerId;

    if (nextActivePointerId == null) {
      activePointerId = null;
      dragStartPosition = null;
      dragCurrentPosition = null;
      dragStartContentUnderCursor = null;
      hasCrossedActivationDistance = false;
      _syncPressedClip();
      return;
    }

    // This means a new pointer has been pressed. Since we're only dealing with
    // one pointer for now, we treat this as the main pointer press signal, and
    // we store parameters for a drag in case the pointer moves.
    if (activePointerId != nextActivePointerId) {
      activePointerId = nextActivePointerId;
      dragStartPosition = interactionState.activePrimaryPointerDownPosition
          ?.clone();
      dragCurrentPosition = interactionState.activePrimaryPointer?.clone();
      final start = dragStartPosition;
      dragStartContentUnderCursor = start == null
          ? null
          : viewModel.getContentUnderCursor(Offset(start.x, start.y));
      hasCrossedActivationDistance = false;
    }

    dragCurrentPosition = interactionState.activePrimaryPointer?.clone();

    final start = dragStartPosition;
    final current = dragCurrentPosition;
    if (start == null || current == null) {
      _syncPressedClip();
      return;
    }

    final deltaX = current.x - start.x;
    final deltaY = current.y - start.y;
    final distanceSquared = deltaX * deltaX + deltaY * deltaY;

    // The drag activation distance is the amount the pointer needs to move
    // before we transition into the applicable action state, whatever that is.
    // For example, if the user clicks and drags while over a clip, we move that
    // clip.
    if (!hasCrossedActivationDistance) {
      hasCrossedActivationDistance =
          distanceSquared >= _dragActivationDistance * _dragActivationDistance;
    }

    _syncPressedClip();
  }

  @override
  void onEntry({required event, required from}) {
    _syncDragParameters();
  }

  @override
  void onActive({required event}) {
    _syncDragParameters();
  }

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Enter drag state',
      from: ArrangerIdleState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          interactionState.activePrimaryPointerId != null,
    ),
    .new(
      name: 'Exit drag state',
      from: ArrangerDragState,
      to: ArrangerIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          interactionState.activePrimaryPointerId == null,
    ),
  ];

  ArrangerDragState(ArrangerIdleState super.parentState);
}

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
      viewModel.cursorLocation = null;
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

    var movedDistance = (currentTime - startTime).round();

    if (!interactionState.isAltPressed) {
      movedDistance = getSnappedTime(
        rawTime: movedDistance,
        divisionChanges: arrangerStateMachine.divisionChanges(),
        round: true,
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

class ArrangerSelectionBoxState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;

  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  Set<Id>? _originalSelectedClipsAtEntry;
  bool _isSubtractiveSelectionLatched = false;

  @visibleForTesting
  Set<Id>? get originalSelectedClipsAtEntry => _originalSelectedClipsAtEntry;

  @visibleForTesting
  bool get isSubtractiveSelectionLatched => _isSubtractiveSelectionLatched;

  Rectangle<double>? _getSelectionBoxRect() {
    final startPosition = parentState.dragStartPosition;
    final currentPosition = parentState.dragCurrentPosition;
    if (startPosition == null || currentPosition == null) {
      return null;
    }

    return Rectangle.fromPoints(
      Point(startPosition.x, startPosition.y),
      Point(currentPosition.x, currentPosition.y),
    );
  }

  void _syncSelectionBox() {
    viewModel.selectionBox = _getSelectionBoxRect();
  }

  Id? _getClipAtDragStart() {
    final startPosition = parentState.dragStartPosition;
    if (startPosition == null) {
      return null;
    }

    final contentUnderCursor = viewModel.getContentUnderCursor(
      Offset(startPosition.x, startPosition.y),
    );

    return contentUnderCursor.clip?.metadata ??
        contentUnderCursor.resizeHandle?.metadata.id;
  }

  void _initializeSelectionSession() {
    if (!interactionState.isShiftPressed) {
      viewModel.selectedClips.clear();
      _originalSelectedClipsAtEntry = Set<Id>.unmodifiable(const <Id>{});
      _isSubtractiveSelectionLatched = false;
      return;
    }

    _originalSelectedClipsAtEntry = Set<Id>.unmodifiable(
      viewModel.selectedClips.nonObservableInner,
    );

    final clipAtDragStart = _getClipAtDragStart();
    _isSubtractiveSelectionLatched =
        clipAtDragStart != null &&
        _originalSelectedClipsAtEntry!.contains(clipAtDragStart);
  }

  void _clearSelectionSession() {
    _originalSelectedClipsAtEntry = null;
    _isSubtractiveSelectionLatched = false;
  }

  Set<Id> _getClipsInSelectionBox({required Rectangle<double> selectionBox}) {
    if (selectionBox.width <= 0 || selectionBox.height <= 0) {
      return {};
    }

    final selectionRect = Rect.fromLTWH(
      selectionBox.left,
      selectionBox.top,
      selectionBox.width,
      selectionBox.height,
    );

    final clipsInSelection = <Id>{};
    for (final annotation in viewModel.visibleClips.getAnnotations()) {
      if (selectionRect.overlaps(annotation.rect)) {
        clipsInSelection.add(annotation.metadata);
      }
    }

    return clipsInSelection;
  }

  void _syncSelectedClips() {
    final originalSelectedClips = _originalSelectedClipsAtEntry;
    final selectionBox = viewModel.selectionBox;
    if (originalSelectedClips == null || selectionBox == null) {
      return;
    }

    final clipsInSelection = _getClipsInSelectionBox(
      selectionBox: selectionBox,
    );
    final nextSelection = _isSubtractiveSelectionLatched
        ? originalSelectedClips.difference(clipsInSelection)
        : originalSelectedClips.union(clipsInSelection);

    viewModel.selectedClips
      ..clear()
      ..addAll(nextSelection);
  }

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to selection box',
      from: ArrangerDragState,
      to: ArrangerSelectionBoxState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).shouldDelegateToSelectionBox,
    ),
    .new(
      name: 'Cancel selection box',
      from: ArrangerSelectionBoxState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Selection box fallback to drag',
      from: ArrangerSelectionBoxState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerSelectionBoxState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerSelectionBoxState(super.parentState);

  @override
  void onEntry({required event, required from}) {
    viewModel.cursorLocation = null;
    _initializeSelectionSession();
    _syncSelectionBox();
    _syncSelectedClips();
  }

  @override
  void onActive({required event}) {
    _syncSelectionBox();
    _syncSelectedClips();
  }

  @override
  void onExit({required event, required to}) {
    final originalSelectedClips = _originalSelectedClipsAtEntry;
    if (isArrangerCancelSignal(event) && originalSelectedClips != null) {
      viewModel.selectedClips
        ..clear()
        ..addAll(originalSelectedClips);
    }

    viewModel.selectionBox = null;
    _clearSelectionSession();
  }
}
