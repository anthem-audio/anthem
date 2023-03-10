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

import 'package:anthem/commands/pattern_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/project.dart';

import 'command.dart';

void _removeGenerator(ProjectModel project, ID generatorID) {
  project.generatorList.removeWhere((element) => element == generatorID);
  if (project.generators.containsKey(generatorID)) {
    project.generators.remove(generatorID);
  }
}

class AddGeneratorCommand extends Command {
  ID generatorID;
  String name;
  Color color;

  AddGeneratorCommand({
    required ProjectModel project,
    required this.generatorID,
    required this.name,
    required this.color,
  }) : super(project);

  @override
  List<StateChange> execute() {
    project.generatorList.add(generatorID);
    project.generators[generatorID] =
        GeneratorModel(name: name, color: color);
    return [
      StateChange.generator(
        GeneratorStateChange.generatorAdded(project.id, generatorID),
      )
    ];
  }

  @override
  List<StateChange> rollback() {
    _removeGenerator(project, generatorID);
    return [
      StateChange.generator(
        GeneratorStateChange.generatorRemoved(project.id, generatorID),
      )
    ];
  }
}
