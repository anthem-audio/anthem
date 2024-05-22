/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

import 'package:anthem/helpers/id.dart';

part 'track.g.dart';

@JsonSerializable()
class TrackModel extends _TrackModel with _$TrackModel {
  TrackModel({required super.name});

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelFromJson(json);
}

abstract class _TrackModel with Store {
  ID id;

  @observable
  String name;

  _TrackModel({required this.name}) : id = getID();

  Map<String, dynamic> toJson() => _$TrackModelToJson(this as TrackModel);
}
