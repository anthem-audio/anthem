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

import 'package:collection/collection.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

import '../../../../commands/state_changes.dart';
import '../../../../model/pattern.dart';
import '../../../../model/project.dart';
import '../../../../model/store.dart';

part 'pattern_picker_state.dart';

List<PatternModel> getPatterns(ProjectModel? project) {
  return project?.song.patternOrder
          .map((patternID) => project.song.patterns[patternID])
          .whereNotNull()
          .toList() ??
      [];
}

class PatternPickerCubit extends Cubit<PatternPickerState> {
  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _updatePatternsSub;
  late final ProjectModel project;

  PatternPickerCubit({required int projectID})
      : super(PatternPickerState(
          projectID: projectID,
          patterns: getPatterns(
            Store.instance.projects[projectID],
          ),
        )) {
    project = Store.instance.projects[projectID]!;
    _updatePatternsSub = project.stateChangeStream
        .where((change) => change is PatternAdded || change is PatternDeleted)
        .map((change) => change as PatternStateChange)
        .listen(_updatePatternList);
  }

  _updatePatternList(PatternStateChange change) {
    emit(state.copyWith(patterns: getPatterns(project)));
  }
}
