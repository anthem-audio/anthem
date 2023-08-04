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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';

import 'command.dart';

void _addPatternToProject({
  required ProjectModel project,
  required PatternModel pattern,
  required int index,
}) {
  project.song.patternOrder.insert(index, pattern.id);
  project.song.patterns[pattern.id] = pattern;
}

void _removePatternFromProject({
  required ProjectModel project,
  required ID patternID,
}) {
  project.song.patternOrder.removeWhere((element) => element == patternID);
  project.song.patterns.remove(patternID);
}

class AddPatternCommand extends Command {
  PatternModel pattern;
  int index;

  AddPatternCommand({
    required ProjectModel project,
    required this.pattern,
    required this.index,
  }) : super(project);

  @override
  void execute() {
    _addPatternToProject(
      project: project,
      pattern: pattern,
      index: index,
    );
  }

  @override
  void rollback() {
    _removePatternFromProject(
      project: project,
      patternID: pattern.id,
    );
  }
}

class DeletePatternCommand extends Command {
  PatternModel pattern;
  int index;

  DeletePatternCommand({
    required ProjectModel project,
    required this.pattern,
    required this.index,
  }) : super(project);

  @override
  void execute() {
    _removePatternFromProject(
      project: project,
      patternID: pattern.id,
    );
  }

  @override
  void rollback() {
    _addPatternToProject(
      project: project,
      pattern: pattern,
      index: index,
    );
  }
}

class SetPatternNameCommand extends Command {
  ID patternID;
  late String oldName;
  String newName;

  SetPatternNameCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newName,
  }) : super(project) {
    oldName = project.song.patterns[patternID]!.name;
  }

  @override
  void execute() {
    final pattern = project.song.patterns[patternID]!;
    pattern.name = newName;
    pattern.updateClipTitleCache();
  }

  @override
  void rollback() {
    final pattern = project.song.patterns[patternID]!;
    pattern.name = oldName;
    pattern.updateClipTitleCache();
  }
}

class SetPatternColorCommand extends Command {
  ID patternID;
  late AnthemColor oldColor;
  AnthemColor newColor;

  SetPatternColorCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newColor,
  }) : super(project) {
    oldColor = project.song.patterns[patternID]!.color;
  }

  @override
  void execute() {
    project.song.patterns[patternID]!.color = newColor;
  }

  @override
  void rollback() {
    project.song.patterns[patternID]!.color = oldColor;
  }
}
