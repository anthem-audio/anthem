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

import 'package:anthem/commands/command.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/project.dart';

class AddAutomationPointCommand extends Command {
  ID patternID;
  ID automationGeneratorID;
  AutomationPointModel point;
  int index;

  AddAutomationPointCommand({
    required this.patternID,
    required this.automationGeneratorID,
    required this.point,
    required this.index,
  });

  @override
  void execute(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points
        .insert(index, point);
  }

  @override
  void rollback(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points
        .removeAt(index);
  }
}

class SetAutomationPointValueCommand extends Command {
  ID patternID;
  ID automationGeneratorID;
  int pointIndex;
  double oldValue;
  double newValue;

  SetAutomationPointValueCommand({
    required this.patternID,
    required this.automationGeneratorID,
    required this.pointIndex,
    required this.oldValue,
    required this.newValue,
  });

  @override
  void execute(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].value = newValue;
  }

  @override
  void rollback(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].value = oldValue;
  }
}

class SetAutomationPointOffsetCommand extends Command {
  ID patternID;
  ID automationGeneratorID;
  int pointIndex;
  int oldOffset;
  int newOffset;

  SetAutomationPointOffsetCommand({
    required this.patternID,
    required this.automationGeneratorID,
    required this.pointIndex,
    required this.oldOffset,
    required this.newOffset,
  });

  @override
  void execute(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].offset = newOffset;
  }

  @override
  void rollback(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].offset = oldOffset;
  }
}

class SetAutomationPointTensionCommand extends Command {
  ID patternID;
  ID automationGeneratorID;
  int pointIndex;
  double oldTension;
  double newTension;

  SetAutomationPointTensionCommand({
    required this.patternID,
    required this.automationGeneratorID,
    required this.pointIndex,
    required this.oldTension,
    required this.newTension,
  });

  @override
  void execute(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].tension = newTension;
  }

  @override
  void rollback(ProjectModel project) {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].tension = oldTension;
  }
}
