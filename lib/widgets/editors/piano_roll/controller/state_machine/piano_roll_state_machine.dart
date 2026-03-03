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
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';

part 'create_note_state.dart';
part 'erase_notes_state.dart';
part 'move_notes_state.dart';
part 'resize_notes_state.dart';
part 'selection_box_state.dart';

sealed class _PianoRollAdaptedPointerSignal {
  const _PianoRollAdaptedPointerSignal();
}

class _PianoRollAdaptedPointerDownSignal
    extends _PianoRollAdaptedPointerSignal {
  final PianoRollInteractionFamily family;
  final PianoRollPointerDownEvent event;

  const _PianoRollAdaptedPointerDownSignal({
    required this.family,
    required this.event,
  });
}

class _PianoRollAdaptedPointerMoveSignal
    extends _PianoRollAdaptedPointerSignal {
  final PianoRollPointerMoveEvent event;

  const _PianoRollAdaptedPointerMoveSignal(this.event);
}

class _PianoRollAdaptedPointerUpSignal extends _PianoRollAdaptedPointerSignal {
  final PianoRollPointerUpEvent event;

  const _PianoRollAdaptedPointerUpSignal(this.event);
}

/// The long-term interaction state machine for the piano roll.
///
/// This first scaffolding pass only establishes the state hierarchy and
/// controller ownership. All interaction behavior still lives on the legacy
/// controller path until routing is introduced.
class PianoRollStateMachine
    extends EditorStateMachine<PianoRollStateMachineData> {
  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final PianoRollController controller;
  int _adaptedPointerDownCount = 0;
  int _adaptedPointerMoveCount = 0;
  int _adaptedPointerUpCount = 0;

  PianoRollStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
    required this.controller,
  });

  factory PianoRollStateMachine.create({
    required ProjectModel project,
    required PianoRollViewModel viewModel,
    required PianoRollController controller,
  }) {
    final data = PianoRollStateMachineData();
    final idleState = PianoRollIdleState();
    final pointerSessionState = PianoRollPointerSessionState(idleState);
    final noteInteractionState = PianoRollNoteInteractionState(
      pointerSessionState,
    );
    final selectionBoxState = PianoRollSelectionBoxState(pointerSessionState);
    final eraseNotesState = PianoRollEraseNotesState(pointerSessionState);
    final moveNotesState = PianoRollMoveNotesState(noteInteractionState);
    final resizeNotesState = PianoRollResizeNotesState(noteInteractionState);
    final createNoteState = PianoRollCreateNoteState(noteInteractionState);
    final states = <EditorStateMachineState<PianoRollStateMachineData>>[
      idleState,
      pointerSessionState,
      noteInteractionState,
      selectionBoxState,
      eraseNotesState,
      moveNotesState,
      resizeNotesState,
      createNoteState,
    ];

    return PianoRollStateMachine._(
      data: data,
      idleState: idleState,
      states: states,
      project: project,
      viewModel: viewModel,
      controller: controller,
    );
  }

  @visibleForTesting
  int get adaptedPointerDownCount => _adaptedPointerDownCount;

  @visibleForTesting
  int get adaptedPointerMoveCount => _adaptedPointerMoveCount;

  @visibleForTesting
  int get adaptedPointerUpCount => _adaptedPointerUpCount;

  void onAdaptedPointerDown(PianoRollPointerDownEvent event) {
    final family = controller.activeInteractionFamily;
    if (family == null) {
      return;
    }

    _adaptedPointerDownCount++;
    data.beginAdaptedPointerSession(family: family, downEvent: event);
    emitSignal(
      _PianoRollAdaptedPointerDownSignal(family: family, event: event),
    );
  }

  void onAdaptedPointerMove(PianoRollPointerMoveEvent event) {
    if (!data.hasActiveAdaptedPointerSession) {
      return;
    }

    _adaptedPointerMoveCount++;
    data.handleAdaptedPointerMove(event);
    emitSignal(_PianoRollAdaptedPointerMoveSignal(event));
  }

  void onAdaptedPointerUp(PianoRollPointerUpEvent event) {
    if (!data.hasActiveAdaptedPointerSession) {
      return;
    }

    _adaptedPointerUpCount++;
    data.endAdaptedPointerSession(event);
    emitSignal(_PianoRollAdaptedPointerUpSignal(event));
  }
}

/// Shared interaction data for the future piano-roll state machine.
///
/// This starts intentionally minimal. Later steps will move pointer and view
/// transform ownership here as gesture routing shifts from the legacy path to
/// the machine.
class PianoRollStateMachineData {
  PianoRollInteractionFamily? activeAdaptedInteractionFamily;
  PianoRollPointerDownEvent? adaptedPointerDownEvent;
  PianoRollPointerMoveEvent? adaptedPointerMoveEvent;
  PianoRollPointerUpEvent? adaptedPointerUpEvent;

  bool get hasActiveAdaptedPointerSession =>
      activeAdaptedInteractionFamily != null;

  void beginAdaptedPointerSession({
    required PianoRollInteractionFamily family,
    required PianoRollPointerDownEvent downEvent,
  }) {
    activeAdaptedInteractionFamily = family;
    adaptedPointerDownEvent = downEvent;
    adaptedPointerMoveEvent = null;
    adaptedPointerUpEvent = null;
  }

  void handleAdaptedPointerMove(PianoRollPointerMoveEvent moveEvent) {
    adaptedPointerMoveEvent = moveEvent;
  }

  void endAdaptedPointerSession(PianoRollPointerUpEvent upEvent) {
    adaptedPointerUpEvent = upEvent;
    activeAdaptedInteractionFamily = null;
  }
}

class PianoRollIdleState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;
}

class PianoRollPointerSessionState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  @override
  PianoRollIdleState get parentState => super.parentState as PianoRollIdleState;

  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;

  @override
  Iterable<EditorStateMachineStateTransition<PianoRollStateMachineData>>
  get transitions => [
    .new(
      name: 'Enter adapted pointer session',
      from: PianoRollIdleState,
      to: PianoRollPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.hasActiveAdaptedPointerSession,
    ),
    .new(
      name: 'Exit adapted pointer session',
      from: PianoRollPointerSessionState,
      to: PianoRollIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          !data.hasActiveAdaptedPointerSession,
    ),
  ];

  PianoRollPointerSessionState(super.parentState);
}

class PianoRollNoteInteractionState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  @override
  PianoRollPointerSessionState get parentState =>
      super.parentState as PianoRollPointerSessionState;

  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
  PianoRollController get controller => pianoRollStateMachine.controller;

  PianoRollNoteInteractionState(super.parentState);
}
