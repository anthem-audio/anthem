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

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:json_annotation/json_annotation.dart';

import 'arrangement/arrangement.dart';
import 'shared/hydratable.dart';

part 'song.g.dart';

@JsonSerializable()
class SongModel extends Hydratable {
  ID id = getID();
  int ticksPerQuarter = 96; // TODO

  Map<ID, PatternModel> patterns = HashMap();
  List<ID> patternOrder = [];
  ID? activePatternID;

  ID? activeGeneratorID;

  late Map<ID, ArrangementModel> arrangements;
  late List<ID> arrangementOrder;
  ID? activeArrangementID;

  late Map<ID, TrackModel> tracks;
  late List<ID> trackOrder;

  @JsonKey(ignore: true)
  StreamController<List<StateChange>>? _changeStreamController;

  StreamController<List<StateChange>> get changeStreamController {
    return _changeStreamController!;
  }

  @JsonKey(ignore: true)
  ProjectModel? _project;

  ProjectModel get project {
    return _project!;
  }

  SongModel() : super();

  SongModel.create({
    required ProjectModel project,
    required StreamController<List<StateChange>> stateChangeStreamController,
  }) : super() {
    final arrangement = ArrangementModel.create(
      name: "Arrangement 1",
      id: getID(),
      project: project,
    );
    arrangements = {arrangement.id: arrangement};
    arrangementOrder = [arrangement.id];
    activeArrangementID = arrangement.id;

    final Map<ID, TrackModel> initTracks = {};
    final List<ID> initTrackOrder = [];

    for (var i = 1; i <= 200; i++) {
      final track = TrackModel(name: "Track $i");
      initTracks[track.id] = track;
      initTrackOrder.add(track.id);
    }

    tracks = initTracks;
    trackOrder = initTrackOrder;

    hydrate(
      project: project,
      changeStreamController: stateChangeStreamController,
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json) =>
      _$SongModelFromJson(json);

  Map<String, dynamic> toJson() => _$SongModelToJson(this);

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

  void setActiveGenerator(ID? generatorID) {
    activeGeneratorID = generatorID;
    _changeStreamController!.add([
      ActiveGeneratorSet(projectID: _project!.id, generatorID: generatorID)
    ]);
  }

  void setActivePattern(ID? patternID) {
    activePatternID = patternID;
    _changeStreamController!
        .add([ActivePatternSet(projectID: _project!.id, patternID: patternID)]);
  }
}

@JsonSerializable()
class TrackModel {
  ID id;
  String name;

  TrackModel({required this.name}) : id = getID();

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelFromJson(json);

  Map<String, dynamic> toJson() => _$TrackModelToJson(this);
}
