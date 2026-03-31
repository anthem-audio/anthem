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
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/basic/menu/context_menu_api.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

part 'create_clip_state.dart';
part 'clip_move_state.dart';
part 'clip_resize_state.dart';
part 'selection_box_state.dart';
part 'snap_delta.dart';

enum ArrangerModifierKey { ctrl, alt, shift }

enum ArrangerCancelTrigger { escapeKey }

enum ArrangerInteractionFamily {
  selectionBox,
  createClip,
  clipResize,
  clipMove,
}

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

  List<TimeSignatureChangeModel> arrangementTimeSignatureChanges() {
    return project
            .sequence
            .arrangements[project.sequence.activeArrangementID]
            ?.timeSignatureChanges ??
        const <TimeSignatureChangeModel>[];
  }

  TimeSignatureModel timeSignatureAt(Time time) {
    var timeSignature = project.sequence.defaultTimeSignature;

    for (final change in arrangementTimeSignatureChanges()) {
      if (change.offset > time) {
        break;
      }
      timeSignature = change.timeSignature;
    }

    return timeSignature;
  }

  List<DivisionChange> divisionChanges() {
    return getDivisionChanges(
      viewWidthInPixels: data.viewSize.width,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: arrangementTimeSignatureChanges(),
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
    final clipResizeState = ArrangerClipResizeState(dragState);
    final selectionBoxState = ArrangerSelectionBoxState(dragState);
    final states = [
      idleState,
      dragState,
      createClipState,
      clipMoveState,
      clipResizeState,
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
  static void Function(Offset globalPosition, MenuDef menu) openContextMenuFn =
      openContextMenu;

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
    updateHoveredClip(coordinates);
    updateArrangerCursor(coordinates);
    updateSystemMouseCursor(coordinates);
  }

  void updateHoveredClip((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.hoveredClip = null;
      return;
    }

    final (x, y) = coordinates;
    final contentUnderCursor = viewModel.getContentUnderCursor(Offset(x, y));
    final hoveredClipId =
        contentUnderCursor.resizeHandle?.metadata.id ??
        contentUnderCursor.clip?.metadata;
    if (viewModel.hoveredClip != hoveredClipId) {
      viewModel.hoveredClip = hoveredClipId;
    }
  }

  void updateArrangerCursor((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    final (x, y) = coordinates;
    final contentUnderCursor = viewModel.getContentUnderCursor(Offset(x, y));
    if (contentUnderCursor.clip != null ||
        contentUnderCursor.resizeHandle != null) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    final adjustedY =
        y +
        interactionState.renderedVerticalScrollPosition -
        viewModel.verticalScrollPosition;

    final fractionalTrackIndex = viewModel.trackPositionCalculator
        .getTrackIndexFromPosition(adjustedY);

    if (fractionalTrackIndex.isInfinite) {
      viewModel.hoverIndicatorPosition = null;
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

    viewModel.hoverIndicatorPosition = (targetTime.toDouble(), trackId);
  }

  void updateSystemMouseCursor((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.mouseCursor = MouseCursor.defer;
      return;
    }

    final (x, y) = coordinates;
    final contentUnderCursor = viewModel.getContentUnderCursor(Offset(x, y));
    final newCursor = contentUnderCursor.resizeHandle != null
        ? SystemMouseCursors.resizeLeftRight
        : MouseCursor.defer;

    if (viewModel.mouseCursor != newCursor) {
      viewModel.mouseCursor = newCursor;
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

    final isSecondaryClick =
        pointerEvent.buttons & kSecondaryMouseButton == kSecondaryMouseButton;
    if (isSecondaryClick) {
      handleSecondaryClick(pointerEvent);
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
    final clipId =
        contentUnderCursor.clip?.metadata ??
        contentUnderCursor.resizeHandle?.metadata.id;

    if (clipId == null) {
      viewModel.selectedClips.clear();
      return;
    }

    if (interactionState.isCtrlPressed) {
      if (viewModel.selectedClips.contains(clipId)) {
        viewModel.selectedClips.remove(clipId);
      } else {
        viewModel.selectedClips.add(clipId);
      }
      return;
    }

    if (viewModel.selectedClips.contains(clipId)) {
      return;
    }

    viewModel.selectedClips
      ..clear()
      ..add(clipId);
  }

  void handleSecondaryClick(PointerEvent event) {
    final contentUnderCursor = viewModel.getContentUnderCursor(
      event.localPosition,
    );
    final clipId =
        contentUnderCursor.clip?.metadata ??
        contentUnderCursor.resizeHandle?.metadata.id;
    if (clipId == null) {
      return;
    }

    if (!viewModel.selectedClips.contains(clipId)) {
      viewModel.selectedClips
        ..clear()
        ..add(clipId);
    }

    openContextMenuFn(
      event.position,
      MenuDef(
        children: [
          AnthemMenuItem(
            text: 'Delete',
            hint: 'Delete selected clips',
            onSelected: controller.deleteSelectedClips,
            shortcutLabel: 'Del',
          ),
        ],
      ),
    );
  }

  void handleDoubleClick(PointerEvent event) {
    final contentUnderCursor = viewModel.getContentUnderCursor(
      event.localPosition,
    );
    final clipId =
        contentUnderCursor.clip?.metadata ??
        contentUnderCursor.resizeHandle?.metadata.id;
    if (clipId == null) {
      return;
    }

    controller.openClipInPianoRoll(clipId);
  }

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

  ({Id id, ResizeAreaType type})? get dragStartResizeHandle =>
      dragStartContentUnderCursor?.resizeHandle?.metadata;

  bool get _isDragStartOverClip => dragStartContentUnderCursor?.clip != null;

  Id? get dragStartClipId => dragStartContentUnderCursor?.clip?.metadata;

  Id? get dragStartResizeHandleClipId => dragStartResizeHandle?.id;

  ResizeAreaType? get dragStartResizeAreaType => dragStartResizeHandle?.type;

  bool get _isSelectionModeActive =>
      interactionState.isCtrlPressed || viewModel.tool == EditorTool.select;

  /// Resolves the interaction family this drag should delegate to, if any.
  ///
  /// The result is intentionally not latched in shared state yet. We use it to
  /// centralize precedence while preserving the existing per-state latching
  /// behavior after entry.
  ArrangerInteractionFamily? get interactionFamily {
    if (!isDragPointerActive || interactionState.isCurrentInteractionCanceled) {
      return null;
    }

    if (hasCrossedActivationDistance && _isSelectionModeActive) {
      return ArrangerInteractionFamily.selectionBox;
    }

    if (parentState.doubleClickPressed &&
        !_isDragStartOverClip &&
        !_isDragStartOverResizeHandle &&
        viewModel.tool == EditorTool.pencil) {
      return ArrangerInteractionFamily.createClip;
    }

    if (hasCrossedActivationDistance && _isDragStartOverResizeHandle) {
      return ArrangerInteractionFamily.clipResize;
    }

    if (hasCrossedActivationDistance &&
        !_isDragStartOverResizeHandle &&
        _isDragStartOverClip) {
      return ArrangerInteractionFamily.clipMove;
    }

    return null;
  }

  bool get _isClipPressEligible =>
      isDragPointerActive &&
      !interactionState.isCurrentInteractionCanceled &&
      !_isSelectionModeActive &&
      (_isDragStartOverClip || _isDragStartOverResizeHandle);

  Id? get _pressedClipCandidateId =>
      dragStartContentUnderCursor?.clip?.metadata ?? dragStartResizeHandle?.id;

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
