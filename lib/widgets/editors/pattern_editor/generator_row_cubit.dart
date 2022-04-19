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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/clip/clip_notes.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generator_row_state.dart';
part 'generator_row_cubit.freezed.dart';

class GeneratorRowCubit extends Cubit<GeneratorRowState> {
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
              ticksPerQuarter: project.song.ticksPerQuarter,
              generatorID: generatorID,
              patternID: patternID,
              color: color,
            );
          })(),
        ) {
    project = Store.instance.projects[projectID]!;
    project.stateChangeStream.listen(_onModelChanged);
  }

  _onModelChanged(List<StateChange> changes) {
    var updateActivePattern = false;
    var updateNotes = false;

    for (final change in changes) {
      if (change is ActivePatternSet) {
        updateActivePattern = true;
      }

      final isNoteChange = change is NoteAdded || change is NoteDeleted;
      if (isNoteChange) {
        final noteChange = change as NoteStateChange;
        final isRelevant = state.patternID == noteChange.patternID &&
            state.generatorID == noteChange.generatorID;
        if (isRelevant) {
          updateNotes = true;
        }
      }
    }

    GeneratorRowState? newState;

    if (updateActivePattern) {
      final newPatternID = project.song.activePatternID;
      final pattern = project.song.patterns[newPatternID];

      newState = (newState ?? state).copyWith(
        patternID: newPatternID,
        clipNotes: pattern?.notes[state.generatorID]
                ?.map((note) => ClipNoteModel.fromNoteModel(note))
                .toList() ??
            [],
      );
    }

    if (updateNotes) {
      final pattern = project.song.patterns[project.song.activePatternID];

      newState = (newState ?? state).copyWith(
        clipNotes: pattern?.notes[state.generatorID]
                ?.map((note) => ClipNoteModel.fromNoteModel(note))
                .toList() ??
            [],
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }
}
