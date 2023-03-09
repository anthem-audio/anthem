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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
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

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  GeneratorRowCubit({
    required ID projectID,
    required ID? patternID,
    required ID generatorID,
  }) : super(
          (() {
            final project = AnthemStore.instance.projects[projectID]!;

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
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  _onModelChanged(List<StateChange> changes) {
    var updateActivePattern = false;
    var updateNotes = false;

    for (final change in changes) {
      change.whenOrNull(
        project: (change) {
          change.mapOrNull(
            activePatternChanged: (change) => updateActivePattern = true,
          );
        },
        note: (change) {
          if (change.patternID == state.patternID &&
              change.generatorID == state.generatorID) {
            updateNotes = true;
          }
        },
      );
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
