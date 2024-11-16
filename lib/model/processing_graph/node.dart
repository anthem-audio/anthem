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

import 'package:anthem/model/processing_graph/node_config.dart';
import 'package:anthem_codegen/include.dart';
import 'package:mobx/mobx.dart';

part 'node.g.dart';

@AnthemModel.syncedModel()
class NodeModel extends _NodeModel
    with _$NodeModel, _$NodeModelAnthemModelMixin {
  NodeModel({required super.id, required super.config});

  NodeModel.uninitialized()
      : super(id: '', config: NodeConfigModel.uninitialized());

  factory NodeModel.fromJson(Map<String, dynamic> json) =>
      _$NodeModelAnthemModelMixin.fromJson(json);
}

abstract class _NodeModel with Store, AnthemModelBase {
  String id;

  NodeConfigModel config;

  _NodeModel({required this.id, required this.config});
}
