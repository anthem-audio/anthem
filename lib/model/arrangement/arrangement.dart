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

import 'dart:convert';

import 'package:anthem/helpers/get_id.dart';
import 'package:json_annotation/json_annotation.dart';

import 'clip.dart';

part 'arrangement.g.dart';

@JsonSerializable()
class ArrangementModel {
  int id = getID();
  String name;
  Map<int, ClipModel> clips = {};

  ArrangementModel({required this.name});

  factory ArrangementModel.fromJson(Map<String, dynamic> json) =>
      _$ArrangementModelFromJson(json);

  Map<String, dynamic> toJson() => _$ArrangementModelToJson(this);

  @override
  String toString() => json.encode(toJson());
}
