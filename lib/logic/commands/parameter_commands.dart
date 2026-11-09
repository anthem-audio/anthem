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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/logic/service_registry.dart';

class _ParameterValueTarget {
  final NodeModel node;
  final NodePortModel port;

  const _ParameterValueTarget({required this.node, required this.port});
}

class SetParameterValueCommand extends Command {
  final Id nodeId;
  final int controlPortId;
  final double oldValue;
  final double newValue;

  SetParameterValueCommand({
    required this.nodeId,
    required this.controlPortId,
    required double oldValue,
    required double newValue,
  }) : oldValue = oldValue.clamp(0.0, 1.0).toDouble(),
       newValue = newValue.clamp(0.0, 1.0).toDouble();

  @override
  Future<void> execute(ProjectModel project) async {
    await _applyParameterValue(
      project,
      nodeId: nodeId,
      controlPortId: controlPortId,
      value: newValue,
    );
  }

  @override
  Future<void> rollback(ProjectModel project) async {
    await _applyParameterValue(
      project,
      nodeId: nodeId,
      controlPortId: controlPortId,
      value: oldValue,
    );
  }

  static _ParameterValueTarget _resolveTarget(
    ProjectModel project, {
    required Id nodeId,
    required int controlPortId,
  }) {
    final node = project.processingGraph.nodes[nodeId];
    if (node == null) {
      throw StateError('SetParameterValueCommand: Node $nodeId was not found.');
    }

    final port = node.controlInputPorts
        .where((port) => port.id == controlPortId)
        .firstOrNull;

    if (port == null) {
      throw StateError(
        'SetParameterValueCommand: Control input port $controlPortId was not '
        'found on node $nodeId.',
      );
    }

    if (port.config.parameterConfig == null) {
      throw StateError(
        'SetParameterValueCommand: Control input port $controlPortId on node '
        '$nodeId is not a parameter.',
      );
    }

    return _ParameterValueTarget(node: node, port: port);
  }

  static Future<double> _applyParameterValue(
    ProjectModel project, {
    required Id nodeId,
    required int controlPortId,
    required double value,
  }) {
    final target = _resolveTarget(
      project,
      nodeId: nodeId,
      controlPortId: controlPortId,
    );
    return ServiceRegistry.forProject(project.id).parameterController
        .setValue(node: target.node, port: target.port, value: value);
  }
}
