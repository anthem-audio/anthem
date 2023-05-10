/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'dart:ui';
import 'package:anthem/helpers/convert.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/plugin.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'generator.g.dart';

@JsonSerializable()
class GeneratorModel extends _GeneratorModel with _$GeneratorModel {
  GeneratorModel(
      {required String name, required Color color, required PluginModel plugin})
      : super(name: name, color: color, plugin: plugin);

  factory GeneratorModel.fromJson(Map<String, dynamic> json) =>
      _$GeneratorModelFromJson(json);
}

abstract class _GeneratorModel with Store {
  String id;

  @observable
  String name;

  @JsonKey(toJson: ColorConvert.colorToInt, fromJson: ColorConvert.intToColor)
  @observable
  Color color;

  @observable
  PluginModel plugin;

  _GeneratorModel({
    required this.name,
    required this.color,
    required this.plugin,
  }) : id = getID();

  Map<String, dynamic> toJson() =>
      _$GeneratorModelToJson(this as GeneratorModel);
}
