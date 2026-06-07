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
import 'package:anthem/model/processing_graph/processors/control_value_visualization.dart';

typedef ParameterUiValueMapper = double Function(double value);

double _identityParameterUiValueMapper(double value) => value;

/// Adapter between generic controls and an Anthem parameter port.
///
/// `Knob` and `Slider` stay generic. They do not know how to find a project
/// service, execute a parameter command, map normalized values, or discover
/// automation. They ask the binding what value to display and how to commit a
/// user edit.
///
/// This binding currently has four responsibilities:
///
/// 1. Identify the parameter by holding the [NodeModel] and [NodePortModel]
///    that a control edits.
/// 2. Map value domains. Anthem parameter values are normalized to
///    [0.0, 1.0], while a control may expose another domain, such as pan as
///    [-1.0, 1.0].
/// 3. Route user edits through parameter logic so gestures produce correct
///    undo entries, touch tracking, default resets, and command behavior.
/// 4. Provide the live automation display source by resolving the owning
///    track's automation lane and returning its visualization stream ID.
class ParameterUiBinding {
  final NodeModel node;
  final NodePortModel port;
  final ParameterUiValueMapper parameterToUiValue;
  final ParameterUiValueMapper uiToParameterValue;

  const ParameterUiBinding({
    required this.node,
    required this.port,
    this.parameterToUiValue = _identityParameterUiValueMapper,
    this.uiToParameterValue = _identityParameterUiValueMapper,
  });

  factory ParameterUiBinding.byId({
    required NodeModel node,
    required int portId,
    ParameterUiValueMapper parameterToUiValue = _identityParameterUiValueMapper,
    ParameterUiValueMapper uiToParameterValue = _identityParameterUiValueMapper,
  }) {
    return ParameterUiBinding(
      node: node,
      port: node.getPortById(portId),
      parameterToUiValue: parameterToUiValue,
      uiToParameterValue: uiToParameterValue,
    );
  }

  String? get automationVisualizationId {
    final ownerTrackId = node.owner?.trackId;
    if (ownerTrackId == null) {
      return null;
    }

    final project = node.project;
    final ownerTrack = project.tracks[ownerTrackId];
    if (ownerTrack == null) {
      return null;
    }

    for (final laneId in ownerTrack.automationLanes) {
      final lane = project.tracks[laneId];
      final target = lane?.automationTarget;
      if (target == null ||
          target.nodeId != node.id ||
          target.portId != port.id) {
        continue;
      }

      final visualizationNodeId =
          lane?.automationProcessing?.controlValueVisualizationNodeId;
      final processor =
          project.processingGraph.nodes[visualizationNodeId]?.processor;
      if (processor is ControlValueVisualizationProcessorModel) {
        return processor.visualizationId;
      }
    }

    return null;
  }

  double uiValueForNormalizedParameterValue(double parameterValue) {
    return parameterToUiValue(
      SetParameterValueCommand.normalizeValue(parameterValue),
    );
  }

  double get uiValue => uiValueForNormalizedParameterValue(
    SetParameterValueCommand.effectiveParameterValue(port),
  );

  void beginChange() {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.beginChange(node: node, port: port);
  }

  void updateChange(double value) {
    ServiceRegistry.forProject(node.project.id).parameterController
        .updateChange(node: node, port: port, value: uiToParameterValue(value));
  }

  void commitChange() {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.commitChange(node: node, port: port);
  }

  void resetToDefault() {
    ServiceRegistry.forProject(
      node.project.id,
    ).parameterController.resetToDefault(node: node, port: port);
  }
}
