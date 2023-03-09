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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/model/project.dart';

/// Base class for a command.
///
/// Anthem uses the command pattern for undo/redo. All undoable changes to the
/// model should be performed via commands.
abstract class Command {
  ProjectModel project;

  /// Executes this command and returns a list of `StateChange`s describing
  /// the resulting changes.
  List<StateChange> execute();

  /// Undoes this command and returns a list of `StateChange`s describing the
  /// resulting changes.
  List<StateChange> rollback();

  Command(this.project);
}
