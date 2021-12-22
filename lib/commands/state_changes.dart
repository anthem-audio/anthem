/*
  Copyright (C) 2021 Joshua Wade

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

abstract class StateChange {}

/*
 * Base classes
 */

abstract class ProjectStateChange extends StateChange {
  int projectID;

  ProjectStateChange({required this.projectID});
}

abstract class GeneratorStateChange extends ProjectStateChange {
  int? generatorID;

  GeneratorStateChange({required int projectID, required this.generatorID})
      : super(projectID: projectID);
}

abstract class PatternStateChange extends ProjectStateChange {
  int patternID;

  PatternStateChange({required int projectID, required this.patternID})
      : super(projectID: projectID);
}

abstract class NoteStateChange extends PatternStateChange {
  int generatorID;
  int noteID;

  NoteStateChange({
    required int projectID,
    required int patternID,
    required this.generatorID,
    required this.noteID,
  }) : super(projectID: projectID, patternID: patternID);
}

/*
 * Special
 */

class NothingChanged extends StateChange {}

class MultipleThingsChanged extends StateChange {
  List<StateChange> changes;

  MultipleThingsChanged(this.changes);
}

/*
 * App
 */

class ProjectAdded extends ProjectStateChange {
  ProjectAdded({required int projectID}) : super(projectID: projectID);
}

class ActiveProjectChanged extends ProjectStateChange {
  ActiveProjectChanged({required int projectID}) : super(projectID: projectID);
}

class ProjectClosed extends ProjectStateChange {
  ProjectClosed({required int projectID}) : super(projectID: projectID);
}

class ProjectSaved extends ProjectStateChange {
  ProjectSaved({required int projectID}) : super(projectID: projectID);
}

class JournalEntryStarted extends ProjectStateChange {
  JournalEntryStarted({required int projectID}) : super(projectID: projectID);
}

class JournalEntryCommitted extends ProjectStateChange {
  JournalEntryCommitted({required int projectID}) : super(projectID: projectID);
}

/*
 * Project
 */

class GeneratorAdded extends GeneratorStateChange {
  GeneratorAdded({
    required int projectID,
    required int generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class GeneratorRemoved extends GeneratorStateChange {
  GeneratorRemoved({
    required int projectID,
    required int generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class ActiveGeneratorSet extends GeneratorStateChange {
  ActiveGeneratorSet({
    required int projectID,
    required int? generatorID,
  }) : super(projectID: projectID, generatorID: generatorID);
}

class PatternAdded extends PatternStateChange {
  PatternAdded({
    required int projectID,
    required int patternID,
  }) : super(projectID: projectID, patternID: patternID);
}

class PatternDeleted extends PatternStateChange {
  PatternDeleted({
    required int projectID,
    required int patternID,
  }) : super(projectID: projectID, patternID: patternID);
}

class ActivePatternSet extends PatternStateChange {
  ActivePatternSet({
    required int projectID,
    required int patternID,
  }) : super(projectID: projectID, patternID: patternID);
}

/*
 * Pattern
 */

class NoteAdded extends NoteStateChange {
  NoteAdded({
    required int projectID,
    required int patternID,
    required int generatorID,
    required int noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteDeleted extends NoteStateChange {
  NoteDeleted({
    required int projectID,
    required int patternID,
    required int generatorID,
    required int noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteMoved extends NoteStateChange {
  NoteMoved({
    required int projectID,
    required int patternID,
    required int generatorID,
    required int noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}

class NoteResized extends NoteStateChange {
  NoteResized({
    required int projectID,
    required int patternID,
    required int generatorID,
    required int noteID,
  }) : super(
          projectID: projectID,
          patternID: patternID,
          generatorID: generatorID,
          noteID: noteID,
        );
}
