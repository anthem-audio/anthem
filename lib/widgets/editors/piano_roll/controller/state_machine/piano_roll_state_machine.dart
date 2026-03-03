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
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';

part 'create_note_state.dart';
part 'erase_notes_state.dart';
part 'move_notes_state.dart';
part 'resize_notes_state.dart';
part 'selection_box_state.dart';

/// The long-term interaction state machine for the piano roll.
///
/// This first scaffolding pass only establishes the state hierarchy and
/// controller ownership. All interaction behavior still lives on the legacy
/// controller path until routing is introduced.
class PianoRollStateMachine
    extends EditorStateMachine<PianoRollStateMachineData> {
  final ProjectModel project;
  final PianoRollViewModel viewModel;

  PianoRollStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
  });

  factory PianoRollStateMachine.create({
    required ProjectModel project,
    required PianoRollViewModel viewModel,
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
    );
  }
}

/// Shared interaction data for the future piano-roll state machine.
///
/// This starts intentionally minimal. Later steps will move pointer and view
/// transform ownership here as gesture routing shifts from the legacy path to
/// the machine.
class PianoRollStateMachineData {}

class PianoRollIdleState
    extends EditorStateMachineState<PianoRollStateMachineData> {
  PianoRollStateMachine get pianoRollStateMachine =>
      stateMachine as PianoRollStateMachine;

  PianoRollStateMachineData get interactionState => pianoRollStateMachine.data;

  ProjectModel get project => pianoRollStateMachine.project;
  PianoRollViewModel get viewModel => pianoRollStateMachine.viewModel;
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

  PianoRollNoteInteractionState(super.parentState);
}
