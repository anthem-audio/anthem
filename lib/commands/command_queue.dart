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

import 'command.dart';

class CommandQueue {
  List<Command> commands = [];
  int commandPointer = 0;

  void push(Command command) {
    commands.removeRange(commandPointer, commands.length);
    commands.add(command);
    commandPointer++;
  }

  void executeAndPush(Command command) {
    command.execute();
    push(command);
  }

  void undo() {
    if (commandPointer - 1 < 0) return;
    commands[commandPointer - 1].rollback();
    commandPointer--;
  }

  void redo() {
    if (commandPointer + 1 >= commands.length) return;
    commands[commandPointer + 1].execute();
    commandPointer++;
  }
}
