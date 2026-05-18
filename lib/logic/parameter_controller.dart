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
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';

class ParameterController {
  final ProjectModel project;

  final Map<(Id, int), _ParameterChangeSession> _activeChanges = {};

  ParameterController(this.project);

  void beginChange({required NodeModel node, required NodePortModel port}) {
    _assertParameterPort(node: node, port: port);

    final key = (node.id, port.id);

    if (_activeChanges.containsKey(key)) {
      commitChange(node: node, port: port);
    }

    _activeChanges[key] = _ParameterChangeSession(
      oldValue: SetParameterValueCommand.effectiveParameterValue(port),
    );
  }

  void updateChange({
    required NodeModel node,
    required NodePortModel port,
    required double value,
  }) {
    _assertParameterPort(node: node, port: port);

    SetParameterValueCommand.applyParameterValue(
      project,
      nodeId: node.id,
      controlPortId: port.id,
      value: value,
    );
  }

  void commitChange({required NodeModel node, required NodePortModel port}) {
    _assertParameterPort(node: node, port: port);

    final session = _activeChanges.remove((node.id, port.id));
    if (session == null) {
      return;
    }

    final newValue = SetParameterValueCommand.effectiveParameterValue(port);
    if (session.oldValue == newValue) {
      return;
    }

    project.push(
      SetParameterValueCommand(
        nodeId: node.id,
        controlPortId: port.id,
        oldValue: session.oldValue,
        newValue: newValue,
      ),
    );
  }

  void cancelChange({required NodeModel node, required NodePortModel port}) {
    _assertParameterPort(node: node, port: port);

    final session = _activeChanges.remove((node.id, port.id));
    if (session == null) {
      return;
    }

    SetParameterValueCommand.applyParameterValue(
      project,
      nodeId: node.id,
      controlPortId: port.id,
      value: session.oldValue,
    );
  }

  void _assertParameterPort({
    required NodeModel node,
    required NodePortModel port,
  }) {
    if (port.nodeId != node.id) {
      throw StateError(
        'ParameterController: Port ${port.id} does not belong to node '
        '${node.id}.',
      );
    }

    if (port.config.parameterConfig == null) {
      throw StateError(
        'ParameterController: Port ${port.id} on node ${node.id} is not a '
        'parameter.',
      );
    }
  }
}

class _ParameterChangeSession {
  final double oldValue;

  const _ParameterChangeSession({required this.oldValue});
}
