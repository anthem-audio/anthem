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

import 'dart:async';
import 'dart:collection';

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_queue.dart';
import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/song.dart';

import 'generator.dart';

class ProjectModel {
  int id;

  late SongModel song;

  Map<int, InstrumentModel> instruments;
  Map<int, ControllerModel> controllers;
  List<int> generatorList;

  // Not to be serialized
  String? filePath;
  CommandQueue commandQueue = CommandQueue();
  List<Command> _journalPageAccumulator = [];
  bool _journalPageActive = false;
  final StreamController<StateChange> _stateChangeStreamController =
      StreamController.broadcast();
  late Stream<StateChange> stateChangeStream;

  ProjectModel()
      : id = getID(),
        instruments = HashMap(),
        controllers = HashMap(),
        generatorList = [] {
    stateChangeStream = _stateChangeStreamController.stream;
    song = SongModel(this, _stateChangeStreamController);
  }

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

  void _dispatch(StateChange change) {
    if (change is MultipleThingsChanged) {
      for (var change in change.changes) {
        _stateChangeStreamController.add(change);
      }
    } else {
      _stateChangeStreamController.add(change);
    }
  }

  void execute(Command command) {
    if (_journalPageActive) {
      _journalPageAccumulator.add(command);
    }
    else {
      final change = commandQueue.executeAndPush(command);
      _dispatch(change);
    }
  }

  void _assertJournalInactive() {
    if (_journalPageActive) {
      throw AssertionError("Journal page was active but shouldn't have been.");
    }
  }

  void undo() {
    _assertJournalInactive();
    final change = commandQueue.undo();
    _dispatch(change);
  }

  void redo() {
    _assertJournalInactive();
    final change = commandQueue.redo();
    _dispatch(change);
  }

  void startJournalPage() {
    _journalPageActive = true;
  }

  void commitJournalPage() {
    if (!_journalPageActive) return;
    if (_journalPageAccumulator.isEmpty) {
      _journalPageActive = false;
      return;
    }

    final accumulator = _journalPageAccumulator;
    _journalPageAccumulator = [];
    _journalPageActive = false;

    final command = JournalPageCommand(this, accumulator);
    final change = commandQueue.executeAndPush(command);
    _dispatch(change);
  }
}
