/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

import 'package:anthem/model/anthem_model_base_mixin.dart';
import 'package:anthem_codegen/include/annotations.dart';
import 'package:mobx/mobx.dart';

import 'package:anthem/helpers/id.dart';

part 'track.g.dart';

@AnthemModel.syncedModel()
class TrackModel extends _TrackModel
    with _$TrackModel, _$TrackModelAnthemModelMixin {
  TrackModel({required super.name});

  TrackModel.uninitialized() : super(name: '');

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelAnthemModelMixin.fromJson(json);
}

abstract class _TrackModel with Store, AnthemModelBase {
  Id id;

  @anthemObservable
  String name;

  _TrackModel({required this.name}) : id = getId(), super();
}
