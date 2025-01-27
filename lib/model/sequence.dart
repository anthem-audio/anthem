/*
  Copyright (C) 2021 - 2025 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem/model/collections.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'arrangement/arrangement.dart';

part 'sequence.g.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'Sequence',
  cppBehaviorClassIncludePath: 'modules/core/sequence.h',
)
class SequenceModel extends _SequenceModel
    with _$SequenceModel, _$SequenceModelAnthemModelMixin {
  SequenceModel() : super();
  SequenceModel.uninitialized() : super();
  SequenceModel.create() : super.create();

  factory SequenceModel.fromJson(Map<String, dynamic> json) =>
      _$SequenceModelAnthemModelMixin.fromJson(json);
}

abstract class _SequenceModel with Store, AnthemModelBase {
  Id id = getId();

  @anthemObservable
  int ticksPerQuarter = 96;

  @anthemObservable
  double beatsPerMinute = 128;

  @anthemObservable
  AnthemObservableMap<Id, PatternModel> patterns = AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<Id> patternOrder = AnthemObservableList();

  @anthemObservable
  @hideFromSerialization
  Id? activePatternID;

  @anthemObservable
  AnthemObservableMap<Id, ArrangementModel> arrangements =
      AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<Id> arrangementOrder = AnthemObservableList();

  @anthemObservable
  @hideFromSerialization
  Id? activeArrangementID;

  @anthemObservable
  AnthemObservableMap<Id, TrackModel> tracks = AnthemObservableMap();

  @anthemObservable
  AnthemObservableList<Id> trackOrder = AnthemObservableList();

  @anthemObservable
  TimeSignatureModel defaultTimeSignature = TimeSignatureModel(4, 4);

  _SequenceModel() : super();

  _SequenceModel.create() : super() {
    final arrangement = ArrangementModel.create(
      name: 'Arrangement 1',
      id: getId(),
    );
    arrangements = AnthemObservableMap.of({arrangement.id: arrangement});
    arrangementOrder = AnthemObservableList.of([arrangement.id]);
    activeArrangementID = arrangement.id;

    final Map<Id, TrackModel> initTracks = {};
    final List<Id> initTrackOrder = [];

    for (var i = 1; i <= 200; i++) {
      final track = TrackModel(name: 'Track $i');
      initTracks[track.id] = track;
      initTrackOrder.add(track.id);
    }

    tracks = AnthemObservableMap.of(initTracks);
    trackOrder = AnthemObservableList.of(initTrackOrder);
  }

  void setActivePattern(Id? patternID) {
    activePatternID = patternID;

    if (patternID != null) {
      project.setSelectedDetailView(PatternDetailViewKind(patternID));
    }
  }

  void setActiveArrangement(Id? arrangementID) {
    activeArrangementID = arrangementID;

    if (arrangementID != null) {
      project.setSelectedDetailView(ArrangementDetailViewKind(arrangementID));
    }
  }
}
