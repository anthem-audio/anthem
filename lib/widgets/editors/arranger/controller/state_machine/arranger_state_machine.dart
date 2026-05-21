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
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/commands/pattern_automation_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/clip/clip_title_text.dart'
    show clipTitleHeight;
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/basic/menu/context_menu_api.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/shared/canvas_annotation_set.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

part 'create_clip_state.dart';
part 'automation_point_move_state.dart';
part 'clip_move_state.dart';
part 'clip_resize_state.dart';
part 'selection_box_state.dart';
part 'snap_delta.dart';

enum ArrangerModifierKey { ctrl, alt, shift }

enum ArrangerCancelTrigger { escapeKey }

enum ArrangerPointerButton { primary, secondary, other }

enum ArrangerInteractionFamily {
  selectionBox,
  createClip,
  automationPointMove,
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

  void onPointerDown(PointerDownEvent event) {
    data.handlePointerDown(event);
    final pointerContext = pointerContextAt(event.localPosition);
    if (data.activePointerId == event.pointer) {
      data.activePointerDownContext = pointerContext;
      data.activePointerContext = pointerContext;
    }

    _syncClipWithAutomationHandles();
    emitSignal(_ArrangerPointerDownSignal(event));
    notifyDataUpdated();
  }

  void onPointerMove(PointerEvent event) {
    data.handlePointerMove(event);
    if (data.activePointerId == event.pointer) {
      data.activePointerContext = pointerContextAt(event.localPosition);
    }

    _syncClipWithAutomationHandles();
    emitSignal(_ArrangerPointerMoveSignal(event));
    notifyDataUpdated();
  }

  void onPointerUp(PointerEvent event) {
    final activePointerId = data.activePointerId;
    final activePointerButton = data.activePointerButton;
    final pointerContext = pointerContextAt(event.localPosition);
    if (activePointerId == event.pointer) {
      data.activePointerContext = pointerContext;
    }

    data.handlePointerUp(event);
    _refreshHoverContext();
    _syncClipWithAutomationHandles();
    emitSignal(_ArrangerPointerUpSignal(event));
    notifyDataUpdated();

    if (activePointerId == event.pointer) {
      data.activePointerDownContext = null;
      data.activePointerContext = null;
      // Exiting states need to see cancellation until their onExit has run.
      if (activePointerButton == ArrangerPointerButton.primary) {
        data.clearInteractionCancellation();
      }
    }
  }

  void onEnter(PointerEnterEvent event) {
    data.handleEnter(event);
    notifyDataUpdated();
  }

  void onExit(PointerExitEvent event) {
    data.handleExit(event);
    _refreshHoverContext();
    _syncClipWithAutomationHandles();
    notifyDataUpdated();
  }

  void onHover(PointerHoverEvent event) {
    data.handleHover(event);
    _refreshHoverContext();
    _syncClipWithAutomationHandles();
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

    _refreshHoverContext();
    _refreshActivePointerContext();
    _syncClipWithAutomationHandles();
    emitSignal(const _ArrangerViewTransformChangedSignal());
    notifyDataUpdated();
  }

