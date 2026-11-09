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

import 'dart:async';

import 'package:anthem/model/project.dart';

import 'command.dart';

class JournalPageCommand extends Command {
  List<Command> commands;

  JournalPageCommand(this.commands);

  @override
  FutureOr<void> execute(ProjectModel project) =>
      _run(project, commands.iterator, rollback: false);

  @override
  FutureOr<void> rollback(ProjectModel project) =>
      _run(project, commands.reversed.iterator, rollback: true);

  FutureOr<void> _run(
    ProjectModel project,
    Iterator<Command> iterator, {
    required bool rollback,
  }) {
    while (iterator.moveNext()) {
      final command = iterator.current;
      final result = rollback
          ? command.rollback(project)
          : command.execute(project);
      if (result is Future<void>) {
        return result.then((_) => _run(project, iterator, rollback: rollback));
      }
    }
  }

  @override
  void dispose() {
    for (final command in commands) {
      command.dispose();
    }
  }
}
