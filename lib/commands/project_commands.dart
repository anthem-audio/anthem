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

import 'dart:ui';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/generator.dart';
import 'package:anthem/model/plugin.dart';
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
  GeneratorType generatorType;
  Color color;
  String? pluginPath;

  AddGeneratorCommand({
    required ProjectModel project,
    required this.generatorID,
    required this.name,
    required this.generatorType,
    required this.color,
    required this.pluginPath,
  }) : super(project);

  @override
  void execute() {
    final plugin = PluginModel(path: pluginPath)
      ..createInEngine(project.engine);
    final generator = GeneratorModel(
      name: name,
      generatorType: generatorType,
      color: color,
      plugin: plugin,
    );

    project.generatorList.add(generatorID);
    project.generators[generatorID] = generator;
  }

  @override
  void rollback() {
    _removeGenerator(project, generatorID);
  }
}
