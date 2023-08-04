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
import 'package:anthem/model/project.dart';

class SetAutomationPointValueCommand extends Command {
  ID patternID;
  ID automationGeneratorID;
  int pointIndex;
  double oldValue;
  double newValue;

  SetAutomationPointValueCommand({
    required ProjectModel project,
    required this.patternID,
    required this.automationGeneratorID,
    required this.pointIndex,
    required this.oldValue,
    required this.newValue,
  }) : super(project);

  @override
  void execute() {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].value = newValue;
  }

  @override
  void rollback() {
    project.song.patterns[patternID]!.automationLanes[automationGeneratorID]!
        .points[pointIndex].value = oldValue;
  }
}
