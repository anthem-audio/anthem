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

import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';

enum DevicePortDirection { input, output }

typedef DevicePortRef = ({
  DeviceModel device,
  ProcessingGraphPortRefModel port,
});

class DevicePortDefaults {
  final ProcessingGraphModel processingGraph;

  const DevicePortDefaults(this.processingGraph);

  void refreshDeviceDefaultPorts(
    DeviceModel device, {
    bool preserveExistingValidDefaults = true,
  }) {
    device.defaultAudioInputPort = _refreshedDefaultPort(
      device,
      NodePortDataType.audio,
      DevicePortDirection.input,
      preserveExistingValidDefaults,
    );
    device.defaultAudioOutputPort = _refreshedDefaultPort(
      device,
      NodePortDataType.audio,
      DevicePortDirection.output,
      preserveExistingValidDefaults,
    );
    device.defaultEventInputPort = _refreshedDefaultPort(
      device,
      NodePortDataType.event,
      DevicePortDirection.input,
      preserveExistingValidDefaults,
    );
    device.defaultEventOutputPort = _refreshedDefaultPort(
      device,
      NodePortDataType.event,
      DevicePortDirection.output,
      preserveExistingValidDefaults,
    );
  }

  DevicePortRef? firstExistingDefaultPort(
    Iterable<DeviceModel> devices,
    NodePortDataType dataType,
    DevicePortDirection direction,
  ) {
    for (final device in devices) {
      final port = existingDefaultPort(device, dataType, direction);
      if (port != null) {
        return (device: device, port: port);
      }
    }

    return null;
  }

  ProcessingGraphPortRefModel? existingDefaultPort(
    DeviceModel device,
    NodePortDataType dataType,
    DevicePortDirection direction,
  ) {
    final ref = _defaultPortRef(device, dataType, direction);
    if (ref == null || !device.nodeIds.contains(ref.nodeId)) {
      return null;
    }

    final node = processingGraph.nodes[ref.nodeId];
    if (node == null) {
      return null;
    }

    final port = _tryGetPortById(node, ref.portId);
    if (port == null ||
        port.type != dataType ||
        !_portsFor(node, dataType, direction).contains(port)) {
      return null;
    }

    return ref;
  }

  ProcessingGraphPortRefModel? firstDevicePort(
    DeviceModel device,
    NodePortDataType dataType,
    DevicePortDirection direction,
  ) {
    for (final node in _ownedNodes(device)) {
      final ports = _portsFor(node, dataType, direction);
      if (ports.isNotEmpty) {
        return ProcessingGraphPortRefModel(
          nodeId: node.id,
          portId: ports.first.id,
        );
      }
    }

    return null;
  }

  ProcessingGraphPortRefModel? _refreshedDefaultPort(
    DeviceModel device,
    NodePortDataType dataType,
    DevicePortDirection direction,
    bool preserveExistingValidDefaults,
  ) {
    if (preserveExistingValidDefaults) {
      final existing = existingDefaultPort(device, dataType, direction);
      if (existing != null) {
        return existing;
      }
    }

    return firstDevicePort(device, dataType, direction);
  }

  ProcessingGraphPortRefModel? _defaultPortRef(
    DeviceModel device,
    NodePortDataType dataType,
    DevicePortDirection direction,
  ) {
    return switch ((dataType, direction)) {
      (NodePortDataType.audio, DevicePortDirection.input) =>
        device.defaultAudioInputPort,
      (NodePortDataType.audio, DevicePortDirection.output) =>
        device.defaultAudioOutputPort,
      (NodePortDataType.event, DevicePortDirection.input) =>
        device.defaultEventInputPort,
      (NodePortDataType.event, DevicePortDirection.output) =>
        device.defaultEventOutputPort,
      (NodePortDataType.control, _) => null,
    };
  }

  Iterable<NodeModel> _ownedNodes(DeviceModel device) sync* {
    for (final nodeId in device.nodeIds) {
      final node = processingGraph.nodes[nodeId];
      if (node != null) {
        yield node;
      }
    }
  }

  Iterable<NodePortModel> _portsFor(
    NodeModel node,
    NodePortDataType dataType,
    DevicePortDirection direction,
  ) {
    return switch ((dataType, direction)) {
      (NodePortDataType.audio, DevicePortDirection.input) =>
        node.audioInputPorts,
      (NodePortDataType.audio, DevicePortDirection.output) =>
        node.audioOutputPorts,
      (NodePortDataType.event, DevicePortDirection.input) =>
        node.eventInputPorts,
      (NodePortDataType.event, DevicePortDirection.output) =>
        node.eventOutputPorts,
      (NodePortDataType.control, DevicePortDirection.input) =>
        node.controlInputPorts,
      (NodePortDataType.control, DevicePortDirection.output) =>
        node.controlOutputPorts,
    };
  }

  NodePortModel? _tryGetPortById(NodeModel node, int portId) {
    try {
      return node.getPortById(portId);
    } on Exception {
      return null;
    }
  }
}
