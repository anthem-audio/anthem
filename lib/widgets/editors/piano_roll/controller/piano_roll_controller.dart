/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'package:anthem/logic/commands/journal_commands.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_live_notes.dart';
import 'package:anthem/widgets/editors/piano_roll/events.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/box_intersection.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'shortcuts.dart';
part 'pointer_events.dart';

enum PianoRollInteractionFamily {
  selectionBox,
  erase,
  moveNotes,
  resizeNotes,
  createNote,
}

enum PianoRollInteractionBackend { legacy, stateMachine }

class _PianoRollInteractionRoute {
  final PianoRollInteractionFamily family;
  final PianoRollInteractionBackend backend;

  const _PianoRollInteractionRoute({
    required this.family,
    required this.backend,
  });
}

class PianoRollController extends _PianoRollController
    with _PianoRollShortcutsMixin, _PianoRollPointerEventsMixin
    implements DisposableService {
  @override
  PianoRollController({required super.project, required super.viewModel}) {
    // Register shortcuts for this editor
    registerShortcuts();
  }
}

class _PianoRollController {
  final ProjectModel project;
  final PianoRollViewModel viewModel;
  final PianoRollLiveNotes liveNotes;
  late final PianoRollStateMachine stateMachine = PianoRollStateMachine.create(
    project: project,
    viewModel: viewModel,
    controller: this as PianoRollController,
  );
  bool _isDisposed = false;
  final Map<PianoRollInteractionFamily, PianoRollInteractionBackend>
  _interactionBackends = {
    PianoRollInteractionFamily.selectionBox:
        PianoRollInteractionBackend.stateMachine,
    PianoRollInteractionFamily.erase: PianoRollInteractionBackend.legacy,
    PianoRollInteractionFamily.moveNotes: PianoRollInteractionBackend.legacy,
    PianoRollInteractionFamily.resizeNotes: PianoRollInteractionBackend.legacy,
    PianoRollInteractionFamily.createNote: PianoRollInteractionBackend.legacy,
  };
  _PianoRollInteractionRoute? _activeInteractionRoute;

