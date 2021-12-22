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

class AppModel {
  Map<int, ProjectModel> projects;
  List<int> projectOrder;
  int activeProjectID;

  final StreamController<StateChange> _stateChangeStreamController =
      StreamController.broadcast();
  late Stream<StateChange> stateChangeStream;

  AppModel()
      : projects = {},
        projectOrder = [],
        activeProjectID = -1 {
    stateChangeStream = _stateChangeStreamController.stream;
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is AppModel &&
        other.projects == projects &&
        other.projectOrder == projectOrder &&
        other.activeProjectID == activeProjectID;
  }

  @override
  int get hashCode =>
      projects.hashCode ^ projectOrder.hashCode ^ activeProjectID.hashCode;

  void addProject(ProjectModel project) {
    projects[project.id] = project;
    projectOrder.add(project.id);
    activeProjectID = project.id;
    _stateChangeStreamController.add(ProjectAdded(projectID: project.id));
  }

  void setActiveProject(int projectID) {
    activeProjectID = projectID;
    _stateChangeStreamController
        .add(ActiveProjectChanged(projectID: projectID));
  }

  void closeProject(int projectID) {
    projects.remove(projectID);
    projectOrder.removeWhere((element) => element == projectID);
    if (activeProjectID == projectID && projectOrder.isNotEmpty) {
      activeProjectID = projectOrder[0];
    }
    _stateChangeStreamController.add(ProjectClosed(projectID: projectID));
  }

  void init() {
    addProject(ProjectModel());
  }
}
