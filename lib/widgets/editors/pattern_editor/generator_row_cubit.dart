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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/model/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/clip/clip_notes.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:optional/optional_internal.dart';

part 'generator_row_state.dart';

class GeneratorRowCubit extends Cubit<GeneratorRowState> {
  // ignore: unused_field
  late final StreamSubscription<NoteStateChange> _updateNotesSub;
  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _changePatternSub;
  late final ProjectModel project;

  GeneratorRowCubit({
    required int projectID,
    required int? patternID,
    required int generatorID,
  }) : super(
          (() {
            final project = Store.instance.projects[projectID]!;

            var color = const Color(0xFFFFFFFF);

            if (project.instruments[generatorID] != null) {
              color = project.instruments[generatorID]!.color;
            } else if (project.controllers[generatorID] != null) {
              color = project.controllers[generatorID]!.color;
            }

            return GeneratorRowState(
              projectID: project.id,
              generatorID: generatorID,
              pattern: patternID == null
                  ? const Optional.empty()
                  : Optional.ofNullable(project.song.patterns[patternID]),
              color: color,
            );
          })(),
        ) {
    project = Store.instance.projects[projectID]!;
    _updateNotesSub = project.stateChangeStream
        .where((change) => change is NoteAdded || change is NoteDeleted)
        .map((change) => change as NoteStateChange)
        .listen(_updateNotes);
    _changePatternSub = project.stateChangeStream
        .where((change) => change is ActivePatternSet)
        .map((change) => change as PatternStateChange)
        .listen(_changePattern);
  }

  _changePattern(PatternStateChange change) {
    final pattern =
        Optional.ofNullable(project.song.patterns[change.patternID]);

    emit(state.copyWith(
      pattern: pattern,
    ));
  }

  _updateNotes(NoteStateChange change) {
    if (state.pattern.map((pattern) => pattern.id).orElseNull !=
            change.patternID ||
        state.generatorID != change.generatorID) {
      return;
    }

    emit(state.copyWith(
      clipNotes: state.pattern.value.notes[state.generatorID]
          ?.map((note) => ClipNoteModel.fromNoteModel(note))
          .toList(),
    ));
  }
}
