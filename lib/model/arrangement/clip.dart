/*
  Copyright (C) 2022 - 2024 Joshua Wade

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
import 'package:anthem_codegen/annotations.dart';
import 'package:mobx/mobx.dart';

part 'clip.g.dart';

@AnthemModel.all()
class ClipModel extends _ClipModel
    with _$ClipModel, _$ClipModelAnthemModelMixin {
  ClipModel.uninitialized()
      : super.create(
          id: getID(),
          patternID: getID(),
          trackID: getID(),
          offset: 0,
        );

  ClipModel(
      {required super.id,
      super.timeView,
      required super.patternID,
      required super.trackID,
      required super.offset});

  ClipModel.create({
    ID? id,
    super.timeView,
    required super.patternID,
    required super.trackID,
    required super.offset,
  }) : super.create(
          id: id ?? getID(),
        );

  factory ClipModel.fromClipModel(ClipModel other) {
    return ClipModel.create(
      id: getID(),
      patternID: other.patternID,
      trackID: other.trackID,
      offset: other.offset,
      timeView: other.timeView != null
          ? TimeViewModel(
              start: other.timeView!.start,
              end: other.timeView!.end,
            )
          : null,
    );
  }

  factory ClipModel.fromJson(Map<String, dynamic> json) =>
      _$ClipModelAnthemModelMixin.fromJson(json);
}

abstract class _ClipModel with Store {
  ID id;

  @anthemObservable
  TimeViewModel? timeView; // If null, we snap to content

  @anthemObservable
  ID patternID;

  @anthemObservable
  ID trackID;

  @anthemObservable
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

  int getWidth(ProjectModel project) {
    if (timeView != null) {
      return timeView!.width;
    }

    return project.song.patterns[patternID]!.getWidth();
  }
}

@AnthemModel.all()
class TimeViewModel extends _TimeViewModel
    with _$TimeViewModel, _$TimeViewModelAnthemModelMixin {
  TimeViewModel({required super.start, required super.end});

  TimeViewModel.uninitialized() : super(start: 0, end: 0);

  factory TimeViewModel.fromJson(Map<String, dynamic> json) =>
      _$TimeViewModelAnthemModelMixin.fromJson(json);
}

abstract class _TimeViewModel with Store {
  @anthemObservable
  int start;

  @anthemObservable
  int end;

  _TimeViewModel({required this.start, required this.end});

  int get width {
    return end - start;
  }

  TimeViewModel clone() {
    return TimeViewModel(start: start, end: end);
  }
}
