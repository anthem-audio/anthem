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

  StateChange executeAndPush(Command command) {
    push(command);
    return command.execute();
  }

  StateChange undo() {
    if (commandPointer - 1 < 0) return NothingChanged();
    commandPointer--;
    return commands[commandPointer].rollback();
  }

  StateChange redo() {
    if (commandPointer + 1 > commands.length) return NothingChanged();
    commandPointer++;
    return commands[commandPointer - 1].execute();
  }

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is CommandQueue &&
        other.commands == commands &&
        other.commandPointer == commandPointer;
  }

  @override
  int get hashCode => commands.hashCode ^ commandPointer.hashCode;
}
