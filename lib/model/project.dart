/*
  Copyright (C) 2021 - 2023 Joshua Wade

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
import 'dart:convert';

import 'package:anthem/commands/command.dart';
import 'package:anthem/commands/command_queue.dart';
import 'package:anthem/commands/journal_commands.dart';
import 'package:anthem/commands/project_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/song.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

import 'generator.dart';
import 'shared/hydratable.dart';

part 'project.g.dart';

enum ProjectLayoutKind { arrange, edit, mix }

enum EditorKind {
  detail,
  automation,
  channelRack,
  mixer,
}

@JsonSerializable()
class ProjectModel extends _ProjectModel with _$ProjectModel {
  ProjectModel() : super();
  ProjectModel.create() : super.create();

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final model = _$ProjectModelFromJson(json);
    model.isSaved = true;
    return model;
  }
}

abstract class _ProjectModel extends Hydratable with Store {
  late SongModel song;

  @observable
  @JsonKey(fromJson: _generatorsFromJson, toJson: _generatorsToJson)
  ObservableMap<ID, GeneratorModel> generators = ObservableMap();

  @observable
  @JsonKey(fromJson: _generatorListFromJson, toJson: _generatorListToJson)
  ObservableList<ID> generatorList = ObservableList();

  @JsonKey(includeFromJson: false, includeToJson: false)
  ID id = getID();

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? filePath;

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isSaved = false;

  // Detail view state

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  DetailViewKind? _selectedDetailView;

  @JsonKey(includeFromJson: false, includeToJson: false)
  DetailViewKind? get selectedDetailView => _selectedDetailView;
  set selectedDetailView(DetailViewKind? detailView) {
    _selectedDetailView = detailView;
    if (detailView != null) isDetailViewSelected = true;
    _dispatch([
      StateChange.project(ProjectStateChange.selectedDetailViewChanged(id)),
    ]);
  }

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isDetailViewSelected = false;

  // Visual layout flags

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isProjectExplorerVisible = true;

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isPatternEditorVisible = true;

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isAutomationMatrixVisible = true;

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  ProjectLayoutKind layout = ProjectLayoutKind.arrange;

  @observable
  @JsonKey(includeFromJson: false, includeToJson: false)
  EditorKind selectedEditor = EditorKind.detail;

  // Undo / redo & etc

  @JsonKey(includeFromJson: false, includeToJson: false)
  CommandQueue commandQueue = CommandQueue();

  @JsonKey(includeFromJson: false, includeToJson: false)
  List<Command> _journalPageAccumulator = [];

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool _journalPageActive = false;

  // State change stream & etc

  @JsonKey(includeFromJson: false, includeToJson: false)
  final StreamController<List<StateChange>> _stateChangeStreamController =
      StreamController.broadcast();

  @JsonKey(includeFromJson: false, includeToJson: false)
  late Stream<List<StateChange>> stateChangeStream;

  // This method is used for deserialization and so doesn't create new child
  // models.
  _ProjectModel() : super() {
    stateChangeStream = _stateChangeStreamController.stream;
  }

  _ProjectModel.create() : super() {
    stateChangeStream = _stateChangeStreamController.stream;
    song = SongModel.create(
      project: this as ProjectModel,
      stateChangeStreamController: _stateChangeStreamController,
    );

    // We don't need to hydrate here. All `SomeModel.Create()` functions should
    // call hydrate().
    isHydrated = true;
  }

  Map<String, dynamic> toJson() => _$ProjectModelToJson(this as ProjectModel);

  @override
  String toString() => json.encode(toJson());

  /// This function is run after deserialization. It allows us to do some setup
  /// that the deserialization step can't do for us.
  void hydrate() {
    song.hydrate(
      project: this as ProjectModel,
      changeStreamController: _stateChangeStreamController,
    );
    isHydrated = true;
  }

  void _dispatch(List<StateChange> changes) {
    _stateChangeStreamController.add(changes);
  }

  void execute(Command command, {bool push = true}) {
    if (_journalPageActive) {
      _journalPageAccumulator.add(command);
    } else {
      final changes =
          push ? commandQueue.executeAndPush(command) : command.execute();
      _dispatch(changes);
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

    final command = JournalPageCommand(this as ProjectModel, accumulator);
    final change = commandQueue.executeAndPush(command);
    _dispatch(change);
  }
}

/// Used to describe which detail view is active in the project sidebar, if any
abstract class DetailViewKind {}

class PatternDetailViewKind extends DetailViewKind {
  ID patternID;
  PatternDetailViewKind(this.patternID);
}

class ArrangementDetailViewKind extends DetailViewKind {
  ID arrangementID;
  ArrangementDetailViewKind(this.arrangementID);
}

class TimeSignatureChangeDetailViewKind extends DetailViewKind {
  ID? arrangementID;
  ID? patternID;
  ID changeID;
  TimeSignatureChangeDetailViewKind({
    this.arrangementID,
    this.patternID,
    required this.changeID,
  });
}

// JSON serialization and deserialization functions

ObservableMap<ID, GeneratorModel> _generatorsFromJson(
    Map<String, dynamic> json) {
  return ObservableMap.of(
    json.map(
      (key, value) => MapEntry(key, GeneratorModel.fromJson(value)),
    ),
  );
}

Map<String, dynamic> _generatorsToJson(
    ObservableMap<ID, GeneratorModel> generators) {
  return generators.map(
    (key, value) => MapEntry(key, value.toJson()),
  );
}

ObservableList<ID> _generatorListFromJson(List<String> json) {
  return ObservableList.of(json);
}

List<String> _generatorListToJson(ObservableList<ID> generatorList) {
  return generatorList.toList();
}
