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

import 'dart:io';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_connection.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/port_ref.dart';
import 'package:anthem/model/processing_graph/processors/live_event_provider.dart';
import 'package:anthem/model/processing_graph/processors/sequence_note_provider.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:file_picker/file_picker.dart';

typedef _DevicePortRef = ({
  DeviceModel device,
  ProcessingGraphPortRefModel port,
});

class DeviceController {
  final ProjectModel project;

  DeviceController(this.project);

  ProjectEntityIdAllocator get _idAllocator =>
      ServiceRegistry.maybeForProject(project.id)?.idAllocator ??
      project.idAllocator;

  Future<void> addDevice({
    required Id trackId,
    required DeviceType type,
    int? index,
  }) async {
    final descriptor = switch (type) {
      DeviceType.toneGenerator => DeviceDescriptorForCommand(
        type: DeviceType.toneGenerator,
        index: index,
      ),
      DeviceType.vst3Plugin => await _createVst3DeviceDescriptor(index: index),
    };

    if (descriptor == null) return;

    project.execute(
      DeviceAddRemoveCommand.add(
        project: project,
        trackId: trackId,
        device: descriptor,
      ),
    );
  }

  Future<DeviceDescriptorForCommand?> _createVst3DeviceDescriptor({
    int? index,
  }) async {
    final dialogController = ServiceRegistry.dialogController;
    String initialDirectory;

    if (Platform.isWindows) {
      initialDirectory = 'C:\\Program Files\\Common Files\\VST3';
    } else if (Platform.isMacOS) {
      initialDirectory = '/Library/Audio/Plug-Ins/VST3';
    } else if (Platform.isLinux) {
      initialDirectory = Platform.environment['HOME'] ?? '/';
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}',
      );
    }

    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a plugin (VST3)',
      allowedExtensions: Platform.isMacOS ? null : ['vst3'],
      initialDirectory: initialDirectory,
      type: Platform.isMacOS ? FileType.custom : FileType.any,
    );

    final path = result?.files[0].path;

    if (path?.toLowerCase().endsWith('.vst3') != true) {
      dialogController.showTextDialog(
        title: 'Error',
        text:
            'The selected plugin could not be loaded. It may '
            'not be a valid VST3 plugin, or it may be incompatible.',
        buttons: [DialogButton.ok()],
      );
      return null;
    }

    return DeviceDescriptorForCommand(
      type: DeviceType.vst3Plugin,
      index: index,
      vst3Path: path!,
    );
  }

  void removeDevice({required Id trackId, required Id deviceId}) {
    project.execute(
      DeviceAddRemoveCommand.remove(
        project: project,
        trackId: trackId,
        deviceId: deviceId,
      ),
    );
  }

  void moveDevice({
    required Id trackId,
    required Id deviceId,
    required int newIndex,
  }) {
    project.execute(
      MoveTrackDeviceCommand(
        trackId: trackId,
        deviceId: deviceId,
        newIndex: newIndex,
      ),
    );
  }

  void disconnectTrackDeviceRouting(Id trackId) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'DeviceController.disconnectTrackDeviceRouting(): Track $trackId not '
        'found.',
      );
    }

    for (final connectionId in track.deviceRoutingConnectionIds.toList()) {
      if (project.processingGraph.connections[connectionId] != null) {
        project.processingGraph.removeConnection(connectionId);
      }
    }

    track.deviceRoutingConnectionIds.clear();
  }

  void rebuildTrackDeviceRouting(Id trackId) {
    final track = project.tracks[trackId];
    if (track == null) {
      throw StateError(
        'DeviceController.rebuildTrackDeviceRouting(): Track $trackId not '
        'found.',
      );
    }

    disconnectTrackDeviceRouting(trackId);

    final generatedConnectionIds = <Id>[];

    void addConnection({
      required Id sourceNodeId,
      required int sourcePortId,
      required Id destinationNodeId,
      required int destinationPortId,
    }) {
      final connection = NodeConnectionModel(
        idAllocator: _idAllocator,
        sourceNodeId: sourceNodeId,
        sourcePortId: sourcePortId,
        destinationNodeId: destinationNodeId,
        destinationPortId: destinationPortId,
      );
      project.processingGraph.addConnection(connection);
      generatedConnectionIds.add(connection.id);
    }

    final firstEventInput = _firstExistingDefaultPort(
      track.devices,
      NodePortDataType.event,
      _PortDirection.input,
    );
    if (firstEventInput != null) {
      _connectTrackEventProviders(
        track: track,
        destination: firstEventInput.port,
        addConnection: addConnection,
      );
    }

    final audioConnectedDevicePairs = <(Id, Id)>{};
    _DevicePortRef? lastAudioOutput;

    // First pass: build the sparse audio chain in rack order. Devices without
    // a compatible audio input are skipped, and the last chainable audio output
    // is carried forward to the next compatible device.
    for (final device in track.devices) {
      var connectedAudioIntoDevice = false;
      final audioInput = _existingDefaultPort(
        device,
        NodePortDataType.audio,
        _PortDirection.input,
      );
      if (lastAudioOutput != null && audioInput != null) {
        addConnection(
          sourceNodeId: lastAudioOutput.port.nodeId,
          sourcePortId: lastAudioOutput.port.portId,
          destinationNodeId: audioInput.nodeId,
          destinationPortId: audioInput.portId,
        );
        audioConnectedDevicePairs.add((lastAudioOutput.device.id, device.id));
        connectedAudioIntoDevice = true;
      }

      final audioOutput = _existingDefaultPort(
        device,
        NodePortDataType.audio,
        _PortDirection.output,
      );
      if (audioOutput != null &&
          (lastAudioOutput == null || connectedAudioIntoDevice)) {
        lastAudioOutput = (device: device, port: audioOutput);
      }
    }

    if (lastAudioOutput != null) {
      final utilityInput = _trackUtilityInput(track);
      if (utilityInput != null) {
        addConnection(
          sourceNodeId: lastAudioOutput.port.nodeId,
          sourcePortId: lastAudioOutput.port.portId,
          destinationNodeId: utilityInput.nodeId,
          destinationPortId: utilityInput.portId,
        );
      }
    }

    _DevicePortRef? lastEventOutput;
    // Second pass: build the sparse event chain, but skip device pairs that
    // were already connected by audio so audio remains the preferred path.
    for (final device in track.devices) {
      var connectedEventIntoDevice = false;
      final eventInput = _existingDefaultPort(
        device,
        NodePortDataType.event,
        _PortDirection.input,
      );
      if (lastEventOutput != null &&
          eventInput != null &&
          !audioConnectedDevicePairs.contains((
            lastEventOutput.device.id,
            device.id,
          ))) {
        addConnection(
          sourceNodeId: lastEventOutput.port.nodeId,
          sourcePortId: lastEventOutput.port.portId,
          destinationNodeId: eventInput.nodeId,
          destinationPortId: eventInput.portId,
        );
        connectedEventIntoDevice = true;
      }

      final eventOutput = _existingDefaultPort(
        device,
        NodePortDataType.event,
        _PortDirection.output,
      );
      if (eventOutput != null &&
          (lastEventOutput == null || connectedEventIntoDevice)) {
        lastEventOutput = (device: device, port: eventOutput);
      }
    }

    track.deviceRoutingConnectionIds.addAll(generatedConnectionIds);
  }

  void _connectTrackEventProviders({
    required TrackModel track,
    required ProcessingGraphPortRefModel destination,
    required void Function({
      required Id sourceNodeId,
      required int sourcePortId,
      required Id destinationNodeId,
      required int destinationPortId,
    })
    addConnection,
  }) {
    final sequenceProviderNode =
        project.processingGraph.nodes[track.sequenceNoteProviderNodeId];
    if (sequenceProviderNode?.eventOutputPorts.isNotEmpty == true) {
      addConnection(
        sourceNodeId: sequenceProviderNode!.id,
        sourcePortId: SequenceNoteProviderProcessorModel.eventOutputPortId,
        destinationNodeId: destination.nodeId,
        destinationPortId: destination.portId,
      );
    }

    final liveEventProviderNode =
        project.processingGraph.nodes[track.liveEventProviderNodeId];
    if (liveEventProviderNode?.eventOutputPorts.isNotEmpty == true) {
      addConnection(
        sourceNodeId: liveEventProviderNode!.id,
        sourcePortId: LiveEventProviderProcessorModel.eventOutputPortId,
        destinationNodeId: destination.nodeId,
        destinationPortId: destination.portId,
      );
    }
  }

  ProcessingGraphPortRefModel? _trackUtilityInput(TrackModel track) {
    final utilityNode = project.processingGraph.nodes[track.utilityNodeId];
    if (utilityNode == null || utilityNode.audioInputPorts.isEmpty) {
      return null;
    }

    return ProcessingGraphPortRefModel(
      nodeId: utilityNode.id,
      portId: UtilityProcessorModel.audioInputPortId,
    );
  }

  _DevicePortRef? _firstExistingDefaultPort(
    Iterable<DeviceModel> devices,
    NodePortDataType dataType,
    _PortDirection direction,
  ) {
    for (final device in devices) {
      final port = _existingDefaultPort(device, dataType, direction);
      if (port != null) {
        return (device: device, port: port);
      }
    }

    return null;
  }

  ProcessingGraphPortRefModel? _existingDefaultPort(
    DeviceModel device,
    NodePortDataType dataType,
    _PortDirection direction,
  ) {
    final ref = switch ((dataType, direction)) {
      (NodePortDataType.audio, _PortDirection.input) =>
        device.defaultAudioInputPort,
      (NodePortDataType.audio, _PortDirection.output) =>
        device.defaultAudioOutputPort,
      (NodePortDataType.event, _PortDirection.input) =>
        device.defaultEventInputPort,
      (NodePortDataType.event, _PortDirection.output) =>
        device.defaultEventOutputPort,
      (NodePortDataType.control, _) => null,
    };
    if (ref == null) {
      return null;
    }

    final node = project.processingGraph.nodes[ref.nodeId];
    if (node == null) {
      return null;
    }

    final port = _tryGetPortById(node, ref.portId);
    if (port == null || port.type != dataType) {
      return null;
    }

    return ref;
  }

  NodePortModel? _tryGetPortById(NodeModel node, int portId) {
    try {
      return node.getPortById(portId);
    } on Exception {
      return null;
    }
  }
}

enum _PortDirection { input, output }
