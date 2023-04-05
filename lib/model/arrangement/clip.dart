/*
  Copyright (C) 2022 - 2023 Joshua Wade

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
import 'package:anthem/model/project.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'clip.g.dart';

@JsonSerializable()
class ClipModel extends _ClipModel with _$ClipModel {
  ClipModel(
      {required ID id,
      TimeViewModel? timeView,
      required ID patternID,
      required ID trackID,
      required int offset})
      : super(
          id: id,
          timeView: timeView,
          patternID: patternID,
          trackID: trackID,
          offset: offset,
        );

  ClipModel.create({
    ID? id,
    TimeViewModel? timeView,
    required ID patternID,
    required ID trackID,
    required int offset,
  }) : super.create(
          id: id ?? getID(),
          timeView: timeView,
          patternID: patternID,
          trackID: trackID,
          offset: offset,
        );

  factory ClipModel.fromClipModel(ClipModel other) {
    return ClipModel.create(
      id: getID(),
      patternID: other.patternID,
      trackID: other.trackID,
      offset: other.offset,
    );
  }

  factory ClipModel.fromJson(Map<String, dynamic> json) =>
      _$ClipModelFromJson(json);
}

abstract class _ClipModel with Store {
  ID id;

  @observable
  TimeViewModel? timeView; // If null, we snap to content

  @observable
  ID patternID;

  @observable
  ID trackID;

  @observable
  int offset;

  /// Used for deserialization. Use ClipModel.create() instead.
  _ClipModel({
    required this.id,
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
  }) : super();

  _ClipModel.create({
    required this.id,
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
  });

  Map<String, dynamic> toJson() => _$ClipModelToJson(this as ClipModel);

  int getWidth(ProjectModel project) {
    if (timeView != null) {
      return timeView!.width;
    }

    return project.song.patterns[patternID]!.getWidth();
  }
}

@JsonSerializable()
class TimeViewModel extends _TimeViewModel with _$TimeViewModel {
  TimeViewModel({required int start, required int end})
      : super(start: start, end: end);

  factory TimeViewModel.fromJson(Map<String, dynamic> json) =>
      _$TimeViewModelFromJson(json);
}

abstract class _TimeViewModel with Store {
  @observable
  int start;

  @observable
  int end;

  _TimeViewModel({required this.start, required this.end});

  Map<String, dynamic> toJson() => _$TimeViewModelToJson(this as TimeViewModel);

  int get width {
    return end - start;
  }
}