  _PianoRollController({required this.project, required this.viewModel})
    : liveNotes = PianoRollLiveNotes(project);

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _clearActiveInteractionRoute();
    liveNotes.removeAll();
    stateMachine.dispose();
  }

  @visibleForTesting
  PianoRollInteractionFamily? get activeInteractionFamily =>
      _activeInteractionRoute?.family;

  @visibleForTesting
  PianoRollInteractionBackend? get activeInteractionBackend =>
      _activeInteractionRoute?.backend;

  @visibleForTesting
  PianoRollInteractionBackend backendForFamily(
    PianoRollInteractionFamily family,
  ) {
    return _interactionBackends[family]!;
  }

  @visibleForTesting
  void setInteractionBackendForTesting(
    PianoRollInteractionFamily family,
    PianoRollInteractionBackend backend,
  ) {
    _interactionBackends[family] = backend;
  }

  PianoRollInteractionFamily? classifyPointerDownInteraction(
    PianoRollPointerDownEvent event,
  ) {
    if (project.sequence.activePatternID == null) {
      return null;
    }

    final isPrimaryClick =
        event.pointerEvent.buttons & kPrimaryMouseButton == kPrimaryMouseButton;
    final isSecondaryClick =
        event.pointerEvent.buttons & kSecondaryMouseButton ==
        kSecondaryMouseButton;

    if (isPrimaryClick && viewModel.tool != EditorTool.eraser) {
      if (event.keyboardModifiers.ctrl || viewModel.tool == EditorTool.select) {
        return PianoRollInteractionFamily.selectionBox;
      }

      if (event.isResize && viewModel.tool == EditorTool.pencil) {
        return PianoRollInteractionFamily.resizeNotes;
      }

      if (event.noteUnderCursor != null) {
        return PianoRollInteractionFamily.moveNotes;
      }

      return PianoRollInteractionFamily.createNote;
    }

    if (isSecondaryClick || viewModel.tool == EditorTool.eraser) {
      return PianoRollInteractionFamily.erase;
    }

    return null;
  }

  void _clearActiveInteractionRoute() {
    _activeInteractionRoute = null;
  }

  void pointerDown(PianoRollPointerDownEvent event) {
    final family = classifyPointerDownInteraction(event);
    if (family == null) {
      _clearActiveInteractionRoute();
      return;
    }

    final backend = _interactionBackends[family]!;
    _activeInteractionRoute = _PianoRollInteractionRoute(
      family: family,
      backend: backend,
    );

    switch (backend) {
      case PianoRollInteractionBackend.legacy:
        (this as PianoRollController).legacyPointerDown(event);
      case PianoRollInteractionBackend.stateMachine:
        stateMachine.onAdaptedPointerDown(event);
    }
  }

  void pointerMove(PianoRollPointerMoveEvent event) {
    final route = _activeInteractionRoute;
    if (route == null) {
      return;
    }

    switch (route.backend) {
      case PianoRollInteractionBackend.legacy:
        (this as PianoRollController).legacyPointerMove(event);
      case PianoRollInteractionBackend.stateMachine:
        stateMachine.onAdaptedPointerMove(event);
    }
  }

  void pointerUp(PianoRollPointerUpEvent event) {
    final route = _activeInteractionRoute;
    if (route == null) {
      return;
    }

    try {
      switch (route.backend) {
        case PianoRollInteractionBackend.legacy:
          (this as PianoRollController).legacyPointerUp(event);
        case PianoRollInteractionBackend.stateMachine:
          stateMachine.onAdaptedPointerUp(event);
      }
    } finally {
      _clearActiveInteractionRoute();
    }
  }

  PatternModel? get activePatternOrNull {
    final patternId = project.sequence.activePatternID;
    if (patternId == null) {
      return null;
    }

    return project.sequence.patterns[patternId];
  }

  PatternModel requireActivePattern() {
    final patternId = project.sequence.activePatternID;
    if (patternId == null) {
      throw StateError('Active pattern is not set');
    }

    final pattern = project.sequence.patterns[patternId];
    if (pattern == null) {
      throw StateError('Active pattern $patternId was not found');
    }

    return pattern;
  }

  NoteModel requireActivePatternNote(Id noteId) {
    return requireActivePattern().notes.firstWhere((note) => note.id == noteId);
  }

  List<DivisionChange> divisionChangesForPatternView({
    required double viewWidthInPixels,
  }) {
    final pattern = requireActivePattern();

    return getDivisionChanges(
      viewWidthInPixels: viewWidthInPixels,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: pattern.timeSignatureChanges,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeView.start,
      timeViewEnd: viewModel.timeView.end,
    );
  }

  int snapTimeInActivePattern({
    required int rawTime,
    required double viewWidthInPixels,
    bool ceil = false,
    bool round = false,
    int startTime = 0,
  }) {
    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: divisionChangesForPatternView(
        viewWidthInPixels: viewWidthInPixels,
      ),
      ceil: ceil,
      round: round,
      startTime: startTime,
    );
  }

  NoteModel addNoteToActivePattern({
    required int key,
    required double velocity,
    required int length,
    required int offset,
    required double pan,
  }) {
    final pattern = requireActivePattern();

    final note = NoteModel(
      key: key,
      velocity: velocity,
      length: length,
      offset: offset,
      pan: pan,
    );

    project.execute(AddNoteCommand(patternID: pattern.id, note: note));

    return note;
  }

  /// Adds a time signature change to the pattern.
  void addTimeSignatureChange({
    required TimeSignatureModel timeSignature,
    required Time offset,
    bool snap = true,
    required double pianoRollWidth,
  }) {
    if (project.sequence.activePatternID == null) return;

    var snappedOffset = offset;

    if (snap) {
      snappedOffset = snapTimeInActivePattern(
        rawTime: offset.floor(),
        viewWidthInPixels: pianoRollWidth,
        ceil: true,
      );
    }

    project.execute(
      AddTimeSignatureChangeCommand(
        timelineKind: TimelineKind.pattern,
        patternID: requireActivePattern().id,
        change: TimeSignatureChangeModel(
          offset: snappedOffset,
          timeSignature: timeSignature,
        ),
      ),
    );
  }

  /// Records the parameters of this note so the next placed note has the same
  /// parameters.
  void setCursorNoteParameters(NoteModel note) {
    viewModel.cursorNoteLength = note.length;
    viewModel.cursorNoteVelocity = note.velocity;
    viewModel.cursorNotePan = note.pan;
  }

  /// Deletes notes in the selectedNotes set from the view model.
  void deleteSelected() {
    final pattern = activePatternOrNull;
    if (viewModel.selectedNotes.isEmpty || pattern == null) {
      return;
    }

    final commands = pattern.notes
        .where((note) => viewModel.selectedNotes.contains(note.id))
        .map((note) {
          return DeleteNoteCommand(patternID: pattern.id, note: note);
        })
        .toList();

    final command = JournalPageCommand(commands);

    project.execute(command);

    viewModel.selectedNotes.clear();
  }

  /// Adds all notes to the selection set in the view model.
  void selectAll() {
    final pattern = activePatternOrNull;
    if (pattern == null) {
      return;
    }

    viewModel.selectedNotes = ObservableSet.of(
      pattern.notes.map((note) => note.id).toSet(),
    );
  }

  List<NoteModel> getNotesUnderCursor(
    Iterable<NoteModel> notes,
    double key,
    double offset,
  ) {
    final keyFloor = key.floor();

    return notes.where((note) {
      return offset >= note.offset &&
          offset < note.offset + note.length &&
          keyFloor == note.key;
    }).toList();
  }
}
