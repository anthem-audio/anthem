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
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
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
  PianoRollInteractionFamily? _activeInteractionFamily;

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
      _activeInteractionFamily;

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
    _activeInteractionFamily = null;
  }

  void pointerDown(PianoRollPointerDownEvent event) {
    final family = classifyPointerDownInteraction(event);
    if (family == null) {
      _clearActiveInteractionRoute();
      return;
    }

    _activeInteractionFamily = family;
    stateMachine.onAdaptedPointerDown(event);
  }

  void pointerMove(PianoRollPointerMoveEvent event) {
    if (_activeInteractionFamily == null) {
      return;
    }

    stateMachine.onAdaptedPointerMove(event);
  }

  void pointerUp(PianoRollPointerUpEvent event) {
    if (_activeInteractionFamily == null) {
      return;
    }

    try {
      stateMachine.onAdaptedPointerUp(event);
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

  NoteModel? createNoteFromPointerDown({
    required PianoRollPointerDownEvent event,
  }) {
    viewModel.selectedNotes.clear();

    final eventTime = event.offset.floor();
    if (eventTime < 0) {
      return null;
    }

    final targetTime = event.keyboardModifiers.alt
        ? eventTime
        : snapTimeInActivePattern(
            rawTime: eventTime,
            viewWidthInPixels: event.pianoRollSize.width,
          );

    project.startUndoGroup();

    return addNoteToActivePattern(
      key: event.key.floor(),
      velocity: viewModel.cursorNoteVelocity,
      length: viewModel.cursorNoteLength,
      offset: targetTime,
      pan: viewModel.cursorNotePan,
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

  /// Records the parameters of this note so the next placed note has the same
  /// parameters.
  void setCursorNoteParameters(NoteModel note) {
    viewModel.cursorNoteLength = note.length;
    viewModel.cursorNoteVelocity = note.velocity;
    viewModel.cursorNotePan = note.pan;
  }

  PianoRollMoveNotesSessionData createMoveNotesSessionData({
    required PianoRollPointerDownEvent event,
    required NoteModel noteUnderCursor,
    required Iterable<NoteModel> notesToMove,
    required bool isSelectionMove,
    required bool didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
  }) {
    final movingNotesById = <Id, NoteModel>{
      noteUnderCursor.id: noteUnderCursor,
    };
    for (final note in notesToMove) {
      movingNotesById[note.id] = note;
    }

    final movingNotes = movingNotesById.values.toList(growable: false);
    if (movingNotes.isEmpty) {
      throw StateError('Move session requires at least one note.');
    }

    final startTimes = <Id, Time>{};
    final startKeys = <Id, int>{};
    var startOfFirstNote = maxSafeIntWeb;
    var keyOfTopNote = 0;
    var keyOfBottomNote = maxSafeIntWeb;

    for (final note in movingNotes) {
      startTimes[note.id] = note.offset;
      startKeys[note.id] = note.key;
      startOfFirstNote = min(startOfFirstNote, note.offset);
      keyOfTopNote = max(keyOfTopNote, note.key);
      keyOfBottomNote = min(keyOfBottomNote, note.key);
    }

    return PianoRollMoveNotesSessionData(
      noteUnderCursor: noteUnderCursor,
      timeOffset: event.offset - noteUnderCursor.offset,
      noteOffset: 0.5,
      startTimes: startTimes,
      startKeys: startKeys,
      startOfFirstNote: startOfFirstNote,
      keyOfTopNote: keyOfTopNote,
      keyOfBottomNote: keyOfBottomNote,
      isSelectionMove: isSelectionMove,
      didDuplicateOnPointerDown: didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
    );
  }

  List<NoteModel> notesForMoveSession(
    PianoRollMoveNotesSessionData sessionData,
  ) {
    final movingNoteIds = sessionData.startTimes.keys.toSet();

    return requireActivePattern().notes
        .where((note) {
          return movingNoteIds.contains(note.id);
        })
        .toList(growable: false);
  }

  void applyMoveNotesSessionUpdate({
    required PianoRollPointerMoveEvent event,
    required PianoRollMoveNotesSessionData sessionData,
  }) {
    final notes = notesForMoveSession(sessionData);
    if (notes.isEmpty) {
      return;
    }

    final key = event.key - sessionData.noteOffset;
    final offset = event.offset - sessionData.timeOffset;
    var snappedOffset = offset.floor();

    if (!event.keyboardModifiers.alt) {
      snappedOffset = snapTimeInActivePattern(
        rawTime: offset.floor(),
        viewWidthInPixels: event.pianoRollSize.width,
        round: true,
        startTime: sessionData.startTimes[sessionData.noteUnderCursor.id]!,
      );
    }

    var timeOffsetFromEventStart =
        snappedOffset - sessionData.startTimes[sessionData.noteUnderCursor.id]!;
    var keyOffsetFromEventStart =
        key.round() - sessionData.startKeys[sessionData.noteUnderCursor.id]!;

    if (sessionData.startOfFirstNote + timeOffsetFromEventStart < 0) {
      timeOffsetFromEventStart = -sessionData.startOfFirstNote;
    }

    if (sessionData.keyOfTopNote + keyOffsetFromEventStart > maxKeyValue) {
      keyOffsetFromEventStart = maxKeyValue.round() - sessionData.keyOfTopNote;
    }

    if (sessionData.keyOfBottomNote + keyOffsetFromEventStart < minKeyValue) {
      keyOffsetFromEventStart =
          minKeyValue.round() - sessionData.keyOfBottomNote;
    }

    for (final note in notes) {
      final shift = event.keyboardModifiers.shift;
      final ctrl = event.keyboardModifiers.ctrl;
      note.key =
          sessionData.startKeys[note.id]! +
          (shift ? 0 : keyOffsetFromEventStart);
      note.offset =
          sessionData.startTimes[note.id]! +
          (!shift && ctrl ? 0 : timeOffsetFromEventStart);
    }

    final noteUnderCursor = sessionData.noteUnderCursor;
    if (!liveNotes.hasNoteForKey(noteUnderCursor.key)) {
      liveNotes.removeAll();
      liveNotes.addNote(
        key: noteUnderCursor.key,
        velocity: noteUnderCursor.velocity,
        pan: noteUnderCursor.pan,
      );
    }
  }

  MoveNotesCommand buildMoveNotesCommand({
    required PianoRollMoveNotesSessionData sessionData,
  }) {
    final notes = notesForMoveSession(sessionData);

    return MoveNotesCommand(
      patternID: requireActivePattern().id,
      noteMoves: notes
          .map((note) {
            return (
              noteID: note.id,
              oldOffset: sessionData.startTimes[note.id]!,
              newOffset: note.offset,
              oldKey: sessionData.startKeys[note.id]!,
              newKey: note.key,
            );
          })
          .toList(growable: false),
    );
  }

  PianoRollResizeNotesSessionData createResizeNotesSessionData({
    required PianoRollPointerDownEvent event,
    required NoteModel pressedNote,
    required Iterable<NoteModel> notesToResize,
    required bool isSelectionResize,
  }) {
    final resizingNotesById = <Id, NoteModel>{pressedNote.id: pressedNote};
    for (final note in notesToResize) {
      resizingNotesById[note.id] = note;
    }

    final resizingNotes = resizingNotesById.values.toList(growable: false);
    if (resizingNotes.isEmpty) {
      throw StateError('Resize session requires at least one note.');
    }

    var smallestNote = resizingNotes.first;
    final startLengths = <Id, Time>{};

    for (final note in resizingNotes) {
      startLengths[note.id] = note.length;
      if (note.length < smallestNote.length) {
        smallestNote = note;
      }
    }

    return PianoRollResizeNotesSessionData(
      pointerStartOffset: event.offset,
      startLengths: startLengths,
      smallestStartLength: smallestNote.length,
      smallestNote: smallestNote.id,
      pressedNote: pressedNote,
      isSelectionResize: isSelectionResize,
    );
  }

  List<NoteModel> notesForResizeSession(
    PianoRollResizeNotesSessionData sessionData,
  ) {
    final resizingNoteIds = sessionData.startLengths.keys.toSet();

    return requireActivePattern().notes
        .where((note) => resizingNoteIds.contains(note.id))
        .toList(growable: false);
  }

  void applyResizeNotesSessionUpdate({
    required PianoRollPointerMoveEvent event,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    final notes = notesForResizeSession(sessionData);
    if (notes.isEmpty) {
      return;
    }

    var snappedOriginalTime = sessionData.pointerStartOffset.floor();
    var snappedEventTime = event.offset.floor();

    final divisionChanges = divisionChangesForPatternView(
      viewWidthInPixels: event.pianoRollSize.width,
    );

    if (!event.keyboardModifiers.alt) {
      snappedOriginalTime = snapTimeInActivePattern(
        rawTime: sessionData.pointerStartOffset.floor(),
        viewWidthInPixels: event.pianoRollSize.width,
        round: true,
      );

      snappedEventTime = snapTimeInActivePattern(
        rawTime: event.offset.floor(),
        viewWidthInPixels: event.pianoRollSize.width,
        round: true,
      );
    }

    late int snapAtSmallestNoteStart;

    final offsetOfSmallestNoteAtStart =
        sessionData.startLengths[sessionData.smallestNote]!;

    for (var i = 0; i < divisionChanges.length; i++) {
      if (i < divisionChanges.length - 1 &&
          divisionChanges[i + 1].offset <= offsetOfSmallestNoteAtStart) {
        continue;
      }

      snapAtSmallestNoteStart = divisionChanges[i].divisionSnapSize;
      break;
    }

    var diff = snappedEventTime - snappedOriginalTime;

    // Preserve the legacy minimum-length behavior exactly during migration.
    if (!event.keyboardModifiers.alt &&
        sessionData.smallestStartLength + diff < snapAtSmallestNoteStart) {
      final snapCount =
          ((snapAtSmallestNoteStart -
                      (sessionData.smallestStartLength + diff)) /
                  snapAtSmallestNoteStart)
              .ceil();
      diff += snapCount * snapAtSmallestNoteStart;
    }

    if (event.keyboardModifiers.alt) {
      final newSmallestNoteSize = sessionData.smallestStartLength + diff;
      if (newSmallestNoteSize < 1) {
        diff += 1 - newSmallestNoteSize;
      }
    }

    for (final note in notes) {
      note.length = sessionData.startLengths[note.id]! + diff;
    }

    setCursorNoteParameters(sessionData.pressedNote);
  }

  ResizeNotesCommand buildResizeNotesCommand({
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    final notes = notesForResizeSession(sessionData);

    return ResizeNotesCommand(
      patternID: requireActivePattern().id,
      noteResizes: notes
          .map((note) {
            return (
              noteID: note.id,
              oldLength: sessionData.startLengths[note.id]!,
              newLength: note.length,
            );
          })
          .toList(growable: false),
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
      notes: pattern.notes.where(
        (note) => viewModel.selectedNotes.contains(note.id),
      ),
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
