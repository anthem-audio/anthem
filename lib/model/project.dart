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
import 'dart:convert';

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_queue.dart';
import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:anthem/model/song.dart';
import 'package:json_annotation/json_annotation.dart';

import 'generator.dart';

part 'project.g.dart';

@JsonSerializable()
class ProjectModel {
  late SongModel song;

  Map<int, InstrumentModel> instruments;
  Map<int, ControllerModel> controllers;
  List<int> generatorList;

  @JsonKey(ignore: true)
  int id;

  @JsonKey(ignore: true)
  String? filePath;

  @JsonKey(ignore: true)
  CommandQueue commandQueue = CommandQueue();

  @JsonKey(ignore: true)
  List<Command> _journalPageAccumulator = [];

  @JsonKey(ignore: true)
  bool _journalPageActive = false;

  @JsonKey(ignore: true)
  final StreamController<StateChange> _stateChangeStreamController =
      StreamController.broadcast();

  @JsonKey(ignore: true)
  late Stream<StateChange> stateChangeStream;

  @JsonKey(ignore: true)
  bool isSaved = false;

  ProjectModel()
      : id = getID(),
        instruments = HashMap(),
        controllers = HashMap(),
        generatorList = [] {
    stateChangeStream = _stateChangeStreamController.stream;
    song = SongModel();
  }

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final model = _$ProjectModelFromJson(json);
    model.isSaved = true;
    return model;
  }

  /// This function is run after deserialization. It allows us to do some setup
  /// that the deserialization step can't do for us.
  void hydrate() {
    song.hydrate(
      project: this,
      changeStreamController: _stateChangeStreamController,
    );
  }

  Map<String, dynamic> toJson() => _$ProjectModelToJson(this);

  @override
  String toString() => json.encode(toJson());

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
    } else {
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
