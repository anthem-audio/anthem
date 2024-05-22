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

import 'package:anthem/engine_api/engine.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'plugin.g.dart';

/// A model representing a plugin.
@JsonSerializable()
class PluginModel extends _PluginModel with _$PluginModel {
  PluginModel({required super.path});

  factory PluginModel.fromJson(Map<String, dynamic> json) =>
      _$PluginModelFromJson(json);
}

abstract class _PluginModel with Store {
  String? path;

  _PluginModel({required this.path});

  Map<String, dynamic> toJson() => _$PluginModelToJson(this as PluginModel);

  Future<bool> createInEngine(Engine engine) async {
    if (path == null) return false;

    try {
      await engine.processingGraphApi.addProcessor(path!);
      return true;
    } catch (ex) {
      return false;
    }
  }
}
