/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

import 'package:anthem/model/project_model_getter_mixin.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'package:anthem/helpers/id.dart';

part 'track.g.dart';

@AnthemModel.syncedModel()
class TrackModel extends _TrackModel
    with _$TrackModel, _$TrackModelAnthemModelMixin {
  TrackModel({required super.name, required super.color, required super.type});

  TrackModel.uninitialized()
    : super(name: '', color: AnthemColor.uninitialized(), type: .hybrid);

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelAnthemModelMixin.fromJson(json);
}

enum TrackType { instrument, audio, hybrid, group }

abstract class _TrackModel
    with Store, AnthemModelBase, ProjectModelGetterMixin {
  /// This track's ID.
  ///
  /// This ID must be used to key this track in [ProjectModel.tracks].
  Id id;

  /// The human-readable name of this track.
  ///
  /// Defaults to something like "Track 1".
  @anthemObservable
  String name;

  /// The color of this track.
  @anthemObservable
  AnthemColor color;

  /// The type of this track.
  ///
  /// This changes the track's behavior from the UI side. For example, all
  /// tracks can have clips with any kind of content, but:
  /// - Audio tracks may only allow audio clips in the UI, and will certainly
  ///   default to them
  /// - Instrument tracks may not be able to play audio? This is undecided as of
  ///   writing.
  /// - When creating a clip on a group track, a group clip will be created, and
  ///   regular clips will not be allowed here
  @anthemObservable
  TrackType type;

  /// IDs of the child tracks of this track.
  ///
  /// If this track is a group track, it likely has child tracks. These tracks
  /// are referenced here.
  ///
  /// Note that these will not show up in the high-level track order or send
  /// track order. They will show up in the [ProjectModel.tracks] map.
  @anthemObservable
  AnthemObservableList<Id> childTracks = AnthemObservableList<Id>();

  @anthemObservable
  /// The ID of the parent of this track, if there is any.
  ///
  /// This is calculated automatically after tracks are added, removed, or moved
  /// around.
  Id? parentTrackId;

  _TrackModel({required this.name, required this.color, required this.type})
    : id = getId(),
      super();
}