  void onTrackLayoutChanged() {
    _refreshHoverContext();
    _refreshActivePointerContext();
    _syncClipWithAutomationHandles();
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

  ArrangerPointerContext pointerContextAt(Offset position) {
    final hitTestResult = viewModel.hitTestContent(position);
    return ArrangerPointerContext(
      position: position,
      hitTestResult: hitTestResult,
      target: _pointerTargetForHitTestResult(hitTestResult),
    );
  }

  ArrangerPointerTarget _pointerTargetForHitTestResult(
    ArrangerHitTestResult hitTestResult,
  ) {
    final clipHit = hitTestResult.clip;
    final isAutomationClipBody = clipHit != null
        ? _isAutomationClipBodyHit(clipHit)
        : false;

    return ArrangerPointerTarget(
      clipHit: clipHit,
      isAutomationClipContent: isAutomationClipBody,
      resizeHandle: hitTestResult.resizeHandle,
      automationHandleAnnotation: hitTestResult.automationHandle,
    );
  }

  bool _isAutomationClipBodyHit(CanvasAnnotationHit<Id> clipHit) {
    final arrangementData = activeArrangementWithClips();
    final clip = arrangementData?.clips[clipHit.annotation.metadata];
    final isAutomationClip =
        clip != null && project.tracks[clip.trackId]?.isAutomationLane == true;

    return isAutomationClip &&
        clipHit.annotation.rect.height > clipTitleHeight &&
        clipHit.offset.dy >= clipTitleHeight;
  }

  void _refreshHoverContext() {
    final hoveredPointer = data.hoveredPointer;
    data.hoverContext = hoveredPointer == null
        ? null
        : pointerContextAt(Offset(hoveredPointer.x, hoveredPointer.y));
  }

  void _refreshActivePointerContext() {
    final activePointer = data.activePointer;
    data.activePointerContext = activePointer == null
        ? null
        : pointerContextAt(Offset(activePointer.x, activePointer.y));
  }

  void _syncClipWithAutomationHandles() {
    final pointerContext = data.activePointerId != null
        ? data.activePointerDownContext
        : data.hoverContext;
    final nextClipId = pointerContext?.automationClipContentClipId;

    if (viewModel.clipWithAutomationHandles != nextClipId) {
      viewModel.clipWithAutomationHandles = nextClipId;
    }
  }

  /// Resolves the currently active arrangement alongside its clips map.
  ///
  /// Returns `null` if there is no active arrangement (project has none
  /// selected, or the selected ID no longer resolves to a model). Callers
  /// should early-return in that case rather than crashing.
  ({ArrangementModel arrangement, Map<Id, ClipModel> clips})?
  activeArrangementWithClips() {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return null;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    if (arrangement == null) {
      return null;
    }

    return (
      arrangement: arrangement,
      clips: arrangement.clips.nonObservableInner,
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
    final automationPointMoveState = ArrangerAutomationPointMoveState(
      dragState,
    );
    final clipMoveState = ArrangerClipMoveState(dragState);
    final clipResizeState = ArrangerClipResizeState(dragState);
    final selectionBoxState = ArrangerSelectionBoxState(dragState);
    final states = [
      idleState,
      dragState,
      createClipState,
      automationPointMoveState,
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

typedef ArrangerResizeHandleAnnotation =
    CanvasAnnotation<({Id id, ResizeAreaType type})>;

Rect _automationClipContentRectForHit(CanvasAnnotationHit<Id> clipHit) {
  final clipRect = clipHit.annotation.rect;
  return Rect.fromLTRB(
    clipRect.left,
    clipRect.top + clipTitleHeight,
    clipRect.right,
    clipRect.bottom,
  );
}

class ArrangerPointerContext {
  final Offset position;
  final ArrangerHitTestResult hitTestResult;
  final ArrangerPointerTarget target;

  const ArrangerPointerContext({
    required this.position,
    required this.hitTestResult,
    required this.target,
  });

  Id? get hoveredClipId => target.hoveredClipId;
  Id? get selectableClipId => target.selectableClipId;
  Id? get movableClipId => target.movableClipId;
  Id? get automationClipContentClipId => target.automationClipContentClipId;
  Rect? get automationClipContentRect => target.automationClipContentRect;
  AutomationHandleAnnotation? get automationHandle => target.automationHandle;
  ArrangerResizeHandleAnnotation? get resizeHandleTarget =>
      target.resizeHandleTarget;
}

class ArrangerPointerTarget {
  final CanvasAnnotationHit<Id>? clipHit;
  final bool isAutomationClipContent;
  final ArrangerResizeHandleAnnotation? resizeHandle;
  final CanvasAnnotation<AutomationHandleAnnotation>?
  automationHandleAnnotation;

  const ArrangerPointerTarget({
    this.clipHit,
    this.isAutomationClipContent = false,
    this.resizeHandle,
    this.automationHandleAnnotation,
  });

  Id? get clipId => clipHit?.annotation.metadata;

  bool get isEmpty =>
      clipHit == null &&
      resizeHandle == null &&
      automationHandleAnnotation == null;

  AutomationHandleAnnotation? get automationHandle =>
      automationHandleAnnotation?.metadata;

  bool get isAutomationPointHandle =>
      automationHandle?.kind == AutomationHandleKind.point;

  bool get hasAutomationClipContent =>
      isAutomationClipContent || automationHandleAnnotation != null;

  Id? get hoveredClipId => clipId ?? resizeHandle?.metadata.id;

  Id? get selectableClipId {
    if (isAutomationPointHandle) {
      return null;
    }

    return clipId ?? resizeHandle?.metadata.id;
  }

  Id? get movableClipId {
    if (automationHandleAnnotation != null) {
      return null;
    }

    return selectableClipId;
  }

  Id? get automationClipContentClipId {
    if (!hasAutomationClipContent) {
      return null;
    }

    return clipId ?? automationHandle?.clipId;
  }

  Rect? get automationClipContentRect {
    final hit = clipHit;
    if (!hasAutomationClipContent || hit == null) {
      return null;
    }

    return _automationClipContentRectForHit(hit);
  }

  ArrangerResizeHandleAnnotation? get resizeHandleTarget {
    if (automationHandleAnnotation != null) {
      return null;
    }

    return resizeHandle;
  }

  bool get suppressesClipLevelActions => isAutomationPointHandle;
}

/// Shared base for the arranger's leaf (non-idle, non-drag-parent) states.
///
/// Every concrete leaf state needs access to the same five handles (the state
/// machine, its interaction data, the project, and the arranger's view model
/// and controller), plus a helper for converting a pixel drag into a snapped
/// tick delta.
abstract class _ArrangerLeafState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  _ArrangerLeafState([super.parentState]);

  /// The owning state machine, cast to its concrete type.
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  /// The state machine's input data: active pointers and their positions,
  /// modifier key state, the rendered time view, and cancellation flag.
  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ProjectModel get project => arrangerStateMachine.project;
  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;
  ArrangerController get controller => arrangerStateMachine.controller;

  /// Converts a pixel drag (start/current X in local coordinates) into tick
  /// times plus a drag delta.
  ///
  /// When [snapOverridden] is true (typically Alt held), the delta is the raw
  /// `currentTime - startTime`. Otherwise it snaps to the nearest grid
  /// division crossing along the drag path, using the arranger's current
  /// division changes.
  ({int startTime, int currentTime, int delta}) resolveSnappedDragDelta({
    required double startPx,
    required double currentPx,
    required bool snapOverridden,
  }) {
    final startTime = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: startPx,
    ).round();
    final currentTime = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: currentPx,
    ).round();
    final delta = snapOverridden
        ? currentTime - startTime
        : getSnappedDragDelta(
            startTime: startTime,
            currentTime: currentTime,
            divisionChanges: arrangerStateMachine.divisionChanges(),
          );

    return (startTime: startTime, currentTime: currentTime, delta: delta);
  }
}

/// An immutable snapshot of a pointer position in local arranger coordinates.
///
/// New instances are created whenever a pointer moves; callers never mutate
/// an existing one in place. Value equality (`==` / `hashCode`) lets us
/// cheaply compare "did this pointer actually move?" without reaching into
/// individual fields.
class ActivePointer {
  final double x;
  final double y;

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
  ArrangerPointerContext? hoverContext;
  int? activePointerId;
  ArrangerPointerButton? activePointerButton;
  ActivePointer? activePointerDownPosition;
  ArrangerPointerContext? activePointerDownContext;
  ArrangerPointerContext? activePointerContext;

  double renderedTimeViewStart = 0;
  double renderedTimeViewEnd = 0;
  double renderedVerticalScrollPosition = 0;
  bool isCurrentInteractionCanceled = false;

  ActivePointer? get activePointer {
    final pointerId = activePointerId;
    if (pointerId == null) {
      return null;
    }

    return pointers[pointerId];
  }

  bool get isPrimaryPointerActive =>
      activePointerId != null &&
      activePointerButton == ArrangerPointerButton.primary;

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

  void handlePointerDown(PointerDownEvent pointerEvent) {
    final pos = pointerEvent.localPosition;
    pointers[pointerEvent.pointer] = ActivePointer(pos.dx, pos.dy);

    final button = _pointerButtonForEvent(pointerEvent);
    if (activePointerId == null || button == ArrangerPointerButton.primary) {
      activePointerId = pointerEvent.pointer;
      activePointerButton = button;
      activePointerDownPosition = ActivePointer(pos.dx, pos.dy);
    }

    if (button == ArrangerPointerButton.primary) {
      clearInteractionCancellation();
    }
  }

  void handlePointerMove(PointerEvent event) {
    final pointer = pointers[event.pointer];
    if (pointer == null) return;

    final pos = event.localPosition;
    pointers[event.pointer] = ActivePointer(pos.dx, pos.dy);
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
        hoveredPointer = ActivePointer(pos.dx, pos.dy);
      }
    }

    final pointerId = event.pointer;
    pointers.remove(pointerId);

    if (activePointerId == pointerId) {
      activePointerId = null;
      activePointerButton = null;
      activePointerDownPosition = null;
    }
  }

