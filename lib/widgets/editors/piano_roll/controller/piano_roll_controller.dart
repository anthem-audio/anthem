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
    _clearActiveInteractionRoute();
    liveNotes.removeAll();
    stateMachine.dispose();
  }

  @visibleForTesting
  PianoRollInteractionFamily? get activeInteractionFamily =>
      stateMachine.data.activeInteractionFamily;

  PianoRollInteractionFamily? classifyPointerDownInteraction({
    required int buttons,
    required bool ctrlPressed,
    required bool isResizeHandle,
    required Id? realNoteUnderCursorId,
  }) {
    if (project.sequence.activePatternID == null) {
      return null;
    }

    final isPrimaryClick = buttons & kPrimaryMouseButton == kPrimaryMouseButton;
    final isSecondaryClick =
        buttons & kSecondaryMouseButton == kSecondaryMouseButton;

    if (isPrimaryClick && viewModel.tool != EditorTool.eraser) {
      if (ctrlPressed || viewModel.tool == EditorTool.select) {
        return PianoRollInteractionFamily.selectionBox;
      }

      if (isResizeHandle && viewModel.tool == EditorTool.pencil) {
        return PianoRollInteractionFamily.resizeNotes;
      }

      if (realNoteUnderCursorId != null) {
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
    stateMachine.data.clearInteractionSession();
  }

  void pointerDown(PianoRollPointerDownEvent event) {
    stateMachine.onAdaptedPointerDown(event);
  }

  void pointerMove(PianoRollPointerMoveEvent event) {
    stateMachine.onAdaptedPointerMove(event);
  }

  void pointerUp(PianoRollPointerUpEvent event) {
    stateMachine.onAdaptedPointerUp(event);
  }

  void onRenderedViewMetricsChanged({
    required Size viewSize,
    required double timeViewStart,
    required double timeViewEnd,
    required double keyHeight,
    required double keyValueAtTop,
  }) {
    stateMachine.onRenderedViewMetricsChanged(
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

  PianoRollTransientNote? createTransientNoteFromPointerDown({
    required double key,
    required double offset,
    required double viewWidthInPixels,
    required bool altPressed,
  }) {
    viewModel.selectedNotes.clear();

    final eventTime = offset.floor();
    if (eventTime < 0) {
      return null;
    }

    final targetTime = altPressed
        ? eventTime
        : snapTimeInActivePattern(
            rawTime: eventTime,
            viewWidthInPixels: viewWidthInPixels,
          );

    return PianoRollTransientNote(
      id: getId(),
      key: key.floor(),
      velocity: viewModel.cursorNoteVelocity,
      length: viewModel.cursorNoteLength,
      offset: targetTime,
      pan: viewModel.cursorNotePan,
    );
  }

  NoteModel createCommittedNoteFromTransient(PianoRollTransientNote note) {
    return NoteModel(
      key: note.key,
      velocity: note.velocity,
      length: note.length,
      offset: note.offset,
      pan: note.pan,
    )..id = note.id;
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
    required double pointerOffset,
    required NoteModel noteUnderCursor,
    required Iterable<NoteModel> notesToMove,
    required bool isSelectionMove,
    required bool didDuplicateOnPointerDown,
    required Set<Id> duplicatedNoteIds,
    required Set<Id> movingTransientNoteIds,
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
    final lengths = <Id, Time>{};
    final velocities = <Id, double>{};
    final pans = <Id, double>{};
    var startOfFirstNote = maxSafeIntWeb;
    var keyOfTopNote = 0;
    var keyOfBottomNote = maxSafeIntWeb;

    for (final note in movingNotes) {
      startTimes[note.id] = note.offset;
      startKeys[note.id] = note.key;
      lengths[note.id] = note.length;
      velocities[note.id] = note.velocity;
      pans[note.id] = note.pan;
      startOfFirstNote = min(startOfFirstNote, note.offset);
      keyOfTopNote = max(keyOfTopNote, note.key);
      keyOfBottomNote = min(keyOfBottomNote, note.key);
    }

    return PianoRollMoveNotesSessionData(
      noteUnderCursor: noteUnderCursor,
      timeOffset: pointerOffset - noteUnderCursor.offset,
      noteOffset: 0.5,
      startTimes: startTimes,
      startKeys: startKeys,
      lengths: lengths,
      velocities: velocities,
      pans: pans,
      startOfFirstNote: startOfFirstNote,
      keyOfTopNote: keyOfTopNote,
      keyOfBottomNote: keyOfBottomNote,
      isSelectionMove: isSelectionMove,
      didDuplicateOnPointerDown: didDuplicateOnPointerDown,
      duplicatedNoteIds: duplicatedNoteIds,
      movingTransientNoteIds: movingTransientNoteIds,
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

  Map<Id, PianoRollMoveNotePreview> createInitialMoveNotesPreview(
    PianoRollMoveNotesSessionData sessionData,
  ) {
    return Map<Id, PianoRollMoveNotePreview>.fromEntries(
      sessionData.startTimes.keys.map((noteId) {
        return MapEntry(noteId, (
          key: sessionData.startKeys[noteId]!,
          offset: sessionData.startTimes[noteId]!,
        ));
      }),
    );
  }

  Map<Id, PianoRollMoveNotePreview> resolveMoveNotesSessionPreview({
    required double key,
    required double offset,
    required double viewWidthInPixels,
    required bool altPressed,
    required bool shiftPressed,
    required bool ctrlPressed,
    required PianoRollMoveNotesSessionData sessionData,
  }) {
    final targetKey = key - sessionData.noteOffset;
    final targetOffset = offset - sessionData.timeOffset;
    var snappedOffset = targetOffset.floor();

    if (!altPressed) {
      snappedOffset = snapTimeInActivePattern(
        rawTime: targetOffset.floor(),
        viewWidthInPixels: viewWidthInPixels,
        round: true,
        startTime: sessionData.startTimes[sessionData.noteUnderCursor.id]!,
      );
    }

    var timeOffsetFromEventStart =
        snappedOffset - sessionData.startTimes[sessionData.noteUnderCursor.id]!;
    var keyOffsetFromEventStart =
        targetKey.round() -
        sessionData.startKeys[sessionData.noteUnderCursor.id]!;

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

    return Map<Id, PianoRollMoveNotePreview>.fromEntries(
      sessionData.startTimes.keys.map((noteId) {
        return MapEntry(noteId, (
          key:
              sessionData.startKeys[noteId]! +
              (shiftPressed ? 0 : keyOffsetFromEventStart),
          offset:
              sessionData.startTimes[noteId]! +
              (!shiftPressed && ctrlPressed ? 0 : timeOffsetFromEventStart),
        ));
      }),
    );
  }

  void syncLivePreviewForMoveSession({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    final notePreview = preview[sessionData.noteUnderCursor.id];
    if (notePreview == null) {
      return;
    }

    if (!liveNotes.hasNoteForKey(notePreview.key)) {
      liveNotes.removeAll();
      liveNotes.addNote(
        key: notePreview.key,
        velocity: sessionData.noteUnderCursor.velocity,
        pan: sessionData.noteUnderCursor.pan,
      );
    }
  }

  MoveNotesCommand buildMoveNotesCommand({
    required PianoRollMoveNotesSessionData sessionData,
    required Map<Id, PianoRollMoveNotePreview> preview,
  }) {
    return MoveNotesCommand(
      patternID: requireActivePattern().id,
      noteMoves: preview.entries
          .where(
            (entry) => !sessionData.movingTransientNoteIds.contains(entry.key),
          )
          .map((entry) {
            return (
              noteID: entry.key,
              oldOffset: sessionData.startTimes[entry.key]!,
              newOffset: entry.value.offset,
              oldKey: sessionData.startKeys[entry.key]!,
              newKey: entry.value.key,
            );
          })
          .toList(growable: false),
    );
  }

  PianoRollResizeNotesSessionData createResizeNotesSessionData({
    required double pointerStartOffset,
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
      pointerStartOffset: pointerStartOffset,
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

  Map<Id, PianoRollResizeNotePreview> createInitialResizeNotesPreview(
    PianoRollResizeNotesSessionData sessionData,
  ) {
    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.startLengths.keys.map((noteId) {
        return MapEntry(noteId, (length: sessionData.startLengths[noteId]!));
      }),
    );
  }

  Map<Id, PianoRollResizeNotePreview> resolveResizeNotesSessionPreview({
    required double currentOffset,
    required double viewWidthInPixels,
    required bool altPressed,
    required PianoRollResizeNotesSessionData sessionData,
  }) {
    var snappedOriginalTime = sessionData.pointerStartOffset.floor();
    var snappedEventTime = currentOffset.floor();

    final divisionChanges = divisionChangesForPatternView(
      viewWidthInPixels: viewWidthInPixels,
    );

    if (!altPressed) {
      snappedOriginalTime = snapTimeInActivePattern(
        rawTime: sessionData.pointerStartOffset.floor(),
        viewWidthInPixels: viewWidthInPixels,
        round: true,
      );

      snappedEventTime = snapTimeInActivePattern(
        rawTime: currentOffset.floor(),
        viewWidthInPixels: viewWidthInPixels,
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
    if (!altPressed &&
        sessionData.smallestStartLength + diff < snapAtSmallestNoteStart) {
      final snapCount =
          ((snapAtSmallestNoteStart -
                      (sessionData.smallestStartLength + diff)) /
                  snapAtSmallestNoteStart)
              .ceil();
      diff += snapCount * snapAtSmallestNoteStart;
    }

    if (altPressed) {
      final newSmallestNoteSize = sessionData.smallestStartLength + diff;
      if (newSmallestNoteSize < 1) {
        diff += 1 - newSmallestNoteSize;
      }
    }

    return Map<Id, PianoRollResizeNotePreview>.fromEntries(
      sessionData.startLengths.keys.map((noteId) {
        return MapEntry(noteId, (
          length: sessionData.startLengths[noteId]! + diff,
        ));
      }),
    );
  }

  ResizeNotesCommand buildResizeNotesCommand({
    required PianoRollResizeNotesSessionData sessionData,
    required Map<Id, PianoRollResizeNotePreview> preview,
  }) {
    return ResizeNotesCommand(
      patternID: requireActivePattern().id,
      noteResizes: preview.entries
          .map((entry) {
            return (
              noteID: entry.key,
              oldLength: sessionData.startLengths[entry.key]!,
              newLength: entry.value.length,
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
