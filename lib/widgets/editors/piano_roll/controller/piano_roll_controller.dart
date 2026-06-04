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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_live_notes.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/piano_roll.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

part 'shortcuts.dart';

const maxSafeIntWeb = 0x001F_FFFF_FFFF_FFFF;

/// Resolves a requested vertical note move against the piano-roll key range.
///
/// Drag moves use the clamped result so notes move as far as possible. Step
/// moves that must preserve pitch class, such as octave transposition, can set
/// [requireExactDelta] so an out-of-range request becomes a no-op.
int resolvePianoRollKeyDelta({
  required int requestedDelta,
  required int keyOfTopNote,
  required int keyOfBottomNote,
  bool requireExactDelta = false,
}) {
  var resolvedDelta = requestedDelta;

  if (keyOfTopNote + resolvedDelta > maxKeyValue) {
    resolvedDelta = maxKeyValue.round() - keyOfTopNote;
  }

  if (keyOfBottomNote + resolvedDelta < minKeyValue) {
    resolvedDelta = minKeyValue.round() - keyOfBottomNote;
  }

  if (requireExactDelta && resolvedDelta != requestedDelta) {
    return 0;
  }

  return resolvedDelta;
}

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

  ProjectEntityIdAllocator get idAllocator =>
      ServiceRegistry.forProject(project.id).idAllocator;

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

  void onEnter(PointerEnterEvent event) {
    stateMachine.onEnter(event);
  }

  void onExit(PointerExitEvent event) {
    stateMachine.onExit(event);
  }

  void onHover(PointerHoverEvent event) {
    stateMachine.onHover(event);
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
    Snap? snap,
    double minPixelsPerSection = minorMinPixels,
  }) {
    final pattern = requireActivePattern();

    return getDivisionChanges(
      viewWidthInPixels: viewWidthInPixels,
      minPixelsPerSection: minPixelsPerSection,
      snap: snap ?? AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: pattern.timeSignatureChanges,
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
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
          idAllocator: idAllocator,
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

  List<NoteModel> _getSelectedNotes(PatternModel pattern) {
    final selectedNoteIds = viewModel.selectedNotes.nonObservableInner;

    return pattern.notes.values
        .where((note) => selectedNoteIds.contains(note.id))
        .toList(growable: false);
  }

  int _copyAnchorOffset(List<NoteModel> notes) {
    var anchorOffset = notes.first.offset;

    for (final note in notes.skip(1)) {
      if (note.offset < anchorOffset) {
        anchorOffset = note.offset;
      }
    }

    return anchorOffset;
  }

  int? _playbackStartPasteAnchorOffset() {
    if (project.sequence.activeTransportSequenceID !=
        project.sequence.activePatternID) {
      return null;
    }

    final playbackStartPosition = project.sequence.playbackStartPosition;
    if (playbackStartPosition < viewModel.timeRange.start ||
        playbackStartPosition >= viewModel.timeRange.end) {
      return null;
    }

    return playbackStartPosition < 0 ? 0 : playbackStartPosition;
  }

  int _visibleStartPasteAnchorOffset() {
    final visibleStart = viewModel.timeRange.start;
    final rawTime = visibleStart <= 0 ? 0 : visibleStart.ceil();
    final viewWidth = stateMachine.data.viewSize.width;

    return snapTimeInActivePattern(
      rawTime: rawTime,
      viewWidthInPixels: viewWidth < 1 ? 1 : viewWidth,
      ceil: true,
    );
  }

  int _pasteAnchorOffset() {
    return _playbackStartPasteAnchorOffset() ??
        _visibleStartPasteAnchorOffset();
  }

  bool copySelected() {
    final pattern = activePatternOrNull;
    if (viewModel.selectedNotes.isEmpty || pattern == null) {
      return false;
    }

    final selectedNotes = _getSelectedNotes(pattern);
    if (selectedNotes.isEmpty) {
      return false;
    }

    ServiceRegistry.clipboard.set(
      NotesClipboardContent(
        anchorOffset: _copyAnchorOffset(selectedNotes),
        notes: selectedNotes,
      ),
    );

    return true;
  }

  void cutSelected() {
    if (!copySelected()) {
      return;
    }

    deleteSelected();
  }

  void pasteNotes() {
    final pattern = activePatternOrNull;
    final content = ServiceRegistry.clipboard.get<NotesClipboardContent>();
    if (pattern == null || content == null) {
      return;
    }

    final newAnchorOffset = _pasteAnchorOffset();

    clearPreviewState();

    final notes = content.reconstruct(
      idAllocator: idAllocator,
      newAnchorOffset: newAnchorOffset,
    );

    if (notes.isEmpty) {
      return;
    }

    project.startUndoGroup();
    for (final note in notes) {
      project.execute(AddNoteCommand(patternID: pattern.id, note: note));
    }
    project.commitUndoGroup();

    viewModel.selectedNotes = ObservableSet.of(
      notes.map((note) => note.id).toSet(),
    );
  }

  /// Moves selected notes vertically by [requestedDelta] keys.
  void transposeSelectedNotes(
    int requestedDelta, {
    bool requireExactDelta = false,
  }) {
    final pattern = activePatternOrNull;
    if (activeInteractionFamily != null ||
        requestedDelta == 0 ||
        viewModel.selectedNotes.isEmpty ||
        pattern == null) {
      return;
    }

    final selectedNoteIds = viewModel.selectedNotes.nonObservableInner;
    final selectedNotes = pattern.notes.values
        .where((note) => selectedNoteIds.contains(note.id))
        .toList(growable: false);

    if (selectedNotes.isEmpty) {
      return;
    }

    var keyOfTopNote = selectedNotes.first.key;
    var keyOfBottomNote = selectedNotes.first.key;
    for (final note in selectedNotes.skip(1)) {
      if (note.key > keyOfTopNote) {
        keyOfTopNote = note.key;
      }

      if (note.key < keyOfBottomNote) {
        keyOfBottomNote = note.key;
      }
    }

    final keyDelta = resolvePianoRollKeyDelta(
      requestedDelta: requestedDelta,
      keyOfTopNote: keyOfTopNote,
      keyOfBottomNote: keyOfBottomNote,
      requireExactDelta: requireExactDelta,
    );

    if (keyDelta == 0) {
      return;
    }

    clearPreviewState();

    project.execute(
      MoveNotesCommand(
        patternID: pattern.id,
        noteMoves: selectedNotes
            .map((note) {
              return (
                noteID: note.id,
                oldOffset: note.offset,
                newOffset: note.offset,
                oldKey: note.key,
                newKey: note.key + keyDelta,
              );
            })
            .toList(growable: false),
      ),
    );
  }

  void _nudgeSelectedNotesInTime({
    required int direction,
    required List<DivisionChange> divisionChanges,
  }) {
    int resolveNudgeDelta({required int startOfFirstNote}) {
      assert(direction == -1 || direction == 1);
      if (direction != -1 && direction != 1) {
        return 0;
      }

      final step = getSnapSizeAtAbsoluteTime(
        absoluteTime: direction > 0 ? startOfFirstNote : startOfFirstNote - 1,
        divisionChanges: divisionChanges,
      );
      final requestedDelta = direction * step;

      if (startOfFirstNote + requestedDelta < 0) {
        return -startOfFirstNote;
      }

      return requestedDelta;
    }

    final pattern = activePatternOrNull;
    if (activeInteractionFamily != null ||
        viewModel.selectedNotes.isEmpty ||
        pattern == null) {
      return;
    }

    final selectedNoteIds = viewModel.selectedNotes.nonObservableInner;
    final selectedNotes = pattern.notes.values
        .where((note) => selectedNoteIds.contains(note.id))
        .toList(growable: false);

    if (selectedNotes.isEmpty) {
      return;
    }

    var startOfFirstNote = selectedNotes.first.offset;
    for (final note in selectedNotes.skip(1)) {
      if (note.offset < startOfFirstNote) {
        startOfFirstNote = note.offset;
      }
    }

    final timeDelta = resolveNudgeDelta(startOfFirstNote: startOfFirstNote);

    if (timeDelta == 0) {
      return;
    }

    clearPreviewState();

    project.execute(
      MoveNotesCommand(
        patternID: pattern.id,
        noteMoves: selectedNotes
            .map((note) {
              return (
                noteID: note.id,
                oldOffset: note.offset,
                newOffset: note.offset + timeDelta,
                oldKey: note.key,
                newKey: note.key,
              );
            })
            .toList(growable: false),
      ),
    );
  }

  void nudgeSelectedNotesByCurrentSnap(int direction) {
    if (activePatternOrNull == null) {
      return;
    }

    _nudgeSelectedNotesInTime(
      direction: direction,
      divisionChanges: divisionChangesForPatternView(
        viewWidthInPixels: stateMachine.data.viewSize.width,
      ),
    );
  }

  void nudgeSelectedNotesByBar(int direction) {
    if (activePatternOrNull == null) {
      return;
    }

    _nudgeSelectedNotesInTime(
      direction: direction,
      divisionChanges: divisionChangesForPatternView(
        viewWidthInPixels: stateMachine.data.viewSize.width,
        snap: BarSnap(),
        minPixelsPerSection: 0,
      ),
    );
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
