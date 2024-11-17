/*
  Copyright (C) 2024 Joshua Wade

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

import 'node_port_config.dart';

part 'node_port.g.dart';

@AnthemModel.syncedModel()
class NodePortModel extends _NodePortModel
    with _$NodePortModel, _$NodePortModelAnthemModelMixin {
  NodePortModel({
    required super.id,
    required super.nodeId,
    required super.config,
  });

  NodePortModel.uninitialized()
      : super(id: -1, nodeId: '', config: NodePortConfigModel.uninitialized());

  void init() {
    if (config.dataType == NodePortDataType.control) {
      parameterValue = config.parameterConfig!.defaultValue;
    }
  }

  factory NodePortModel.fromJson(Map<String, dynamic> json) =>
      _$NodePortModelAnthemModelMixin.fromJson(json);
}

abstract class _NodePortModel with Store, AnthemModelBase {
  // This will map to the 32-bit parameter ID from the VST standard if this is a
  // control input port.
  int id;

  String nodeId;

  NodePortConfigModel config;

  /// The value of the parameter, if this port is a control input port.
  @anthemObservable
  double? parameterValue;

  _NodePortModel({
    required this.id,
    required this.nodeId,
    required this.config,
  });
}
