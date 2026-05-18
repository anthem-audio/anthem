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

import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';

typedef ParameterControlValueMapper = double Function(double value);

double _identityParameterValueMapper(double value) => value;

class ParameterControlBinding {
  final NodeModel node;
  final NodePortModel port;
  final ParameterControlValueMapper parameterToControlValue;
  final ParameterControlValueMapper controlToParameterValue;

  const ParameterControlBinding({
    required this.node,
    required this.port,
    this.parameterToControlValue = _identityParameterValueMapper,
    this.controlToParameterValue = _identityParameterValueMapper,
  });

  factory ParameterControlBinding.byId({
    required NodeModel node,
    required int portId,
    ParameterControlValueMapper parameterToControlValue =
        _identityParameterValueMapper,
    ParameterControlValueMapper controlToParameterValue =
        _identityParameterValueMapper,
  }) {
    return ParameterControlBinding(
      node: node,
      port: node.getPortById(portId),
      parameterToControlValue: parameterToControlValue,
      controlToParameterValue: controlToParameterValue,
    );
  }

  double get controlValue => parameterToControlValue(
    SetParameterValueCommand.effectiveParameterValue(port),
  );

  void beginChange() {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.beginChange(node: node, port: port);
  }

  void updateChange(double value) {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.updateChange(
      node: node,
      port: port,
      value: controlToParameterValue(value),
    );
  }

  void commitChange() {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.commitChange(node: node, port: port);
  }
}
