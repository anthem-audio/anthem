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
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/hydratable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'clip.g.dart';

@JsonSerializable()
class ClipModel extends _ClipModel with _$ClipModel {
  ClipModel(
      {required ID clipID,
      TimeViewModel? timeView,
      required ID patternID,
      required ID trackID,
      required int offset})
      : super(
            clipID: clipID,
            timeView: timeView,
            patternID: patternID,
            trackID: trackID,
            offset: offset);

  ClipModel.create({
    required ID clipID,
    TimeViewModel? timeView,
    required ID patternID,
    required ID trackID,
    required int offset,
    required ProjectModel project,
  }) : super.create(
            clipID: clipID,
            timeView: timeView,
            patternID: patternID,
            trackID: trackID,
            offset: offset,
            project: project);

  factory ClipModel.fromJson(Map<String, dynamic> json) =>
      _$ClipModelFromJson(json);
}

abstract class _ClipModel extends Hydratable with Store {
  ID clipID;

  @observable
  TimeViewModel? timeView; // If null, we snap to content

  @observable
  ID patternID;

  @observable
  ID trackID;

  @observable
  int offset;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ProjectModel? _project;
  @JsonKey(includeFromJson: false, includeToJson: false)
  PatternModel? _pattern;

  ProjectModel get project {
    return _project!;
  }

  PatternModel get pattern {
    return _pattern!;
  }

  /// Used for deserialization. Use ClipModel.create() instead.
  _ClipModel({
    required this.clipID,
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
  }) : super();

  _ClipModel.create({
    required this.clipID,
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
    required ProjectModel project,
  }) : super() {
    hydrate(project: project);
  }

  Map<String, dynamic> toJson() => _$ClipModelToJson(this as ClipModel);

  void hydrate({required ProjectModel project}) {
    _project = project;
    _pattern = project.song.patterns[patternID]!;
    isHydrated = true;
  }

  @computed
  int get width {
    if (timeView != null) {
      return timeView!.end - timeView!.start;
    }

    return pattern.getWidth();
  }
}

@JsonSerializable()
class TimeViewModel {
  int start;
  int end;

  TimeViewModel({required this.start, required this.end});

  factory TimeViewModel.fromJson(Map<String, dynamic> json) =>
      _$TimeViewModelFromJson(json);

  Map<String, dynamic> toJson() => _$TimeViewModelToJson(this);

  int get width {
    return end - start;
  }
}