  void handleEnter(PointerEnterEvent e) {}

  void handleExit(PointerExitEvent e) {
    hoveredPointer = null;
    hoverContext = null;
  }

  void handleHover(PointerHoverEvent e) {
    hoveredPointer = ActivePointer(e.localPosition.dx, e.localPosition.dy);
  }

  void requestInteractionCancellation() {
    isCurrentInteractionCanceled = true;
  }

  void clearInteractionCancellation() {
    isCurrentInteractionCanceled = false;
  }

  ArrangerPointerButton _pointerButtonForEvent(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton == kPrimaryMouseButton) {
      return ArrangerPointerButton.primary;
    }

    if (event.buttons & kSecondaryMouseButton == kSecondaryMouseButton) {
      return ArrangerPointerButton.secondary;
    }

    return ArrangerPointerButton.other;
  }
}

class ArrangerIdleState extends _ArrangerLeafState {
  static const Duration _doubleClickThreshold = Duration(milliseconds: 500);
  static const double _maxClickTravelDistance = 8;
  static const double _maxDoubleClickDistance = 8;
  static void Function(Offset globalPosition, MenuDef menu) openContextMenuFn =
      openContextMenu;

  ActivePointer? lastHoveredPointer;

  int? _primaryClickPointerId;
  Offset? _primaryClickDownPosition;

