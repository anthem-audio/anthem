/*
  Copyright (C) 2021 - 2026 Joshua Wade

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
}) {
  project.sequence.patterns[pattern.id] = pattern;
}

void _removePatternFromProject({
  required ProjectModel project,
  required Id patternId,
}) {
  project.sequence.patterns.remove(patternId);
}

class PatternAddRemoveCommand extends Command {
  final bool _isAdd;

  late final PatternModel pattern;

  PatternAddRemoveCommand.add({required this.pattern}) : _isAdd = true;

  PatternAddRemoveCommand.remove({
    required ProjectModel project,
    required Id patternId,
  }) : _isAdd = false {
    final foundPattern = project.sequence.patterns[patternId];
    if (foundPattern == null) {
      throw StateError(
        'PatternAddRemoveCommand.remove(): Pattern $patternId not found.',
      );
    }

    pattern = foundPattern;
  }

  @override
  void execute(ProjectModel project) {
    if (_isAdd) {
      _add(project);
    } else {
      _remove(project);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (_isAdd) {
      _remove(project);
    } else {
      _add(project);
    }
  }

  void _add(ProjectModel project) {
    if (project.sequence.patterns[pattern.id] != null) {
      throw StateError(
        'Tried to add a pattern that already exists. This indicates bad usage '
        'of PatternAddRemoveCommand, or bad project state.',
      );
    }

    _addPatternToProject(project: project, pattern: pattern);
  }

  void _remove(ProjectModel project) {
    if (project.sequence.patterns[pattern.id] == null) {
      throw StateError(
        'Tried to remove a pattern that does not exist. This indicates bad '
        'usage of PatternAddRemoveCommand, or bad project state.',
      );
    }

    _removePatternFromProject(project: project, patternId: pattern.id);
  }
}

class SetPatternNameCommand extends Command {
  Id patternID;
  late String oldName;
  String newName;

  SetPatternNameCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newName,
  }) {
    oldName = project.sequence.patterns[patternID]!.name;
  }

  @override
  void execute(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID]!;
    pattern.name = newName;
  }

  @override
  void rollback(ProjectModel project) {
    final pattern = project.sequence.patterns[patternID]!;
    pattern.name = oldName;
  }
}

class SetPatternColorCommand extends Command {
  Id patternID;
  late AnthemColor oldColor;
  AnthemColor newColor;

  SetPatternColorCommand({
    required ProjectModel project,
    required this.patternID,
    required this.newColor,
  }) {
    oldColor = project.sequence.patterns[patternID]!.color;
  }

  @override
  void execute(ProjectModel project) {
    project.sequence.patterns[patternID]!.color = newColor;
  }

  @override
  void rollback(ProjectModel project) {
    project.sequence.patterns[patternID]!.color = oldColor;
  }
}
