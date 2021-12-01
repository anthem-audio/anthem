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

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

part 'generator_row_state.dart';

class GeneratorRowCubit extends Cubit<GeneratorRowState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateNotesSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _changePatternSub;
  final Store _store = Store.instance;

  GeneratorRowCubit({
    required int projectID,
    required int? patternID,
    required int generatorID,
  }) : super(
          (() {
            final project = Store.instance.projects[projectID];

            var color = const Color(0xFFFFFFFF);

            if (project?.instruments[generatorID] != null) {
              color = Color(project!.instruments[generatorID]!.color);
            } else if (project?.controllers[generatorID] != null) {
              color = Color(project!.controllers[generatorID]!.color);
            }

            return GeneratorRowState(
              projectID: projectID,
              patternID: patternID,
              generatorID: generatorID,
              color: color,
              notes: null,
            );
          })(),
        ) {
    _updateNotesSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.NoteAdded || event.type == Reply.NoteDeleted)
        .listen(_updateNotes);
    _changePatternSub = rid.replyChannel.stream
        .where((event) => event.type == Reply.ActivePatternSet)
        .listen(_changePattern);
  }

  List<Note> _getNotes(int patternID) {
    return _store.projects[state.projectID]!.song.patterns[patternID]
            ?.generatorNotes[state.generatorID]?.notes ??
        [];
  }

  _changePattern(PostedReply reply) {
    final patternID = _store.projects[state.projectID]!.song.activePatternId;

    final notes = _getNotes(patternID);

    emit(GeneratorRowState(
      projectID: state.projectID,
      generatorID: state.generatorID,
      patternID: patternID,
      notes: notes,
      color: state.color,
    ));
  }

  _updateNotes(PostedReply reply) {
    if (reply.type == Reply.NoteAdded || reply.type == Reply.NoteDeleted) {
      Map response = jsonDecode(reply.data!);

      final patternID = response["patternID"];
      final generatorID = response["generatorID"];

      if (state.patternID != patternID || state.generatorID != generatorID) {
        return;
      }
    }

    final notes = _getNotes(state.patternID!);

    emit(GeneratorRowState(
      projectID: state.projectID,
      generatorID: state.generatorID,
      patternID: state.patternID,
      notes: notes,
      color: state.color,
    ));
  }
}
