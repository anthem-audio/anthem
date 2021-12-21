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

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_queue.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/song.dart';

import 'generator.dart';

class ProjectModel {
  int id;

  SongModel song;

  Map<int, InstrumentModel> instruments;
  Map<int, ControllerModel> controllers;
  List<int> generatorList;

  // Not to be serialized
  String? filePath;
  CommandQueue commandQueue;
  List<Command> journalPageAccumulator;

  ProjectModel()
      : id = getID(),
        song = SongModel(),
        instruments = {},
        controllers = {},
        generatorList = [],
        commandQueue = CommandQueue(),
        journalPageAccumulator = [];

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is ProjectModel &&
        other.id == id &&
        other.song == song &&
        other.instruments == instruments &&
        other.controllers == controllers &&
        other.generatorList == generatorList &&
        other.commandQueue == commandQueue &&
        other.filePath == filePath;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      song.hashCode ^
      instruments.hashCode ^
      controllers.hashCode ^
      generatorList.hashCode ^
      commandQueue.hashCode ^
      filePath.hashCode;
}
