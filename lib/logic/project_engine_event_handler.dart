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

import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/parameter_commands.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/logic/parameter_controller.dart';

class _ProcessorParameterGestureSession {
  final double oldValue;

  const _ProcessorParameterGestureSession({required this.oldValue});
}

/// Applies processor reports to the UI cache and undo history.
///
/// `Engine` creates and owns this handler for its project and notifies it when
/// the engine stops so unfinished parameter gestures can be discarded.
class ProjectEngineEventHandler {
  final ProjectModel project;

  final Map<(Id, int), _ProcessorParameterGestureSession>
  _processorParameterGestureSessions = {};

  ProjectEngineEventHandler(this.project);

  /// Applies parameter reports and plugin state-change notifications.
  void handleEvent(IpcEvent event) {
    switch (event) {
      case PluginChangedEvent e:
        _scheduleProcessorStateCapture(e.nodeId);
        return;
      case ProcessorParameterChangedEvent e:
        _handleParameterChanged(e);
        return;
      case ProcessorParameterGestureEvent e:
        _handleParameterGesture(e);
        return;
      case ProcessorParameterSnapshotEvent e:
        _handleParameterSnapshot(e);
        return;
      case ProcessorParameterResyncEvent e:
        _processorParameterGestureSessions.removeWhere(
          (key, _) => key.$1 == e.nodeId,
        );
        final node = project.processingGraph.nodes[e.nodeId];
        if (node == null) return;
        for (final parameter in e.parameterValues) {
          final port = _findParameterPort(node, parameter.controlPortId);
          _applyParameterValue(
            node,
            parameter.controlPortId,
            parameter.value,
            parameter.displayText,
            markTouched: port?.parameterValue != parameter.value,
          );
        }
        _scheduleProcessorStateCapture(e.nodeId);
        return;
      default:
        return;
    }
  }

  /// Discards unfinished parameter gestures from the stopped engine.
  void handleEngineStopped() {
    _processorParameterGestureSessions.clear();
  }

  void _scheduleProcessorStateCapture(Id nodeId) {
    project.processingGraph.nodes[nodeId]?.scheduleDebouncedStateUpdate();
  }

  NodePortModel? _findParameterPort(NodeModel node, int controlPortId) {
    for (final port in node.controlInputPorts) {
      if (port.id == controlPortId && port.config.parameterConfig != null) {
        return port;
      }
    }

    return null;
  }

  void _applyParameterValue(
    NodeModel node,
    int controlPortId,
    double rawValue,
    String? displayText, {
    required bool markTouched,
  }) {
    final port = _findParameterPort(node, controlPortId);
    if (port == null) return;
    if (markTouched) node.touchControlInputParameter(port);
    applyReportedParameterValues(node, [
      ProcessingGraphParameterValue(
        controlPortId: controlPortId,
        value: rawValue,
        displayText: displayText,
      ),
    ]);
  }

  void _handleParameterChanged(ProcessorParameterChangedEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    _applyParameterValue(
      node,
      event.controlPortId,
      event.value,
      event.displayText,
      markTouched: true,
    );

    _scheduleProcessorStateCapture(event.nodeId);
  }

  void _handleParameterGesture(ProcessorParameterGestureEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    final port = _findParameterPort(node, event.controlPortId);
    if (port == null) {
      return;
    }

    final key = (event.nodeId, event.controlPortId);

    _applyParameterValue(
      node,
      event.controlPortId,
      event.value,
      event.displayText,
      markTouched: false,
    );

    if (event.isStarting) {
      node.touchControlInputParameter(port);
      _processorParameterGestureSessions[key] =
          _ProcessorParameterGestureSession(
            oldValue: port.parameterValueOrResetTarget,
          );
      return;
    }

    final session = _processorParameterGestureSessions.remove(key);
    if (session == null) {
      return;
    }

    final newValue = port.parameterValueOrResetTarget;
    if (session.oldValue == newValue) {
      return;
    }

    project.push(
      SetParameterValueCommand(
        nodeId: event.nodeId,
        controlPortId: event.controlPortId,
        oldValue: session.oldValue,
        newValue: newValue,
      ),
    );
  }

  void _handleParameterSnapshot(ProcessorParameterSnapshotEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    for (final parameterValue in event.parameterValues) {
      _applyParameterValue(
        node,
        parameterValue.controlPortId,
        parameterValue.value,
        parameterValue.displayText,
        markTouched: false,
      );
    }
  }
}
