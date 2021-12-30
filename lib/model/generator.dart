/*
  Copyright (C) 2021 Joshua Wade

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
import 'dart:ui';
import 'package:anthem/helpers/convert.dart';
import 'package:anthem/helpers/get_id.dart';
import 'package:json_annotation/json_annotation.dart';

part 'generator.g.dart';

abstract class GeneratorModel {
  int id;
  String name;
  @JsonKey(toJson: ColorConvert.colorToInt, fromJson: ColorConvert.intToColor)
  Color color;

  GeneratorModel({
    required this.name,
    required this.color,
  }) : id = getID();

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;

    return other is GeneratorModel &&
        other.id == id &&
        other.name == name &&
        other.color == color;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ color.hashCode;
}

@JsonSerializable()
class InstrumentModel extends GeneratorModel {
  InstrumentModel({
    required String name,
    required Color color,
  }) : super(name: name, color: color);

  factory InstrumentModel.fromJson(Map<String, dynamic> json) =>
      _$InstrumentModelFromJson(json);

  Map<String, dynamic> toJson() => _$InstrumentModelToJson(this);

  @override
  String toString() => json.encode(toJson());
}

@JsonSerializable()
class ControllerModel extends GeneratorModel {
  ControllerModel({
    required String name,
    required Color color,
  }) : super(name: name, color: color);

  factory ControllerModel.fromJson(Map<String, dynamic> json) =>
      _$ControllerModelFromJson(json);

  Map<String, dynamic> toJson() => _$ControllerModelToJson(this);

  @override
  String toString() => json.encode(toJson());
}
