/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

part 'project_state_changes.dart';
part 'pattern_state_changes.dart';

part 'arrangement_state_changes.dart';

abstract class StateChange {}

class ProjectAdded extends ProjectStateChange {
  ProjectAdded({required ID projectID}) : super(projectID: projectID);
}

class ActiveProjectChanged extends ProjectStateChange {
  ActiveProjectChanged({required ID projectID}) : super(projectID: projectID);
}

class ProjectClosed extends ProjectStateChange {
  ProjectClosed({required ID projectID}) : super(projectID: projectID);
}

class ProjectSaved extends ProjectStateChange {
  ProjectSaved({required ID projectID}) : super(projectID: projectID);
}

class JournalEntryStarted extends ProjectStateChange {
  JournalEntryStarted({required ID projectID}) : super(projectID: projectID);
}

class JournalEntryCommitted extends ProjectStateChange {
  JournalEntryCommitted({required ID projectID}) : super(projectID: projectID);
}
