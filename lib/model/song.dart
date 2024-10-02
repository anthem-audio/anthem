/*
  Copyright (C) 2021 - 2024 Joshua Wade

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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'arrangement/arrangement.dart';
import 'shared/hydratable.dart';

part 'song.g.dart';

@AnthemModel.all()
class SongModel extends _SongModel
    with _$SongModel, _$SongModelAnthemModelMixin {
  SongModel() : super();
  SongModel.uninitialized() : super();
  SongModel.create({
    required super.project,
  }) : super.create();

  factory SongModel.fromJson(Map<String, dynamic> json) =>
      _$SongModelAnthemModelMixin.fromJson(json);
}

abstract class _SongModel extends Hydratable with Store {
  ID id = getID();

  @anthemObservable
  int ticksPerQuarter = 96;

  @anthemObservable
  ObservableMap<ID, PatternModel> patterns = ObservableMap();

  @anthemObservable
  ObservableList<ID> patternOrder = ObservableList();

  @anthemObservable
  @hideFromSerialization
  ID? activePatternID;

  @anthemObservable
  ObservableMap<ID, ArrangementModel> arrangements = ObservableMap();

  @anthemObservable
  ObservableList<ID> arrangementOrder = ObservableList();

  @anthemObservable
  @hideFromSerialization
  ID? activeArrangementID;

  @anthemObservable
  // @hide
  ObservableMap<ID, TrackModel> tracks = ObservableMap();

  @anthemObservable
  ObservableList<ID> trackOrder = ObservableList();

  @anthemObservable
  TimeSignatureModel defaultTimeSignature = TimeSignatureModel(4, 4);

  @hide
  ProjectModel? _project;

  ProjectModel get project {
    return _project!;
  }

  _SongModel() : super();

  _SongModel.create({
    required ProjectModel project,
  }) : super() {
    final arrangement = ArrangementModel.create(
      name: 'Arrangement 1',
      id: getID(),
      project: project,
    );
    arrangements = ObservableMap.of({arrangement.id: arrangement});
    arrangementOrder = ObservableList.of([arrangement.id]);
    activeArrangementID = arrangement.id;

    final Map<ID, TrackModel> initTracks = {};
    final List<ID> initTrackOrder = [];

    for (var i = 1; i <= 200; i++) {
      final track = TrackModel(name: 'Track $i');
      initTracks[track.id] = track;
      initTrackOrder.add(track.id);
    }

    tracks = ObservableMap.of(initTracks);
    trackOrder = ObservableList.of(initTrackOrder);

    hydrate(
      project: project,
    );
  }

  Future<void> createInEngine(Engine engine) async {
    for (final arrangement in arrangements.values) {
      await arrangement.createInEngine(engine);
    }
  }

  void hydrate({
    required ProjectModel project,
  }) {
    _project = project;

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
      project.setSelectedDetailView(PatternDetailViewKind(patternID));
    }
  }

  void setActiveArrangement(ID? arrangementID) {
    activeArrangementID = arrangementID;

    if (arrangementID != null) {
      project.setSelectedDetailView(ArrangementDetailViewKind(arrangementID));
    }
  }
}
