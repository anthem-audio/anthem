/*
  Copyright (C) 2022 - 2025 Joshua Wade

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
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

part 'clip.g.dart';

@AnthemModel.syncedModel()
class ClipModel extends _ClipModel
    with _$ClipModel, _$ClipModelAnthemModelMixin {
  ClipModel.uninitialized()
      : super.create(
          id: getId(),
          patternId: getId(),
          trackId: getId(),
          offset: 0,
        );

  ClipModel(
      {required super.id,
      super.timeView,
      required super.patternId,
      required super.trackId,
      required super.offset});

  ClipModel.create({
    Id? id,
    super.timeView,
    required super.patternId,
    required super.trackId,
    required super.offset,
  }) : super.create(
          id: id ?? getId(),
        );

  factory ClipModel.fromClipModel(ClipModel other) {
    return ClipModel.create(
      id: getId(),
      patternId: other.patternId,
      trackId: other.trackId,
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

abstract class _ClipModel with Store, AnthemModelBase {
  Id id;

  @anthemObservable
  TimeViewModel? timeView; // If null, we snap to content

  @anthemObservable
  Id patternId;

  @anthemObservable
  Id trackId;

  @anthemObservable
  int offset;

  /// Used for deserialization. Use ClipModel.create() instead.
  _ClipModel({
    required this.id,
    this.timeView,
    required this.patternId,
    required this.trackId,
    required this.offset,
  }) : super();

  _ClipModel.create({
    required this.id,
    this.timeView,
    required this.patternId,
    required this.trackId,
    required this.offset,
  }) : super();

  int get width {
    if (timeView != null) {
      return timeView!.width;
    }

    return project.sequence.patterns[patternId]!.clipAutoWidth;
  }
}

@AnthemModel.syncedModel()
class TimeViewModel extends _TimeViewModel
    with _$TimeViewModel, _$TimeViewModelAnthemModelMixin {
  TimeViewModel({required super.start, required super.end});

  TimeViewModel.uninitialized() : super(start: 0, end: 0);

  factory TimeViewModel.fromJson(Map<String, dynamic> json) =>
      _$TimeViewModelAnthemModelMixin.fromJson(json);
}

abstract class _TimeViewModel with Store, AnthemModelBase {
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
