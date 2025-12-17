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
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/clip/packed_texture.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'arrangement/arrangement.dart';

part 'sequencer.g.dart';

part 'package:anthem/widgets/basic/clip/clip_title_atlas_mixin.dart';

@AnthemModel.syncedModel(
  cppBehaviorClassName: 'Sequencer',
  cppBehaviorClassIncludePath: 'modules/core/sequencer.h',
)
class SequencerModel extends _SequencerModel
    with
        _$SequencerModel,
        _$SequencerModelAnthemModelMixin,
        _ClipTitleAtlasMixin {
  SequencerModel.uninitialized() : super();

  SequencerModel.create() : super.create() {
    _init();
  }

  factory SequencerModel.fromJson(Map<String, dynamic> json) {
    final sequence = _$SequencerModelAnthemModelMixin.fromJson(json);
    sequence.activePatternID = sequence.patternOrder.firstOrNull;
    sequence.activeArrangementID = sequence.arrangementOrder.firstOrNull;
    sequence._init();
    return sequence;
  }

  void _init() {
    onModelFirstAttached(() {
      _updateClipTitleTextureAtlas();
    });
  }
}

abstract class _SequencerModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  @anthemObservable
  int ticksPerQuarter = 96;

  /// The project BPM, stored as a fixed point number with 2 decimal places.
  ///
  /// For example, 120 BPM would be stored as 12000.
  @anthemObservable
  int beatsPerMinuteRaw = 12800;

  /// Gets the BPM as a double.
  double get beatsPerMinute => beatsPerMinuteRaw / 100;

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

  /// The ID of the sequence that is currently set to be played back, if any.
  @anthemObservable
  @hideFromSerialization
  Id? activeTransportSequenceID;

  /// The global time signature for the project.
  ///
  /// "Default" is in reference to the fact that time signatures can be changed
  /// midway through an arrangement or pattern. This is the time signature that
  /// is used if there are no time signature changes.
  @anthemObservable
  TimeSignatureModel defaultTimeSignature = TimeSignatureModel(4, 4);

  /// The playback start position, in ticks.
  @anthemObservable
  @hideFromSerialization
  int playbackStartPosition = 0;

  /// Whether the sequence is currently playing.
  @anthemObservable
  @hideFromSerialization
  bool isPlaying = false;

  _SequencerModel() : super();

  _SequencerModel.create() : super() {
    final arrangement = ArrangementModel.create(
      name: 'Arrangement 1',
      id: getId(),
    );
    arrangements = AnthemObservableMap.of({arrangement.id: arrangement});
    arrangementOrder = AnthemObservableList.of([arrangement.id]);
    activeArrangementID = arrangement.id;
    activeTransportSequenceID = arrangement.id;
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
