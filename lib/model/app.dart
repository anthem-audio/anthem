/*
  Copyright (C) 2021 - 2023 Joshua Wade

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
import 'package:mobx/mobx.dart';

part 'app.g.dart';

class AppModel = _AppModel with _$AppModel;

abstract class _AppModel with Store {
  @observable
  ObservableMap<ID, ProjectModel> projects;

  @observable
  ObservableList<ID> projectOrder;

  @observable
  ID activeProjectID;

  // TODO: hopefully deprecate this via mobx
  final StreamController<StateChange> _stateChangeStreamController =
      StreamController.broadcast();

  /// Contains globally-relevant state changes. Most state changes will be on
  /// the `stateChangeStream` in each `ProjectModel`.
  late Stream<StateChange> stateChangeStream;

  _AppModel()
      : projects = ObservableMap.of({}),
        projectOrder = ObservableList.of([]),
        activeProjectID = "" {
    stateChangeStream = _stateChangeStreamController.stream;
  }

  void addProject(ProjectModel project) {
    projects[project.id] = project;
    projectOrder.add(project.id);
    activeProjectID = project.id;
  }

  void setActiveProject(ID projectID) {
    activeProjectID = projectID;
  }

  void closeProject(ID projectID) {
    projects.remove(projectID);
    projectOrder.removeWhere((element) => element == projectID);
    if (activeProjectID == projectID && projectOrder.isNotEmpty) {
      activeProjectID = projectOrder[0];
    }
  }

  void init() {
    final model = ProjectModel.create();
    addProject(model);
  }
}
