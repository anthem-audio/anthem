/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/project_commands.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';

class PatternEditorController {
  final ProjectModel project;

  PatternEditorController({required this.project});

  void addGenerator({
    required String name,
    required Color color,
    required String pluginPath,
  }) {
    // TODO: Use plugin path to send this to the engine

    final id = getID();

    project.execute(AddGeneratorCommand(
      project: project,
      generatorID: id,
      name: name,
      color: color,
    ));

    project.activeGeneratorID = id;
  }

  void deletePattern(ID patternID) {
    project.execute(DeletePatternCommand(
      project: project,
      pattern: project.song.patterns[patternID]!,
      index: project.song.patternOrder.indexOf(patternID),
    ));
  }
}