  DateTime? _lastPrimaryClickTimestamp;
  Offset? _lastPrimaryClickPosition;

  bool doubleClickPressed = false;

  /// Updates the current mouse hover position with a new one from
  /// [interactionState].
  void updateHover() {
    lastHoveredPointer = interactionState.hoveredPointer?.clone();

    updateHoveredClip();
    updateArrangerCursor();
    updateSystemMouseCursor();
  }

  void updateHoveredClip() {
    final hoverContext = interactionState.hoverContext;
    if (hoverContext == null) {
      viewModel.hoveredClip = null;
      return;
    }

    final hoveredClipId = hoverContext.hoveredClipId;
    if (viewModel.hoveredClip != hoveredClipId) {
      viewModel.hoveredClip = hoveredClipId;
    }
  }

  void updateArrangerCursor() {
    final hoverContext = interactionState.hoverContext;
    if (hoverContext == null) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    if (!hoverContext.target.isEmpty) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    final position = hoverContext.position;
    final adjustedY =
        position.dy +
        interactionState.renderedVerticalScrollPosition -
        viewModel.verticalScrollPosition;

    final rowHit = viewModel.trackPositionCalculator.rowAtPosition(adjustedY);
    if (rowHit == null) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    final rowId = _rowIdForCursor(rowHit.row);
    if (rowId == null) {
      viewModel.hoverIndicatorPosition = null;
      return;
    }

    final offset = pixelsToTime(
      timeViewStart: interactionState.renderedTimeViewStart,
      timeViewEnd: interactionState.renderedTimeViewEnd,
      viewPixelWidth: interactionState.viewSize.width,
      pixelOffsetFromLeft: position.dx,
    );

    final targetTime = interactionState.isAltPressed
        ? offset
        : getSnappedTime(
            rawTime: offset.round(),
            divisionChanges: arrangerStateMachine.divisionChanges(),
            round: true,
          );

    viewModel.hoverIndicatorPosition = (
      offset: targetTime.toDouble(),
      rowId: rowId,
    );
  }

  Id? _rowIdForCursor(ArrangerRow row) {
    return switch (row) {
      TrackArrangerRow(:final trackId) =>
        project.tracks.containsKey(trackId) ? trackId : null,
      PhantomAutomationArrangerRow() => row.rowId,
    };
  }

  void updateSystemMouseCursor() {
    final hoverContext = interactionState.hoverContext;
    if (hoverContext == null) {
      viewModel.mouseCursor = MouseCursor.defer;
      return;
    }

    final newCursor = hoverContext.resizeHandleTarget != null
        ? SystemMouseCursors.resizeLeftRight
        : MouseCursor.defer;

    if (viewModel.mouseCursor != newCursor) {
      viewModel.mouseCursor = newCursor;
    }
  }

  void _clearPrimaryClickTracking() {
    _primaryClickPointerId = null;
    _primaryClickDownPosition = null;
  }

