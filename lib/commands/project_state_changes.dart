/*
  Copyright (C) 2022 Joshua Wade

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

part of 'state_changes.dart';

abstract class ProjectStateChange extends StateChange {
  ID projectID;

  ProjectStateChange({required this.projectID});
}



// Generator

class GeneratorAdded extends GeneratorStateChange {
  GeneratorAdded({
    required ID projectID,
    required ID generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class GeneratorRemoved extends GeneratorStateChange {
  GeneratorRemoved({
    required ID projectID,
    required ID generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class ActiveGeneratorChanged extends GeneratorStateChange {
  ActiveGeneratorChanged({
    required ID projectID,
    required ID? generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class PatternAdded extends PatternStateChange {
  PatternAdded({
    required ID projectID,
    required ID patternID,
  }) : super(projectID: projectID, patternID: patternID);
}



// Pattern

class PatternDeleted extends PatternStateChange {
  PatternDeleted({
    required ID projectID,
    required ID patternID,
  }) : super(projectID: projectID, patternID: patternID);
}

class ActivePatternChanged extends PatternStateChange {
  ActivePatternChanged({
    required ID projectID,
    required ID? patternID,
  }) : super(projectID: projectID, patternID: patternID);
}
