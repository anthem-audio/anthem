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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
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
      : super(PatternDetailViewState(projectID: projectID)) {
    project = Store.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    // var didSomeItemChange = false;

    for (final change in changes) {
      // if (change is SomeChange) {
      //   didSomeItemChange = true;
      // }
    }

    PatternDetailViewState? newState;

    // if (didSomeItemChange) {
    //   newState = (newState ?? state).copyWith(
    //     ...
    //   );
    // }

    if (newState != null) {
      emit(newState);
    }
  }
}
