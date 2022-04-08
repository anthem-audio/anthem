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
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pattern_picker_state.dart';
part 'pattern_picker_cubit.freezed.dart';

List<int> getPatternIDs(ProjectModel? project) {
  return [...project?.song.patternOrder ?? []];
}

class PatternPickerCubit extends Cubit<PatternPickerState> {
  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _updatePatternsSub;
  late final ProjectModel project;

  PatternPickerCubit({required int projectID})
      : super(PatternPickerState(
          projectID: projectID,
          patternIDs: getPatternIDs(
            Store.instance.projects[projectID],
          ),
          patternHeight: 50,
        )) {
    project = Store.instance.projects[projectID]!;
    _updatePatternsSub = project.stateChangeStream
        .where((change) => change is PatternAdded || change is PatternDeleted)
        .map((change) => change as PatternStateChange)
        .listen(_updatePatternList);
  }

  _updatePatternList(PatternStateChange change) {
    emit(state.copyWith(patternIDs: getPatternIDs(project)));
  }

  setPatternHeight(double height) {
    emit(state.copyWith(patternHeight: height));
  }

  addPattern(String name) {
    project.execute(
      AddPatternCommand(
        project: project,
        pattern: PatternModel(name),
        index: project.song.patternOrder.length,
      ),
    );
  }
}
