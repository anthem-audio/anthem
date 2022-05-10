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
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:anthem/helpers/id.dart';

part 'file_explorer_state.dart';
part 'file_explorer_cubit.freezed.dart';

class FileExplorerCubit extends Cubit<FileExplorerState> {
  late final ProjectModel project;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  FileExplorerCubit(ID projectID)
      : super(
          (() {
            final project = Store.instance.projects[projectID]!;
            return FileExplorerState(
              projectID: projectID,
              patternIDs: [...project.song.patternOrder],
            );
          })(),
        ) {
    project = Store.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var didPatternListChange = false;

    for (final change in changes) {
      if (change is PatternAdded || change is PatternDeleted) {
        didPatternListChange = true;
      }
    }

    FileExplorerState? newState;

    if (didPatternListChange) {
      newState = (newState ?? state).copyWith(
        patternIDs: [...project.song.patternOrder],
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }
}
