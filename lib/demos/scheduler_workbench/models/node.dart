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
import 'node_port.dart';

part 'node.g.dart';

enum NodeProcessingState { notReady, ready, processing, completed }

// ignore: library_private_types_in_public_api
class NodeModel = _NodeModel with _$NodeModel;

abstract class _NodeModel with Store {
  final int id;
  final String name;
  Simulation? _simulation;

  @observable
  double x;

  @observable
  double y;

  @observable
  int processingTicks = 1;

  @observable
  NodeProcessingState processingState = NodeProcessingState.notReady;

  @observable
  ObservableList<NodePortModel> audioInputPorts;

  @observable
  ObservableList<NodePortModel> eventInputPorts;

  @observable
  ObservableList<NodePortModel> controlInputPorts;

  @observable
  ObservableList<NodePortModel> audioOutputPorts;

  @observable
  ObservableList<NodePortModel> eventOutputPorts;

  @observable
  ObservableList<NodePortModel> controlOutputPorts;

  _NodeModel({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    ObservableList<NodePortModel>? audioInputPorts,
    ObservableList<NodePortModel>? eventInputPorts,
    ObservableList<NodePortModel>? controlInputPorts,
    ObservableList<NodePortModel>? audioOutputPorts,
    ObservableList<NodePortModel>? eventOutputPorts,
    ObservableList<NodePortModel>? controlOutputPorts,
  }) : audioInputPorts = audioInputPorts ?? ObservableList<NodePortModel>(),
       eventInputPorts = eventInputPorts ?? ObservableList<NodePortModel>(),
       controlInputPorts = controlInputPorts ?? ObservableList<NodePortModel>(),
       audioOutputPorts = audioOutputPorts ?? ObservableList<NodePortModel>(),
       eventOutputPorts = eventOutputPorts ?? ObservableList<NodePortModel>(),
       controlOutputPorts =
           controlOutputPorts ?? ObservableList<NodePortModel>();

  void attachSimulation(Simulation simulation) {
    _simulation = simulation;
  }

  Future<void> process() {
    final simulation = _simulation;

    if (simulation == null) {
      return Future.error(
        StateError('Node $id is not attached to a simulation.'),
      );
    }

    return simulation.processNode(this as NodeModel);
  }

  @action
  void setPosition({required double x, required double y}) {
    this.x = x;
    this.y = y;
  }

  @action
  void setProcessingTicks(int value) {
    processingTicks = value.clamp(1, 1000000);
  }

  @action
  void setProcessingState(NodeProcessingState state) {
    processingState = state;
  }

  NodePortModel getPortById(int portId) {
    for (final port in getAllPorts()) {
      if (port.id == portId) {
        return port;
      }
    }

    throw StateError('Port with id $portId not found on node $id.');
  }

  Iterable<NodePortModel> getAllPorts() {
    return audioInputPorts
        .followedBy(audioOutputPorts)
        .followedBy(eventInputPorts)
        .followedBy(eventOutputPorts)
        .followedBy(controlInputPorts)
        .followedBy(controlOutputPorts);
  }
}
