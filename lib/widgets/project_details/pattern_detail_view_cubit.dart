/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pattern_detail_view_state.dart';
part 'pattern_detail_view_cubit.freezed.dart';

class PatternDetailViewCubit extends Cubit<PatternDetailViewState> {
  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  PatternDetailViewCubit({required String projectID})
      : super(
          (() {
            String? patternID;
            final project = AnthemStore.instance.projects[projectID]!;
            if (project.selectedDetailView is PatternDetailViewKind) {
              patternID = (project.selectedDetailView as PatternDetailViewKind)
                  .patternID;
            }

            return PatternDetailViewState(
              projectID: projectID,
              patternID: patternID,
              patternName: project.song.patterns[patternID]?.name ?? "",
            );
          })(),
        ) {
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var didActiveDetailViewChange = false;

    for (final change in changes) {
      change.whenOrNull(project: (projectChange) {
        projectChange.mapOrNull(
            selectedDetailViewChanged: (change) =>
                didActiveDetailViewChange = true);
      });
    }

    PatternDetailViewState? newState;

    if (didActiveDetailViewChange &&
        project.selectedDetailView is PatternDetailViewKind) {
      final patternID =
          (project.selectedDetailView as PatternDetailViewKind).patternID;

      emit(
        PatternDetailViewState(
          projectID: project.id,
          patternID: patternID,
          patternName: project.song.patterns[patternID]!.name,
        ),
      );

      return;
    }

    if (newState != null) {
      emit(newState);
    }
  }

  void setPatternName(String newName) {
    if (state.patternID == null) return;

    project.execute(
      SetPatternNameCommand(
        project: project,
        patternID: state.patternID!,
        newName: newName,
      ),
    );
  }

  void setPatternColor(AnthemColor newColor) {
    if (state.patternID == null) return;

    project.execute(
      SetPatternColorCommand(
        project: project,
        patternID: state.patternID!,
        newColor: newColor,
      ),
    );
  }
}