  void _handlePointerDownSignal(_ArrangerPointerDownSignal signal) {
    final pointerEvent = signal.event;
    if (pointerEvent is! PointerDownEvent) {
      return;
    }

    final isSecondaryClick =
        pointerEvent.buttons & kSecondaryMouseButton == kSecondaryMouseButton;
    if (isSecondaryClick) {
      final pointerContext = interactionState.activePointerDownContext;
      if (interactionState.activePointerId == pointerEvent.pointer &&
          interactionState.activePointerButton ==
              ArrangerPointerButton.secondary &&
          pointerContext != null) {
        handleSecondaryClick(pointerEvent, pointerContext);
      }
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

    _primaryClickPointerId = pointerEvent.pointer;
    _primaryClickDownPosition = pointerEvent.localPosition;
  }

  void _handlePointerUpSignal(_ArrangerPointerUpSignal signal) {
    final wasDoubleClickPressed = doubleClickPressed;

    final pointerEvent = signal.event;
    if (pointerEvent is PointerCancelEvent) {
      doubleClickPressed = false;
      _clearPrimaryClickTracking();
      return;
    }

    if (pointerEvent is! PointerUpEvent) {
      return;
    }

    final activePointerId = _primaryClickPointerId;
    final pointerDownPosition = _primaryClickDownPosition;
    if (activePointerId == null || pointerDownPosition == null) {
      return;
    }

    if (activePointerId != pointerEvent.pointer) {
      return;
    }

    doubleClickPressed = false;

    final clickPosition = pointerEvent.localPosition;
    final clickTravelDistance = (clickPosition - pointerDownPosition).distance;
    _clearPrimaryClickTracking();

    if (clickTravelDistance > _maxClickTravelDistance) {
      return;
    }

    final pointerContext = interactionState.activePointerContext;
    if (pointerContext == null) {
      return;
    }

    final clickTimestamp = DateTime.now();

    if (wasDoubleClickPressed) {
      _lastPrimaryClickTimestamp = null;
      _lastPrimaryClickPosition = null;
      handleDoubleClick(pointerContext);
      return;
    }

    _lastPrimaryClickTimestamp = clickTimestamp;
    _lastPrimaryClickPosition = clickPosition;
    handleSingleClick(pointerContext);
  }

  void handleSingleClick(ArrangerPointerContext pointerContext) {
    if (pointerContext.target.suppressesClipLevelActions) {
      return;
    }

    final clipId = pointerContext.selectableClipId;

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

  void handleSecondaryClick(
    PointerEvent event,
    ArrangerPointerContext pointerContext,
  ) {
    if (pointerContext.target.suppressesClipLevelActions) {
      return;
    }

    final clipId = pointerContext.selectableClipId;
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

  void handleDoubleClick(ArrangerPointerContext pointerContext) {
    if (pointerContext.target.suppressesClipLevelActions) {
      return;
    }

    final clipId = pointerContext.selectableClipId;
    if (clipId == null) {
      return;
    }

    final isPartOfMultiSelection =
        viewModel.selectedClips.contains(clipId) &&
        viewModel.selectedClips.length > 1;

    final didOpenEditor = controller.openClipInEditor(clipId);

    if (didOpenEditor && !isPartOfMultiSelection) {
      viewModel.selectedClips.remove(clipId);
    }
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

class ArrangerDragState extends _ArrangerLeafState {
  static const double _dragActivationDistance = 4;

  @override
  ArrangerIdleState get parentState => super.parentState as ArrangerIdleState;

  int? activePointerId;
  ActivePointer? dragStartPosition;
  ActivePointer? dragCurrentPosition;
  ArrangerPointerContext? dragStartContext;
  ArrangerPointerContext? dragCurrentContext;
  bool hasCrossedActivationDistance = false;

  bool get isDragPointerActive => interactionState.isPrimaryPointerActive;

  bool get _isDragStartOverResizeHandle =>
      dragStartContext?.resizeHandleTarget != null;

  bool get _isDragStartOverMovableClip =>
      dragStartContext?.movableClipId != null;

  bool get _isDragStartOverEmpty => dragStartContext?.target.isEmpty ?? false;

  bool get _isDragStartOverAutomationClipContent {
    return dragStartContext?.automationClipContentClipId != null;
  }

  bool get _isDragStartOverAutomationPointHandle {
    return dragStartContext?.automationHandle?.kind ==
        AutomationHandleKind.point;
  }

  bool get _doesDragStartSuppressClipLevelActions =>
      dragStartContext?.target.suppressesClipLevelActions ?? false;

  bool get _isSelectionModeActive =>
      interactionState.isCtrlPressed || viewModel.tool == EditorTool.select;

  /// Resolves the interaction family this drag should delegate to, if any.
  ///
  /// Priority (first match wins):
  ///
  /// 1. No interaction if the pointer is up or the drag has been canceled.
  /// 2. Automation point move - on an automation point handle, or on a
  ///    double-click press over automation clip content.
  /// 3. Selection box - when Ctrl is held or the select tool is active, once
  ///    the pointer has moved past the activation distance and the target does
  ///    not suppress clip-level selection behavior.
  /// 4. Create clip - on a double-click press over empty canvas with the pencil
  ///    tool. Deliberately fires *before* the activation distance so a
  ///    double-click-release (no drag) can still insert at a point.
  /// 5. Clip resize - activation distance crossed with the drag start over a
  ///    resize handle.
  /// 6. Clip move - activation distance crossed with the drag start over a
  ///    movable clip target (not on its resize handle).
  ///
  /// Anything else returns null, meaning "stay in drag-parent".
  ArrangerInteractionFamily? get interactionFamily {
    if (!isDragPointerActive || interactionState.isCurrentInteractionCanceled) {
      return null;
    }

    if (_isDragStartOverAutomationPointHandle) {
      return ArrangerInteractionFamily.automationPointMove;
    }

    if (parentState.doubleClickPressed &&
        _isDragStartOverAutomationClipContent) {
      return ArrangerInteractionFamily.automationPointMove;
    }

    if (hasCrossedActivationDistance &&
        _isSelectionModeActive &&
        !_doesDragStartSuppressClipLevelActions) {
      return ArrangerInteractionFamily.selectionBox;
    }

    if (parentState.doubleClickPressed &&
        _isDragStartOverEmpty &&
        viewModel.tool == EditorTool.pencil) {
      return ArrangerInteractionFamily.createClip;
    }

    if (hasCrossedActivationDistance && _isDragStartOverResizeHandle) {
      return ArrangerInteractionFamily.clipResize;
    }

    if (hasCrossedActivationDistance &&
        !_isDragStartOverResizeHandle &&
        _isDragStartOverMovableClip) {
      return ArrangerInteractionFamily.clipMove;
    }

    return null;
  }

  bool get _isClipPressEligible =>
      isDragPointerActive &&
      !interactionState.isCurrentInteractionCanceled &&
      !_isSelectionModeActive &&
      !_doesDragStartSuppressClipLevelActions &&
      (_isDragStartOverMovableClip || _isDragStartOverResizeHandle);

  void _syncPressedClip() {
    final nextPressedClip = _isClipPressEligible
        ? dragStartContext?.selectableClipId
        : null;
    if (viewModel.pressedClip != nextPressedClip) {
      viewModel.pressedClip = nextPressedClip;
    }
  }

  void _syncDragParameters() {
    final nextActivePointerId = interactionState.isPrimaryPointerActive
        ? interactionState.activePointerId
        : null;

    if (nextActivePointerId == null) {
      activePointerId = null;
      dragStartPosition = null;
      dragCurrentPosition = null;
      dragStartContext = null;
      dragCurrentContext = null;
      hasCrossedActivationDistance = false;
      _syncPressedClip();
      return;
    }

    // A different primary pointer is now active than we last saw, which means
    // a new press just happened (we support one primary pointer at a time).
    // Capture the drag-start fixtures up front so later move events have a
    // fixed origin; interactionFamily / leaf states read these as-is.
    if (activePointerId != nextActivePointerId) {
      activePointerId = nextActivePointerId;
      dragStartPosition = interactionState.activePointerDownPosition?.clone();
      dragCurrentPosition = interactionState.activePointer?.clone();
      dragStartContext = interactionState.activePointerDownContext;
      dragCurrentContext = interactionState.activePointerContext;
      hasCrossedActivationDistance = false;
    }

    dragCurrentPosition = interactionState.activePointer?.clone();
    dragCurrentContext = interactionState.activePointerContext;

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
          interactionState.isPrimaryPointerActive,
    ),
    .new(
      name: 'Exit drag state',
      from: ArrangerDragState,
      to: ArrangerIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          !interactionState.isPrimaryPointerActive,
    ),
  ];

  ArrangerDragState(ArrangerIdleState super.parentState);
}
