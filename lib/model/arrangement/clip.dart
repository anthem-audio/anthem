/*
  Copyright (C) 2022 Joshua Wade

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
import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip.g.dart';

@JsonSerializable()
class ClipModel extends Hydratable {
  ID clipID = getID();
  TimeViewModel? timeView; // If null, we snap to content
  ID patternID;
  ID trackID;
  int offset;

  @JsonKey(ignore: true)
  ProjectModel? _project;
  @JsonKey(ignore: true)
  PatternModel? _pattern;

  ProjectModel get project {
    assertHydrated();
    return _project!;
  }

  PatternModel get pattern {
    assertHydrated();
    return _pattern!;
  }

  /// Used for deserialization. Use ClipModel.create() instead.
  ClipModel({
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
  }) : super();

  ClipModel.create({
    this.timeView,
    required this.patternID,
    required this.trackID,
    required this.offset,
    required ProjectModel project,
  }) : super() {
    hydrate(project: project);
  }

  factory ClipModel.fromJson(Map<String, dynamic> json) =>
      _$ClipModelFromJson(json);

  Map<String, dynamic> toJson() => _$ClipModelToJson(this);

  void hydrate({required ProjectModel project}) {
    _project = project;
    _pattern = project.song.patterns[patternID]!;
  }

  @override
  bool get isHydrated => _project != null && _pattern != null;

  int getWidth() {
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
