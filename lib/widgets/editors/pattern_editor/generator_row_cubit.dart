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
  final Store _store = Store.instance;

  GeneratorRowCubit({
    required int projectID,
    required int? patternID,
    required int generatorID,
  }) : super(
          GeneratorRowState(
            projectID: projectID,
            patternID: patternID,
            generatorID: generatorID,
            notes: null,
          ),
        ) {
    _updateNotesSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.NoteAdded ||
            event.type == Reply.NoteDeleted ||
            event.type == Reply.ActivePatternSet)
        .listen(_updateNotes);
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

    final notes = _store.projects
          .firstWhere((project) => project.id == state.projectID)
          .song
          .patterns
          .firstWhere((pattern) => pattern.id == state.patternID)
          .generatorNotes[state.generatorID]!
          .notes;

    emit(GeneratorRowState(
      projectID: state.projectID,
      generatorID: state.generatorID,
      patternID: state.patternID,
      notes: notes,
    ));
  }
}
