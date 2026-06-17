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

import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/journal_commands.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';

// Pixel range where mouse events will affect stems.
const stemEditableSize = 80;

class PianoRollStemEditorPointerEvent {
  final double offset;
  final double normalizedY;
  final Size viewSize;
  final int pointer;

  const PianoRollStemEditorPointerEvent({
    required this.offset,
    required this.normalizedY,
    required this.viewSize,
    this.pointer = 0,
  });
}

class PianoRollStemEditorStateMachine
    extends EditorStateMachine<PianoRollStemEditorStateMachineData> {
  final ProjectModel project;
  final PianoRollViewModel viewModel;

  PianoRollStemEditorStateMachine._({
    required super.data,
    required super.idleState,
    required super.states,
    required this.project,
    required this.viewModel,
  });

  factory PianoRollStemEditorStateMachine.create({
    required ProjectModel project,
    required PianoRollViewModel viewModel,
  }) {
    final data = PianoRollStemEditorStateMachineData();
    final idleState = PianoRollStemIdleState();
    final pointerSessionState = PianoRollStemPointerSessionState(idleState);
    final editState = PianoRollStemEditState(pointerSessionState);

    return PianoRollStemEditorStateMachine._(
      data: data,
      idleState: idleState,
      states: [idleState, pointerSessionState, editState],
      project: project,
      viewModel: viewModel,
    );
  }

  PatternModel? get activePatternOrNull {
    final patternId = project.sequence.activePatternID;
    if (patternId == null) {
      return null;
    }

    return project.sequence.patterns[patternId];
  }

  void onPointerDown(PianoRollStemEditorPointerEvent event) {
    data.handlePointerDown(event);
    notifyDataUpdated();
  }

  void onPointerMove(PianoRollStemEditorPointerEvent event) {
    data.handlePointerMove(event);
    notifyDataUpdated();
  }

  void onPointerUp(PianoRollStemEditorPointerEvent event) {
    data.handlePointerUp(event);
    notifyDataUpdated();
  }
}

class PianoRollStemEditorStateMachineData {
  int? activePointerId;
  PianoRollStemEditorPointerEvent? pointerDownEvent;
  PianoRollStemEditorPointerEvent? currentEvent;
  Size viewSize = Size.zero;

  bool get isPointerActive => activePointerId != null;

  void handlePointerDown(PianoRollStemEditorPointerEvent event) {
    activePointerId = event.pointer;
    pointerDownEvent = event;
    currentEvent = event;
    viewSize = event.viewSize;
  }

  void handlePointerMove(PianoRollStemEditorPointerEvent event) {
    if (activePointerId != event.pointer) {
      return;
    }

    currentEvent = event;
    viewSize = event.viewSize;
  }

  void handlePointerUp(PianoRollStemEditorPointerEvent event) {
    if (activePointerId != event.pointer) {
      return;
    }

    activePointerId = null;
    viewSize = event.viewSize;
  }
}

abstract class _PianoRollStemMachineState
    extends EditorStateMachineState<PianoRollStemEditorStateMachineData> {
  _PianoRollStemMachineState([super.parentState]);

  PianoRollStemEditorStateMachine get stemStateMachine =>
      stateMachine as PianoRollStemEditorStateMachine;

  ProjectModel get project => stemStateMachine.project;
  PianoRollViewModel get viewModel => stemStateMachine.viewModel;
  PianoRollStemEditorStateMachineData get interactionState =>
      stemStateMachine.data;

  PatternModel? get activePatternOrNull => stemStateMachine.activePatternOrNull;
}

class PianoRollStemIdleState extends _PianoRollStemMachineState {}

class PianoRollStemPointerSessionState extends _PianoRollStemMachineState {
  @override
  PianoRollStemIdleState get parentState =>
      super.parentState as PianoRollStemIdleState;

  int? activePointerId;
  PianoRollStemEditorPointerEvent? pointerDownEvent;
  PianoRollStemEditorPointerEvent? currentEvent;
  PianoRollStem? activeStem;
  PatternModel? pattern;

