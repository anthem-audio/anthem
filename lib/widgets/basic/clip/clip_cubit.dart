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

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

import '../../../commands/state_changes.dart';
import '../../../model/pattern.dart';
import '../../../model/project.dart';
import '../../../model/store.dart';

part 'clip_state.dart';

class ClipCubit extends Cubit<ClipState> {
  // TODO: Allow this to optionally take a ClipModel
  late final ProjectModel project;

  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _updatePatternSub;

  ClipCubit({required int projectID, required int patternID})
      : super(
          ClipState(
            pattern:
                Store.instance.projects[projectID]!.song.patterns[patternID]!,
          ),
        ) {
    project = Store.instance.projects[projectID]!;
    _updatePatternSub = project.stateChangeStream
        .where((change) =>
            change is NoteStateChange &&
            change.patternID == patternID)
        .map((change) => change as PatternStateChange)
        .listen(_updatePattern);
  }

  _updatePattern(PatternStateChange change) {
    emit(state.copyWith());
  }
}
