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

import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_live_notes.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'shortcuts.dart';

const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;

enum PianoRollInteractionFamily {
  selectionBox,
  erase,
  moveNotes,
  resizeNotes,
  createNote,
}

enum PianoRollModifierKey { ctrl, alt, shift }

typedef PianoRollMoveNotePreview = ({int key, Time offset});
typedef PianoRollResizeNotePreview = ({Time length});

class PianoRollController extends _PianoRollController
    with _PianoRollShortcutsMixin
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

  _PianoRollController({required this.project, required this.viewModel})
    : liveNotes = PianoRollLiveNotes(project);

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    stateMachine.data.clearInteractionSession();
    liveNotes.removeAll();
    viewModel.selectionBox = null;
    viewModel.pressedNote = null;
    clearPreviewState();
    stateMachine.dispose();
  }

  @visibleForTesting
  PianoRollInteractionFamily? get activeInteractionFamily =>
      stateMachine.data.activeInteractionFamily;

  void modifierPressed(PianoRollModifierKey modifier) {
    stateMachine.modifierPressed(modifier);
  }

  void modifierReleased(PianoRollModifierKey modifier) {
    stateMachine.modifierReleased(modifier);
  }

  void pointerDown(PointerDownEvent event) {
    stateMachine.onPointerDown(event);
  }

  void pointerMove(PointerMoveEvent event) {
    stateMachine.onPointerMove(event);
  }

  void pointerUp(PointerEvent event) {
    stateMachine.onPointerUp(event);
  }

  void onRenderedViewMetricsChanged({
    required Size viewSize,
    required double timeViewStart,
    required double timeViewEnd,
    required double keyHeight,
    required double keyValueAtTop,
  }) {
    stateMachine.onRenderedViewTransformChanged(
      viewSize: viewSize,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      keyHeight: keyHeight,
      keyValueAtTop: keyValueAtTop,
    );
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

  /// Clears any in-progress editor preview state for the active pattern.
  ///
  /// Pattern-owned preview state is split between committed-note overrides and
  /// preview-only notes that do not exist in the main pattern note list yet.
  /// The view model still owns transient interaction metadata like pressed and
  /// hovered IDs. All of that state must be cleared together whenever an
  /// interaction ends or is canceled.
  void clearPreviewState() {
    final previewNoteIds = activePatternOrNull?.previewNotes.keys.toSet() ?? {};
    activePatternOrNull?.clearNotePreviews();
    viewModel.clearTransientPreviewState();

    // Selected preview-only note IDs should only survive if those preview
    // notes were committed as real notes first. If preview notes are being
    // cleared outright, drop any now-dangling IDs from the selection.
    if (previewNoteIds.isNotEmpty) {
      viewModel.selectedNotes.removeAll(previewNoteIds);
    }
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

  /// Deletes notes in the selectedNotes set from the view model.
  void deleteSelected() {
    final pattern = activePatternOrNull;
    if (viewModel.selectedNotes.isEmpty || pattern == null) {
      return;
    }

    final command = DeleteNotesCommand(
      patternID: pattern.id,
      notes: viewModel.selectedNotes
          .map((noteId) => pattern.notes[noteId])
          .nonNulls,
    );

    project.execute(command);

    viewModel.selectedNotes.clear();
  }

  /// Adds all notes to the selection set in the view model.
  void selectAll() {
    final pattern = activePatternOrNull;
    if (pattern == null) {
      return;
    }

    viewModel.selectedNotes = ObservableSet.of(pattern.notes.keys.toSet());
  }
}
