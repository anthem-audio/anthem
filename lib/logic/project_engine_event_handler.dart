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

class _PluginParameterGestureSession {
  final double oldValue;

  const _PluginParameterGestureSession({required this.oldValue});
}

/// Applies plugin events from the engine to a project's model and undo history.
///
/// `Engine` creates and owns this handler for its project and notifies it when
/// the engine stops so unfinished parameter gestures can be discarded.
class ProjectEngineEventHandler {
  final ProjectModel project;

  final Map<(Id, int), _PluginParameterGestureSession>
  _pluginParameterGestureSessions = {};

  ProjectEngineEventHandler(this.project);

  /// Applies plugin parameter, state-change, and loading notifications.
  void handleEvent(IpcEvent event) {
    switch (event) {
      case PluginChangedEvent e:
        _scheduleNodeStateUpdate(e.nodeId);
        return;
      case PluginParameterChangedEvent e:
        _handlePluginParameterChanged(e);
        return;
      case PluginParameterGestureEvent e:
        _handlePluginParameterGesture(e);
        return;
      case PluginParameterSnapshotEvent e:
        _handlePluginParameterSnapshot(e);
        return;
      case PluginLoadedEvent e:
        final node = project.processingGraph.nodes[e.nodeId];
        if (node == null) {
          return;
        }

        final completer = node.pluginLoadedCompleter;

        // Ignore repeated loading notifications.
        if (completer.isCompleted) return;

        completer.complete();
        return;
      default:
        return;
    }
  }

  /// Discards unfinished parameter gestures from the stopped engine.
  void handleEngineStopped() {
    _pluginParameterGestureSessions.clear();
  }

  void _scheduleNodeStateUpdate(Id nodeId) {
    project.processingGraph.nodes[nodeId]?.scheduleDebouncedStateUpdate();
  }

  NodePortModel? _findPluginParameterPort(NodeModel node, int controlPortId) {
    for (final port in node.controlInputPorts) {
      if (port.id == controlPortId && port.config.parameterConfig != null) {
        return port;
      }
    }

    return null;
  }

  void _applyPluginParameterValue(
    NodeModel node,
    int controlPortId,
    double rawValue,
    String? displayText, {
    required bool markTouched,
  }) {
    final value = rawValue.clamp(0.0, 1.0).toDouble();
    final port = _findPluginParameterPort(node, controlPortId);

    if (port == null) {
      return;
    }

    if (markTouched) {
      node.touchControlInputParameter(port);
    }

    if (port.parameterValue != value) {
      port.parameterValue = value;
    }

    if (port.parameterDisplayText != displayText) {
      port.parameterDisplayText = displayText;
    }
  }

  void _handlePluginParameterChanged(PluginParameterChangedEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    _applyPluginParameterValue(
      node,
      event.controlPortId,
      event.value,
      event.displayText,
      markTouched: true,
    );

    _scheduleNodeStateUpdate(event.nodeId);
  }

  void _handlePluginParameterGesture(PluginParameterGestureEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    final port = _findPluginParameterPort(node, event.controlPortId);
    if (port == null) {
      return;
    }

    final key = (event.nodeId, event.controlPortId);

    if (event.isStarting) {
      node.touchControlInputParameter(port);
      _pluginParameterGestureSessions[key] = _PluginParameterGestureSession(
        oldValue: SetParameterValueCommand.effectiveParameterValue(port),
      );
      return;
    }

    final session = _pluginParameterGestureSessions.remove(key);
    if (session == null) {
      return;
    }

    final newValue = SetParameterValueCommand.effectiveParameterValue(port);
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

  void _handlePluginParameterSnapshot(PluginParameterSnapshotEvent event) {
    final node = project.processingGraph.nodes[event.nodeId];
    if (node == null) {
      return;
    }

    for (final parameterValue in event.parameterValues) {
      _applyPluginParameterValue(
        node,
        parameterValue.controlPortId,
        parameterValue.value,
        parameterValue.displayText,
        markTouched: false,
      );
    }
  }
}
