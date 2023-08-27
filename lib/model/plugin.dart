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

import 'package:anthem/engine_api/engine.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobx/mobx.dart';

part 'plugin.g.dart';

/// A model representing a plugin.
@JsonSerializable()
class PluginModel extends _PluginModel with _$PluginModel {
  PluginModel({required String? path}) : super(path: path);

  factory PluginModel.fromJson(Map<String, dynamic> json) =>
      _$PluginModelFromJson(json);
}

abstract class _PluginModel with Store {
  String? path;

  _PluginModel({required this.path});

  Map<String, dynamic> toJson() => _$PluginModelToJson(this as PluginModel);

  Future<bool> createInEngine(Engine engine) async {
    if (path == null) return false;

    // TODO: For now, we're just grabbing the first arrangement. Really,
    // plugins should be added to all arrangements. This is an issue with
    // trying to align with Tracktion Engine, since Tracktion Engine treats
    // edits as having separate track lists, whereas we want a single track
    // list to span across all arrangements.
    //
    // But back to the TODO - this effectively means we must have exactly one
    // arrangement at once, or bad things will happen. We need to fix this.
    //
    // Maybe we need a better abstraction between us and Tracktion Engine?
    try {
      await engine.projectApi.addPlugin(
        path!,
        engine.project.song
            .arrangements[engine.project.song.activeArrangementID]!.editPointer,
      );
      return true;
    } catch (ex) {
      return false;
    }
  }
}
