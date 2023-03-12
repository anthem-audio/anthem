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

import 'package:anthem/commands/project_state_changes.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

import 'arrangement/arrangement.dart';
import 'shared/hydratable.dart';

part 'song.g.dart';

@JsonSerializable()
class SongModel extends _SongModel with _$SongModel {
  SongModel() : super();
  SongModel.create({
    required ProjectModel project,
    required StreamController<List<StateChange>> stateChangeStreamController,
  }) : super.create(
          project: project,
          stateChangeStreamController: stateChangeStreamController,
        );

  factory SongModel.fromJson(Map<String, dynamic> json) =>
      _$SongModelFromJson(json);
}

abstract class _SongModel extends Hydratable with Store {
  ID id = getID();

  @observable
  int ticksPerQuarter = 96; // TODO

  @observable
  @JsonKey(fromJson: _patternsFromJson, toJson: _patternsToJson)
  ObservableMap<ID, PatternModel> patterns = ObservableMap();

  @observable
  @JsonKey(fromJson: _patternOrderFromJson, toJson: _patternOrderToJson)
  ObservableList<ID> patternOrder = ObservableList();

  @observable
  ID? activePatternID;

  @observable
  @JsonKey(fromJson: _arrangementsFromJson, toJson: _arrangementsToJson)
  ObservableMap<ID, ArrangementModel> arrangements = ObservableMap();

  @observable
  @JsonKey(fromJson: _arrangementOrderFromJson, toJson: _arrangementOrderToJson)
  ObservableList<ID> arrangementOrder = ObservableList();

  @observable
  ID? activeArrangementID;

  @observable
  @JsonKey(fromJson: _tracksFromJson, toJson: _tracksToJson)
  ObservableMap<ID, TrackModel> tracks = ObservableMap();

  @observable
  @JsonKey(fromJson: _trackOrderFromJson, toJson: _trackOrderToJson)
  ObservableList<ID> trackOrder = ObservableList();

  @JsonKey(includeFromJson: false, includeToJson: false)
  StreamController<List<StateChange>>? _changeStreamController;

  StreamController<List<StateChange>> get changeStreamController {
    return _changeStreamController!;
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  ProjectModel? _project;

  ProjectModel get project {
    return _project!;
  }

  _SongModel() : super();

  _SongModel.create({
    required ProjectModel project,
    required StreamController<List<StateChange>> stateChangeStreamController,
  }) : super() {
    final arrangement = ArrangementModel.create(
      name: "Arrangement 1",
      id: getID(),
      project: project,
    );
    arrangements = ObservableMap.of({arrangement.id: arrangement});
    arrangementOrder = ObservableList.of([arrangement.id]);
    activeArrangementID = arrangement.id;

    final Map<ID, TrackModel> initTracks = {};
    final List<ID> initTrackOrder = [];

    for (var i = 1; i <= 200; i++) {
      final track = TrackModel(name: "Track $i");
      initTracks[track.id] = track;
      initTrackOrder.add(track.id);
    }

    tracks = ObservableMap.of(initTracks);
    trackOrder = ObservableList.of(initTrackOrder);

    hydrate(
      project: project,
      changeStreamController: stateChangeStreamController,
    );
  }

  Map<String, dynamic> toJson() => _$SongModelToJson(this as SongModel);

  @override
  String toString() => json.encode(toJson());

  void hydrate({
    required ProjectModel project,
    required StreamController<List<StateChange>> changeStreamController,
  }) {
    _project = project;
    _changeStreamController = changeStreamController;

    for (final arrangement in arrangements.values) {
      arrangement.hydrate(project: project);
    }

    for (final pattern in patterns.values) {
      pattern.hydrate(project: project);
    }

    isHydrated = true;
  }

  void setActivePattern(ID? patternID) {
    activePatternID = patternID;

    if (patternID != null) {
      project.selectedDetailView = PatternDetailViewKind(patternID);
    }

    changeStreamController.add([
      StateChange.project(
        ProjectStateChange.activePatternChanged(_project!.id),
      ),
    ]);
  }

  void setActiveArrangement(ID? arrangementID) {
    activeArrangementID = arrangementID;

    if (arrangementID != null) {
      project.selectedDetailView = ArrangementDetailViewKind(arrangementID);
    }

    changeStreamController.add([
      StateChange.project(
        ProjectStateChange.activeArrangementChanged(_project!.id),
      ),
    ]);
  }
}

// JSON serialization and deserialization functions

ObservableMap<ID, PatternModel> _patternsFromJson(Map<String, dynamic> json) {
  return ObservableMap.of(
    json.map(
      (key, value) => MapEntry(key, PatternModel.fromJson(value)),
    ),
  );
}

Map<String, dynamic> _patternsToJson(ObservableMap<ID, PatternModel> patterns) {
  return patterns.map((key, value) => MapEntry(key, value.toJson()));
}

ObservableList<ID> _patternOrderFromJson(List<String> json) {
  return ObservableList.of(json);
}

List<String> _patternOrderToJson(ObservableList<ID> patternOrder) {
  return patternOrder.toList();
}

ObservableMap<ID, ArrangementModel> _arrangementsFromJson(
    Map<String, dynamic> json) {
  return ObservableMap.of(
    json.map(
      (key, value) => MapEntry(key, ArrangementModel.fromJson(value)),
    ),
  );
}

Map<String, dynamic> _arrangementsToJson(
    ObservableMap<ID, ArrangementModel> arrangements) {
  return arrangements.map((key, value) => MapEntry(key, value.toJson()));
}

ObservableList<ID> _arrangementOrderFromJson(List<String> json) {
  return ObservableList.of(json);
}

List<String> _arrangementOrderToJson(ObservableList<ID> arrangementOrder) {
  return arrangementOrder.toList();
}

ObservableMap<ID, TrackModel> _tracksFromJson(Map<String, dynamic> json) {
  return ObservableMap.of(
    json.map(
      (key, value) => MapEntry(key, TrackModel.fromJson(value)),
    ),
  );
}

Map<String, dynamic> _tracksToJson(ObservableMap<ID, TrackModel> tracks) {
  return tracks.map((key, value) => MapEntry(key, value.toJson()));
}

ObservableList<ID> _trackOrderFromJson(List<String> json) {
  return ObservableList.of(json);
}

List<String> _trackOrderToJson(ObservableList<ID> trackOrder) {
  return trackOrder.toList();
}
