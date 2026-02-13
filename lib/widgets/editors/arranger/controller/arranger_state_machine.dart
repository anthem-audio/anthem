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

import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/events.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

enum ArrangerModifierKey { ctrl, alt, shift }

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

  void onPointerDown(ArrangerPointerEvent event) {
    updateData((data) {
      data.handlePointerDown(event);
    });
  }

  void onPointerMove(ArrangerPointerEvent event) {
    updateData((data) {
      data.handlePointerMove(event);
    });
  }

  void onPointerUp(ArrangerPointerEvent event) {
    updateData((data) {
      data.handlePointerUp(event);
    });
  }

  void onEnter(PointerEnterEvent event) {
    updateData((data) {
      data.handleEnter(event);
    });
  }

  void onExit(PointerExitEvent event) {
    updateData((data) {
      data.handleExit(event);
    });
  }

  void onHover(PointerHoverEvent event) {
    updateData((data) {
      data.handleHover(event);
    });
  }

  void onViewSizeChanged(Size viewSize) {
    updateData((data) {
      data.viewSize = viewSize;
    });
  }

  void modifierPressed(ArrangerModifierKey modifier) {
    if (data.isModifierPressed(modifier)) {
      return;
    }

    updateData((data) {
      data.setModifier(modifier, true);
    });
  }

  void modifierReleased(ArrangerModifierKey modifier) {
    if (!data.isModifierPressed(modifier)) {
      return;
    }

    updateData((data) {
      data.setModifier(modifier, false);
    });
  }

  List<DivisionChange> divisionChanges() {
    return getDivisionChanges(
      viewWidthInPixels: data.viewSize.width,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: [],
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );
  }

  ArrangerStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
  });

  factory ArrangerStateMachine.create({
    required ProjectModel project,
    required ArrangerViewModel viewModel,
  }) {
    final data = ArrangerStateMachineData();
    final idleState = ArrangerIdleState();
    final states = [idleState];

    return ArrangerStateMachine._(
      data: data,
      idleState: idleState,
      states: states,
      project: project,
      viewModel: viewModel,
    );
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   // some other stuff
  // }
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

  void handlePointerDown(ArrangerPointerEvent event) {
    final pos = event.pointerEvent.localPosition;
    pointers[event.pointerEvent.pointer] = .new(pos.dx, pos.dy);
  }

  void handlePointerMove(ArrangerPointerEvent event) {
    final pointer = pointers[event.pointerEvent.pointer];
    if (pointer == null) return;

    final pos = event.pointerEvent.localPosition;
    pointer.x = pos.dx;
    pointer.y = pos.dy;
  }

  void handlePointerUp(ArrangerPointerEvent event) {
    pointers.remove(event.pointerEvent.pointer);
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
}

class ArrangerIdleState
    extends EditorStateMachineState<ArrangerStateMachineData> {
  /// Convenience getter to fetch the base state machine object.
  ArrangerStateMachine get arrangerStateMachine =>
      stateMachine as ArrangerStateMachine;

  /// The main input data for the state machine, which is the current
  /// interaction state (e.g. what pointers are down and where, which modifier
  /// keys are pressed).
  ArrangerStateMachineData get interactionState => arrangerStateMachine.data;

  ProjectModel get project => arrangerStateMachine.project;
  ArrangerViewModel get viewModel => arrangerStateMachine.viewModel;

  ActivePointer? lastHoveredPointer;

  /// Updates the current mouse hover position with a new one from [interactionState].
  void updateHover() {
    lastHoveredPointer = interactionState.hoveredPointer?.clone();

    updateCursor(
      lastHoveredPointer == null
          ? null
          : (lastHoveredPointer!.x, lastHoveredPointer!.y),
    );
  }

  void updateCursor((double x, double y)? coordinates) {
    if (coordinates == null) {
      viewModel.cursorLocation = null;
      return;
    }

    final (x, y) = coordinates;

    final fractionalTrackIndex = viewModel.trackPositionCalculator
        .getTrackIndexFromPosition(y);

    if (fractionalTrackIndex.isInfinite) {
      viewModel.cursorLocation = null;
      return;
    }

    final trackId = viewModel.trackPositionCalculator.trackIndexToId(
      fractionalTrackIndex.floor(),
    );

    final offset = pixelsToTime(
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
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

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Mouse moved (idle)',
      from: ArrangerIdleState,
      to: ArrangerIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          lastHoveredPointer != data.hoveredPointer,
      onTransition: ({required event, required from, required to}) =>
          updateHover(),
    ),
  ];
}
