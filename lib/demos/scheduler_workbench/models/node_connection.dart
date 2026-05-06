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

import '../simulation/simulation.dart';

part 'node_connection.g.dart';

// ignore: library_private_types_in_public_api
class NodeConnectionModel = _NodeConnectionModel with _$NodeConnectionModel;

abstract class _NodeConnectionModel with Store {
  Simulation? _simulation;

  @observable
  int id;

  @observable
  int sourceNodeId;

  @observable
  int sourcePortId;

  @observable
  int destinationNodeId;

  @observable
  int destinationPortId;

  @observable
  bool isCopied = false;

  _NodeConnectionModel({
    required this.id,
    required this.sourceNodeId,
    required this.sourcePortId,
    required this.destinationNodeId,
    required this.destinationPortId,
  });

  void attachSimulation(Simulation simulation) {
    _simulation = simulation;
  }

  void moveData() {
    final simulation = _simulation;

    if (simulation == null) {
      throw StateError('Connection $id is not attached to a simulation.');
    }

    simulation.moveData(this as NodeConnectionModel);
  }

  @action
  void setCopied(bool value) {
    isCopied = value;
  }
}
