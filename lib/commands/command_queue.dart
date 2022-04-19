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

import 'command.dart';

class CommandQueue {
  List<Command> commands = [];
  int commandPointer = 0;

  void push(Command command) {
    commands.removeRange(commandPointer, commands.length);
    commands.add(command);
    commandPointer++;
  }

  List<StateChange> executeAndPush(Command command) {
    push(command);
    return command.execute();
  }

  List<StateChange> undo() {
    if (commandPointer - 1 < 0) return [];
    commandPointer--;
    return commands[commandPointer].rollback();
  }

  List<StateChange> redo() {
    if (commandPointer + 1 > commands.length) return [];
    commandPointer++;
    return commands[commandPointer - 1].execute();
  }
}
