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

part 'project_state_changes.dart';
part 'pattern_state_changes.dart';
part 'arrangement_state_changes.dart';

abstract class StateChange {}

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