  void _initializeSession() {
    activePointerId = interactionState.activePointerId;
    pointerDownEvent = interactionState.pointerDownEvent;
    currentEvent = interactionState.currentEvent;
    activeStem = viewModel.activeStem;
    pattern = activePatternOrNull;
  }

  void _syncCurrentEvent() {
    if (!interactionState.isPointerActive) {
      return;
    }

    currentEvent = interactionState.currentEvent;
  }

  void _clearSession() {
    activePointerId = null;
    pointerDownEvent = null;
    currentEvent = null;
    activeStem = null;
    pattern = null;
  }

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStemEditorStateMachineData> from,
  }) {
    _initializeSession();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    _syncCurrentEvent();
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStemEditorStateMachineData> to,
  }) {
    _clearSession();
  }

  @override
  Iterable<
    EditorStateMachineStateTransition<PianoRollStemEditorStateMachineData>
  >
  get transitions => [
    .new(
      name: 'Enter stem pointer session',
      from: PianoRollStemIdleState,
      to: PianoRollStemPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          data.isPointerActive,
    ),
    .new(
      name: 'Exit stem pointer session',
      from: PianoRollStemPointerSessionState,
      to: PianoRollStemIdleState,
      canTransition: ({required data, required event, required currentState}) =>
          !data.isPointerActive,
    ),
  ];

  PianoRollStemPointerSessionState(super.parentState);
}

class PianoRollStemEditState extends _PianoRollStemMachineState {
  @override
  PianoRollStemPointerSessionState get parentState =>
      super.parentState as PianoRollStemPointerSessionState;

  final oldValues = <Id, double>{};
  final newValues = <Id, double>{};

  PianoRollStem? activeStem;
  PatternModel? pattern;

  NoteAttribute _noteAttributeForStem(PianoRollStem stem) {
    return switch (stem) {
      PianoRollStem.velocity => NoteAttribute.velocity,
      PianoRollStem.pan => NoteAttribute.pan,
    };
  }

  double _stemValueForNote({
    required NoteModel note,
    required PianoRollStem stem,
  }) {
    return switch (stem) {
      PianoRollStem.velocity => note.velocity,
      PianoRollStem.pan => note.pan,
    };
  }

  Iterable<NoteModel> _candidateNotes(PatternModel pattern) {
    final notes = pattern.notes.values.toList(growable: false);
    if (viewModel.selectedNotes.isEmpty) {
      return notes;
    }

    return notes.where((note) => viewModel.selectedNotes.contains(note.id));
  }

  List<NoteModel> _affectedNotes({
    required PatternModel pattern,
    required PianoRollStemEditorPointerEvent event,
  }) {
    final notes = _candidateNotes(pattern).toList(growable: false);
    if (notes.isEmpty) {
      return const [];
    }

    Time? closestOffsetBefore;
    Time? closestOffsetAfter;

    for (final note in notes) {
      if (note.offset < event.offset) {
        if (closestOffsetBefore == null ||
            (note.offset - event.offset).abs() <
                (closestOffsetBefore - event.offset).abs()) {
          closestOffsetBefore = note.offset;
        }
        continue;
      }

      if (closestOffsetAfter == null ||
          (note.offset - event.offset).abs() <
              (closestOffsetAfter - event.offset).abs()) {
        closestOffsetAfter = note.offset;
      }
    }

    double offsetToPixels(Time offset) {
      return timeToPixels(
        timeViewStart: viewModel.timeRange.start,
        timeViewEnd: viewModel.timeRange.end,
        viewPixelWidth: event.viewSize.width,
        time: offset.toDouble(),
      );
    }

    final pointerTimePixels = timeToPixels(
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
      viewPixelWidth: event.viewSize.width,
      time: event.offset,
    );

    final closestBeforeDistance = closestOffsetBefore == null
        ? double.infinity
        : (offsetToPixels(closestOffsetBefore) - pointerTimePixels).abs();
    final closestAfterDistance = closestOffsetAfter == null
        ? double.infinity
        : (offsetToPixels(closestOffsetAfter) - pointerTimePixels).abs();

    final targetOffset = closestBeforeDistance <= closestAfterDistance
        ? closestOffsetBefore
        : closestOffsetAfter;
    final targetDistance = closestBeforeDistance <= closestAfterDistance
        ? closestBeforeDistance
        : closestAfterDistance;

    if (targetOffset == null || targetDistance > stemEditableSize / 2) {
      return const [];
    }

    return notes.where((note) => note.offset == targetOffset).toList();
  }

