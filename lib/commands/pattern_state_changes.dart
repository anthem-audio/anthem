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

/*
 * Base classes
 */

abstract class GeneratorStateChange extends ProjectStateChange {
  ID? generatorID;

  GeneratorStateChange({required ID projectID, required this.generatorID})
      : super(projectID: projectID);
}

abstract class PatternStateChange extends ProjectStateChange {
  ID? patternID;

  PatternStateChange({required ID projectID, required this.patternID})
      : super(projectID: projectID);
}

abstract class NoteStateChange extends PatternStateChange {
  ID generatorID;
  ID noteID;

  NoteStateChange({
    required ID projectID,
    required ID patternID,
    required this.generatorID,
    required this.noteID,
  }) : super(projectID: projectID, patternID: patternID);
}

/*
 * State changes
 */

class NoteAdded extends NoteStateChange {
  NoteAdded({
    required ID projectID,
    required ID patternID,
    required ID generatorID,
    required ID noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteDeleted extends NoteStateChange {
  NoteDeleted({
    required ID projectID,
    required ID patternID,
    required ID generatorID,
    required ID noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteMoved extends NoteStateChange {
  NoteMoved({
    required ID projectID,
    required ID patternID,
    required ID generatorID,
    required ID noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteResized extends NoteStateChange {
  NoteResized({
    required ID projectID,
    required ID patternID,
    required ID generatorID,
    required ID noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}
