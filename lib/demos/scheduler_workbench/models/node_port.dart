/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:mobx/mobx.dart';

part 'node_port.g.dart';

enum PortDataType { audio, event, control }

enum PortDirection { input, output }

// ignore: library_private_types_in_public_api
class NodePortModel = _NodePortModel with _$NodePortModel;

abstract class _NodePortModel with Store {
  final int id;
  final int nodeId;
  final String name;
  final PortDataType dataType;
  final PortDirection direction;

  @observable
  ObservableList<int> connections;

  _NodePortModel({
    required this.id,
    required this.nodeId,
    required this.name,
    required this.dataType,
    required this.direction,
    ObservableList<int>? connections,
  }) : connections = connections ?? ObservableList<int>();

  @computed
  bool get isInput => direction == PortDirection.input;

  @computed
  bool get isOutput => direction == PortDirection.output;
}
