/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'dart:async';
import 'dart:convert';

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/note.dart';
import 'package:anthem/model/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:optional/optional_internal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'piano_roll_state.dart';
part 'piano_roll_cubit.freezed.dart';

class PianoRollCubit extends Cubit<PianoRollState> {
  // ignore: unused_field
  late final StreamSubscription<StateChange> _updateActivePatternSub;
  late final StreamSubscription<GeneratorStateChange>
      // ignore: unused_field
      _updateActiveInstrumentSub;
  late final ProjectModel project;

  PianoRollCubit({required int projectID})
      : super(
          PianoRollState(
            projectID: projectID,
            ticksPerQuarter:
                Store.instance.projects[projectID]!.song.ticksPerQuarter,
            notes: const [],
          ),
        ) {
    project = Store.instance.projects[projectID]!;
    _updateActivePatternSub = project.stateChangeStream
        .where((event) =>
            event is ActivePatternSet ||
            event is NoteAdded ||
            event is NoteDeleted ||
            event is NoteMoved ||
            event is NoteResized ||
            event is ActiveGeneratorSet)
        .listen(_updateActivePattern);
    _updateActiveInstrumentSub = project.stateChangeStream
        .where((event) => event is ActiveGeneratorSet)
        .map((event) => event as ActiveGeneratorSet)
        .listen(_updateActiveInstrument);
  }

  List<LocalNote> _getLocalNotes(int patternID, int generatorID) {
    return (project.song.patterns[patternID]!.notes[generatorID] ?? [])
        .map((modelNote) => LocalNote.fromNote(modelNote))
        .toList();
  }

  _updateActivePattern(StateChange change) {
    final patternID = project.song.activePatternID;
    final pattern = project.song.patterns[patternID];

    emit(state.copyWith(
      patternID: patternID,
      notes: pattern == null || state.activeInstrumentID == null
          ? []
          : _getLocalNotes(pattern.id, state.activeInstrumentID!),
    ));
  }

  _updateActiveInstrument(GeneratorStateChange change) {
    final pattern = project.song.patterns[state.patternID];

    emit(state.copyWith(
      activeInstrumentID: project.song.activeGeneratorID,
      notes: state.patternID == null || project.song.activeGeneratorID == null
          ? []
          : _getLocalNotes(state.patternID!, project.song.activeGeneratorID!),
    ));
  }

  NoteModel? _getNote(int? instrumentID, int noteID) {
    final pattern = project.song.patterns[state.patternID];
    final noteList = pattern?.notes[instrumentID];
    NoteModel? note;
    try {
      note = noteList?.firstWhere((note) => note.id == noteID);
    } catch (ex) {
      note = null;
    }
  }

  void addNote({
    required int? instrumentID,
    required int key,
    required int velocity,
    required int length,
    required int offset,
  }) {
    if (state.patternID == null || instrumentID == null) {
      return;
    }

    final data = {};

    data["id"] = getID();
    data["key"] = key;
    data["velocity"] = velocity;
    data["length"] = length;
    data["offset"] = offset;

    project.execute(AddNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      note: NoteModel(
        key: key,
        velocity: velocity,
        length: length,
        offset: offset,
      ),
    ));
  }

  void removeNote({required int? instrumentID, required int noteID}) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    project.execute(DeleteNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      note: note,
    ));
  }

  void moveNote({
    required int? instrumentID,
    required int noteID,
    required int key,
    required int offset,
  }) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    return project.execute(MoveNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      noteID: noteID,
      oldKey: note.key,
      newKey: key,
      oldOffset: note.offset,
      newOffset: offset,
    ));
  }

  void resizeNote({
    required int? instrumentID,
    required int noteID,
    required int length,
  }) {
    final note = _getNote(instrumentID, noteID);

    if (state.patternID == null || instrumentID == null || note == null) {
      return;
    }

    return project.execute(ResizeNoteCommand(
      project: project,
      patternID: state.patternID!,
      generatorID: instrumentID,
      noteID: noteID,
      oldLength: note.length,
      newLength: length,
    ));
  }

  void mutateLocalNotes(
      {required int? instrumentID,
      required Function(List<LocalNote> notes) mutator}) {
    if (state.patternID == null || instrumentID == null) {
      return;
    }

    final newNotes = [...state.notes];

    mutator(newNotes);

    emit(PianoRollState(
      activeInstrumentID: state.activeInstrumentID,
      patternID: state.patternID,
      projectID: state.projectID,
      ticksPerQuarter: state.ticksPerQuarter,
      notes: newNotes,
    ));
  }
}
