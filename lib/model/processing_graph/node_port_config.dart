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

import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

import 'parameter_config.dart';

part 'node_port_config.g.dart';

@AnthemEnum()
enum NodePortDataType {
  audio,
  midi,
  control,
}

@AnthemModel.all()
class NodePortConfigModel extends _NodePortConfigModel
    with _$NodePortConfigModel, _$NodePortConfigModelAnthemModelMixin {
  NodePortConfigModel({
    required super.dataType,
    super.parameterConfig,
  });

  NodePortConfigModel.uninitialized() : super(dataType: NodePortDataType.audio);

  factory NodePortConfigModel.fromJson(Map<String, dynamic> json) =>
      _$NodePortConfigModelAnthemModelMixin.fromJson(json);
}

abstract class _NodePortConfigModel with Store, AnthemModelBase {
  NodePortDataType dataType;
  ParameterConfigModel? parameterConfig;

  _NodePortConfigModel({
    required this.dataType,
    this.parameterConfig,
  });
}