  double _valueFromEvent({
    required PianoRollStem stem,
    required PianoRollStemEditorPointerEvent event,
  }) {
    return (stem.top - stem.bottom) * event.normalizedY + stem.bottom;
  }

  void _applyPreview() {
    final stem = activeStem;
    final targetPattern = pattern;
    final event = parentState.currentEvent;
    if (stem == null || targetPattern == null || event == null) {
      return;
    }

    final newValue = _valueFromEvent(stem: stem, event: event);
    final affectedNotes = _affectedNotes(pattern: targetPattern, event: event);

    for (final note in affectedNotes) {
      oldValues[note.id] ??= _stemValueForNote(note: note, stem: stem);
      newValues[note.id] = newValue;

      switch (stem) {
        case PianoRollStem.velocity:
          viewModel.cursorNoteVelocity = newValue;
          targetPattern.setNoteOverride(noteId: note.id, velocity: newValue);
          break;
        case PianoRollStem.pan:
          viewModel.cursorNotePan = newValue;
          targetPattern.setNoteOverride(noteId: note.id, pan: newValue);
          break;
      }
    }
  }

  void _commitAndClearSession() {
    final stem = activeStem;
    final targetPattern = pattern;

    if (stem != null && targetPattern != null) {
      if (oldValues.isNotEmpty && newValues.isNotEmpty) {
        final isPatternStillRegistered =
            project.sequence.patterns[targetPattern.id] == targetPattern;

        if (isPatternStillRegistered) {
          final noteAttribute = _noteAttributeForStem(stem);
          final commands = oldValues.keys
              .where((noteId) => targetPattern.notes.containsKey(noteId))
              .map(
                (noteId) => SetNoteAttributeCommand(
                  patternID: targetPattern.id,
                  noteID: noteId,
                  attribute: noteAttribute,
                  oldValue: oldValues[noteId]!,
                  newValue: newValues[noteId]!,
                ),
              )
              .toList(growable: false);

          if (commands.isNotEmpty) {
            project.push(JournalPageCommand(commands), execute: true);
          }
        }

        targetPattern.clearNoteOverrides();
      }
    }

    _clearSession();
  }

  void _clearSession() {
    activeStem = null;
    pattern = null;
    oldValues.clear();
    newValues.clear();
  }

  @override
  Iterable<
    EditorStateMachineStateTransition<PianoRollStemEditorStateMachineData>
  >
  get transitions => [
    .new(
      name: 'Delegate stem pointer session to edit',
      from: PianoRollStemPointerSessionState,
      to: PianoRollStemEditState,
      canTransition: ({required data, required event, required currentState}) {
        final pointerSessionState =
            currentState as PianoRollStemPointerSessionState;
        return pointerSessionState.activeStem != null &&
            pointerSessionState.pattern != null;
      },
    ),
    .new(
      name: 'Exit stem edit',
      from: PianoRollStemEditState,
      to: PianoRollStemPointerSessionState,
      canTransition: ({required data, required event, required currentState}) =>
          !data.isPointerActive,
    ),
  ];

  PianoRollStemEditState(super.parentState);

  @override
  void onEntry({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStemEditorStateMachineData> from,
  }) {
    activeStem = parentState.activeStem;
    pattern = parentState.pattern;
    _applyPreview();
  }

  @override
  void onActive({required EditorStateMachineEvent event}) {
    if (!interactionState.isPointerActive) {
      return;
    }

    _applyPreview();
  }

  @override
  void onExit({
    required EditorStateMachineEvent event,
    required EditorStateMachineState<PianoRollStemEditorStateMachineData> to,
  }) {
    _commitAndClearSession();
  }

  @override
  void onDispose() {
    if (oldValues.isNotEmpty) {
      pattern?.clearNoteOverrides();
    }

    _clearSession();
  }
}
