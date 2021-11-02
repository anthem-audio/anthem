/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:anthem/helpers/get_id.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

part 'piano_roll_state.dart';

class PianoRollCubit extends Cubit<PianoRollState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateActivePatternSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateActiveInstrumentSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateNotesSub;
  final Store _store = Store.instance;

  PianoRollCubit({required int projectID})
      : super(
          PianoRollState(
            projectID: projectID,
            pattern: null,
            ticksPerQuarter:
                Store.instance.projects[projectID]!.song.ticksPerQuarter,
            activeInstrumentID: null,
            notes: [],
          ),
        ) {
    _updateActivePatternSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.ActivePatternSet ||
            event.type == Reply.NoteAdded ||
            event.type == Reply.NoteDeleted ||
            event.type == Reply.ActiveInstrumentSet)
        .listen(_updateActivePattern);
    _updateActiveInstrumentSub = rid.replyChannel.stream
        .where((event) => event.type == Reply.ActiveInstrumentSet)
        .listen(_updateActiveInstrument);
  }

  List<LocalNote> _getLocalNotes(int patternID, int generatorID) {
    return (_store.projects[state.projectID]!.song.patterns[patternID]!
        .generatorNotes[generatorID]?.notes ?? [])
        .map((modelNote) {
      return LocalNote.fromNote(modelNote);
    }).toList();
  }

  _updateActivePattern(PostedReply _reply) {
    final project = _store.projects[state.projectID]!;
    final patternID = project.song.activePatternId;
    Pattern? pattern;
    if (patternID != 0) {
      pattern = project.song.patterns[patternID];
    }

    emit(PianoRollState(
      projectID: state.projectID,
      ticksPerQuarter: state.ticksPerQuarter,
      pattern: pattern,
      activeInstrumentID: state.activeInstrumentID,
      notes: pattern == null || state.activeInstrumentID == null
          ? []
          : _getLocalNotes(patternID, state.activeInstrumentID!),
    ));
  }

  _updateActiveInstrument(PostedReply _reply) {
    final project = _store.projects[state.projectID]!;
    emit(PianoRollState(
      projectID: state.projectID,
      ticksPerQuarter: state.ticksPerQuarter,
      pattern: state.pattern,
      activeInstrumentID: project.song.activeInstrumentId,
      notes: state.pattern == null
          ? []
          : _getLocalNotes(state.pattern!.id, project.song.activeInstrumentId),
    ));
  }

  Future<void> addNote({
    required int? instrumentID,
    required int key,
    required int velocity,
    required int length,
    required int offset,
  }) {
    if (state.pattern == null || instrumentID == null) {
      final completer = Completer();
      completer.complete();
      return completer.future;
    }

    final data = Map();

    data["id"] = getID();
    data["key"] = key;
    data["velocity"] = velocity;
    data["length"] = length;
    data["offset"] = offset;

    return _store.msgAddNote(
        state.projectID, state.pattern!.id, instrumentID, json.encode(data));
  }
}
