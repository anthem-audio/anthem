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
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';

class PatternEditorController {
  final ProjectModel project;

  PatternEditorController({required this.project});

  ID addPattern([String? name]) {
    if (name == null) {
      final patterns = project.song.patterns.nonObservableInner;
      var patternNumber = patterns.length;

      final existingNames = patterns.values.map((pattern) => pattern.name);

      do {
        patternNumber++;
        name = "Pattern $patternNumber";
      } while (existingNames.contains(name));
    }

    final patternModel = PatternModel.create(name: name, project: project);

    project.execute(
      AddPatternCommand(
        project: project,
        pattern: patternModel,
        index: project.song.patternOrder.length,
      ),
    );

    project.song.setActivePattern(patternModel.id);

    return patternModel.id;
  }

  void addGenerator(String name, Color color) {
    project.execute(AddGeneratorCommand(
      project: project,
      generatorID: getID(),
      name: name,
      color: color,
    ));
  }

  void deletePattern(ID patternID) {
    project.execute(DeletePatternCommand(
      project: project,
      pattern: project.song.patterns[patternID]!,
      index: project.song.patternOrder.indexOf(patternID),
    ));
  }
}
