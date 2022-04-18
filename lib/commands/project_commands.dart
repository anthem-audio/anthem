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

import 'dart:ui';

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

void _removeGenerator(ProjectModel project, int generatorID) {
  project.generatorList.removeWhere((element) => element == generatorID);
  if (project.instruments.containsKey(generatorID)) {
    project.instruments.remove(generatorID);
  }
  if (project.controllers.containsKey(generatorID)) {
    project.controllers.remove(generatorID);
  }
}

class AddInstrumentCommand extends Command {
  int instrumentID;
  String name;
  Color color;

  AddInstrumentCommand({
    required ProjectModel project,
    required this.instrumentID,
    required this.name,
    required this.color,
  }) : super(project);

  @override
  List<StateChange> execute() {
    project.generatorList.add(instrumentID);
    project.instruments[instrumentID] =
        InstrumentModel(name: name, color: color);
    return [GeneratorAdded(projectID: project.id, generatorID: instrumentID)];
  }

  @override
  List<StateChange> rollback() {
    _removeGenerator(project, instrumentID);
    return [GeneratorRemoved(projectID: project.id, generatorID: instrumentID)];
  }
}

class AddControllerCommand extends Command {
  int controllerID;
  String name;
  Color color;

  AddControllerCommand({
    required ProjectModel project,
    required this.controllerID,
    required this.name,
    required this.color,
  }) : super(project);

  @override
  List<StateChange> execute() {
    project.generatorList.add(controllerID);
    project.controllers[controllerID] =
        ControllerModel(name: name, color: color);
    return [GeneratorAdded(projectID: project.id, generatorID: controllerID)];
  }

  @override
  List<StateChange> rollback() {
    _removeGenerator(project, controllerID);
    return [GeneratorRemoved(projectID: project.id, generatorID: controllerID)];
  }
}
