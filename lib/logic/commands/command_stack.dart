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

import 'package:anthem/model/project.dart';

import 'command.dart';

class CommandStack {
  final ProjectModel _project;
  final List<Command> commands = [];
  int commandPointer = 0;

  CommandStack(this._project);

  void push(Command command) {
    commands.removeRange(commandPointer, commands.length);
    commands.add(command);
    commandPointer++;
  }

  void executeAndPush(Command command) {
    push(command);
    command.execute(_project);
  }

  bool get canUndo => commandPointer - 1 >= 0;

  void undo() {
    if (!canUndo) return;
    commandPointer--;
    commands[commandPointer].rollback(_project);
  }

  bool get canRedo => commandPointer < commands.length;

  void redo() {
    if (!canRedo) return;
    commands[commandPointer].execute(_project);
    commandPointer++;
  }
}
