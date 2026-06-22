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
import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/journal_commands.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/editor_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';

const _stemNearestHitRadiusPixels = 40.0;

class _PianoRollStemEditNoteSnapshot {
  final Id id;
  final Time offset;
  final double oldValue;

  const _PianoRollStemEditNoteSnapshot({
    required this.id,
    required this.offset,
    required this.oldValue,
  });
}

int _lowerBoundByOffset(
  List<_PianoRollStemEditNoteSnapshot> notes,
  double offset,
) {
  var low = 0;
  var high = notes.length;

  while (low < high) {
    final mid = low + ((high - low) >> 1);
    if (notes[mid].offset < offset) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }

  return low;
}

Time? _nearestStemOffset(
  List<_PianoRollStemEditNoteSnapshot> notes,
  double offset, {
  required double maxDistance,
}) {
  if (notes.isEmpty) {
    return null;
  }

  final nextIndex = _lowerBoundByOffset(notes, offset);
  final previousNote = nextIndex > 0 ? notes[nextIndex - 1] : null;
  final nextNote = nextIndex < notes.length ? notes[nextIndex] : null;

  final Time nearestOffset;
  if (previousNote == null) {
    nearestOffset = nextNote!.offset;
  } else if (nextNote == null) {
    nearestOffset = previousNote.offset;
  } else {
    final previousDistance = (previousNote.offset - offset).abs();
    final nextDistance = (nextNote.offset - offset).abs();
    nearestOffset = previousDistance <= nextDistance
        ? previousNote.offset
        : nextNote.offset;
  }

  if ((nearestOffset - offset).abs() > maxDistance) {
    return null;
  }

  return nearestOffset;
}

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
  PianoRollStemEditorPointerEvent? previousEvent;
  PianoRollStemEditorPointerEvent? currentEvent;
  PianoRollStem? activeStem;
  PatternModel? pattern;
  List<_PianoRollStemEditNoteSnapshot> _noteSnapshots = const [];

  void _initializeSession() {
    activePointerId = interactionState.activePointerId;
    pointerDownEvent = interactionState.pointerDownEvent;
    previousEvent = interactionState.currentEvent;
    currentEvent = interactionState.currentEvent;
    activeStem = viewModel.activeStem;
    pattern = activePatternOrNull;
    _noteSnapshots = _createNoteSnapshot();
  }

  void _syncCurrentEvent() {
    final nextEvent = interactionState.currentEvent;
    if (nextEvent == null || identical(nextEvent, currentEvent)) {
      return;
    }

    previousEvent = currentEvent ?? nextEvent;
    currentEvent = nextEvent;
  }

  List<_PianoRollStemEditNoteSnapshot> _createNoteSnapshot() {
    final stem = activeStem;
    final targetPattern = pattern;
    if (stem == null || targetPattern == null) {
      return const [];
    }

    final hasSelectedNotes = viewModel.selectedNotes.isNotEmpty;
    final notes =
        targetPattern.notes.values
            .where(
              (note) =>
                  !hasSelectedNotes ||
                  viewModel.selectedNotes.contains(note.id),
            )
            .map(
              (note) => _PianoRollStemEditNoteSnapshot(
                id: note.id,
                offset: note.offset,
                oldValue: switch (stem) {
                  PianoRollStem.velocity => note.velocity,
                  PianoRollStem.pan => note.pan,
                },
              ),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final offsetCompare = a.offset.compareTo(b.offset);
            if (offsetCompare != 0) {
              return offsetCompare;
            }

            return a.id.compareTo(b.id);
          });

    return List.unmodifiable(notes);
  }

  void _clearSession() {
    activePointerId = null;
    pointerDownEvent = null;
    previousEvent = null;
    currentEvent = null;
    activeStem = null;
    pattern = null;
    _noteSnapshots = const [];
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

  List<_PianoRollStemEditNoteSnapshot> _notesInOffsetRange({
    required List<_PianoRollStemEditNoteSnapshot> notes,
    required double startOffset,
    required double endOffset,
  }) {
    final firstIndex = _lowerBoundByOffset(notes, startOffset);
    final result = <_PianoRollStemEditNoteSnapshot>[];

    for (var i = firstIndex; i < notes.length; i++) {
      final note = notes[i];
      if (note.offset > endOffset) {
        break;
      }

      result.add(note);
    }

    return result;
  }

  double _normalizedYForOffset({
    required double startOffset,
    required double startY,
    required double endOffset,
    required double endY,
    required double offset,
  }) {
    final offsetDelta = endOffset - startOffset;
    if (offsetDelta == 0) {
      return endY;
    }

    final t = ((offset - startOffset) / offsetDelta).clamp(0.0, 1.0);
    return startY + (endY - startY) * t;
  }

  double _valueFromNormalizedY({
    required PianoRollStem stem,
    required double normalizedY,
  }) {
    return (stem.top - stem.bottom) * normalizedY + stem.bottom;
  }

  double _nearestStemHitRadiusTime(PianoRollStemEditorPointerEvent event) {
    final viewWidth = event.viewSize.width;
    if (viewWidth <= 0) {
      return 0;
    }

    return viewModel.timeRange.width.abs() /
        viewWidth *
        _stemNearestHitRadiusPixels;
  }

  void _applyPreview() {
    final stem = activeStem;
    final targetPattern = pattern;
    final endEvent = parentState.currentEvent;
    final noteSnapshots = parentState._noteSnapshots;
    if (stem == null || targetPattern == null || endEvent == null) {
      return;
    }

    final startEvent = parentState.previousEvent ?? endEvent;
    final startEdgeOffset = _nearestStemOffset(
      noteSnapshots,
      startEvent.offset,
      maxDistance: _nearestStemHitRadiusTime(startEvent),
    );
    final endEdgeOffset = _nearestStemOffset(
      noteSnapshots,
      endEvent.offset,
      maxDistance: _nearestStemHitRadiusTime(endEvent),
    );
    if (startEdgeOffset == null || endEdgeOffset == null) {
      return;
    }

    final rangeStart = min(startEdgeOffset, endEdgeOffset).toDouble();
    final rangeEnd = max(startEdgeOffset, endEdgeOffset).toDouble();
    final affectedNotes = _notesInOffsetRange(
      notes: noteSnapshots,
      startOffset: rangeStart,
      endOffset: rangeEnd,
    );

    if (affectedNotes.isEmpty) {
      return;
    }

    final cursorValue = _valueFromNormalizedY(
      stem: stem,
      normalizedY: endEvent.normalizedY,
    );
    switch (stem) {
      case PianoRollStem.velocity:
        viewModel.cursorNoteVelocity = cursorValue;
        break;
      case PianoRollStem.pan:
        viewModel.cursorNotePan = cursorValue;
        break;
    }

    for (final note in affectedNotes) {
      if (!targetPattern.notes.containsKey(note.id)) {
        continue;
      }

      final newValue = _valueFromNormalizedY(
        stem: stem,
        normalizedY: _normalizedYForOffset(
          startOffset: startEdgeOffset.toDouble(),
          startY: startEvent.normalizedY,
          endOffset: endEdgeOffset.toDouble(),
          endY: endEvent.normalizedY,
          offset: note.offset.toDouble(),
        ),
      );
      oldValues[note.id] ??= note.oldValue;
      newValues[note.id] = newValue;

      switch (stem) {
        case PianoRollStem.velocity:
          targetPattern.setNoteOverride(noteId: note.id, velocity: newValue);
          break;
        case PianoRollStem.pan:
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
