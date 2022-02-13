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
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

part 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  // ignore: unused_field
  late final StreamSubscription<StateChange> _updateActiveGeneratorSub;

  late final ProjectModel project;

  ProjectCubit({required int id})
      : super(
          ProjectState(
            id: id,
            activeGeneratorID: null,
          ),
        ) {
    project = Store.instance.projects[id]!;

    _updateActiveGeneratorSub = project.stateChangeStream
        .where((change) => change is ActiveGeneratorSet)
        .map((change) => change as ActiveGeneratorSet)
        .listen(_updateActiveGenerator);
  }

  _updateActiveGenerator(ActiveGeneratorSet change) {
    emit(
      ProjectState(
          id: state.id, activeGeneratorID: project.song.activeGeneratorID),
    );
  }

  void undo() {
    project.undo();
  }

  void redo() {
    project.redo();
  }

  void journalStartEntry() {
    project.startJournalPage();
  }

  void journalCommitEntry() {
    project.commitJournalPage();
  }

  void setActiveGeneratorID(int? id) => project.song.setActiveGenerator(id);
}
