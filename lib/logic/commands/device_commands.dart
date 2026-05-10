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

import 'dart:math';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/track.dart';

class DeviceAddRemoveCommand extends Command {
  final bool _isAdd;
  final Id trackId;

  late final DeviceModel _device;
  int? _index;
  ProcessingGraphFragment? _graphFragment;

  DeviceAddRemoveCommand.add({
    required ProjectModel project,
    required this.trackId,
    required DeviceDescriptorForCommand device,
  }) : _isAdd = true {
    _getTrack(project, trackId, 'DeviceAddRemoveCommand.add');

    final idAllocator = ServiceRegistry.forProject(project.id).idAllocator;
    final createResult = DeviceFactories.create(
      idAllocator: idAllocator,
      descriptor: device,
    );

    _device = createResult.device;
    _index = device.index;
    _graphFragment = createResult.graphFragment;
  }

  DeviceAddRemoveCommand.remove({
    required ProjectModel project,
    required this.trackId,
    required Id deviceId,
  }) : _isAdd = false {
    final track = _getTrack(project, trackId, 'DeviceAddRemoveCommand.remove');
    final index = track.devices.indexWhere((device) => device.id == deviceId);
    if (index == -1) {
      throw StateError(
        'DeviceAddRemoveCommand.remove(): Device $deviceId not found on '
        'track $trackId.',
      );
    }

    _device = track.devices[index];
    _index = index;
  }

  @override
  void execute(ProjectModel project) {
    if (_isAdd) {
      _add(project);
    } else {
      _remove(project);
    }
  }

  @override
  void rollback(ProjectModel project) {
    if (_isAdd) {
      _remove(project);
    } else {
      _add(project);
    }
  }

  void _add(ProjectModel project) {
    final track = _getTrack(project, trackId, 'DeviceAddRemoveCommand._add');
    final graphFragment = _graphFragment;
    if (graphFragment == null) {
      throw StateError(
        'DeviceAddRemoveCommand._add(): No graph fragment is available '
        'for device ${_device.id}.',
      );
    }

    if (track.devices.any((device) => device.id == _device.id)) {
      throw StateError(
        'DeviceAddRemoveCommand._add(): Device ${_device.id} already '
        'exists on track $trackId.',
      );
    }

    final insertIndex = _index == null
        ? track.devices.length
        : min(_index!, track.devices.length);
    track.devices.insert(insertIndex, _device);
    _index ??= insertIndex;

    if (!graphFragment.isEmpty) {
      project.processingGraph.restoreGraphFragment(graphFragment);
    }

    _rebuildRoutingAndCompile(project);
  }

  void _remove(ProjectModel project) {
    final track = _getTrack(project, trackId, 'DeviceAddRemoveCommand._remove');
    final index = track.devices.indexWhere((device) => device.id == _device.id);
    if (index == -1) {
      throw StateError(
        'DeviceAddRemoveCommand._remove(): Device ${_device.id} not found '
        'on track $trackId.',
      );
    }
    _index ??= index;

    final deviceController = ServiceRegistry.forProject(
      project.id,
    ).deviceController;

    deviceController.disconnectTrackDeviceRouting(trackId);

    track.devices.removeAt(index);

    _graphFragment = project.processingGraph.removeNodesAndCapture(
      _device.nodeIds,
    );

    _rebuildRoutingAndCompile(project);
  }

  void _rebuildRoutingAndCompile(ProjectModel project) {
    final deviceController = ServiceRegistry.forProject(
      project.id,
    ).deviceController;

    deviceController.rebuildTrackDeviceRouting(trackId);
    project.engine.processingGraphApi.compile();
  }
}

class MoveTrackDeviceCommand extends Command {
  final Id trackId;
  final Id deviceId;
  final int newIndex;

  late int _oldIndex;

  MoveTrackDeviceCommand({
    required this.trackId,
    required this.deviceId,
    required this.newIndex,
  });

  @override
  void execute(ProjectModel project) {
    final track = _getTrack(project, trackId, 'MoveTrackDeviceCommand.execute');
    _oldIndex = _moveDevice(track, deviceId, newIndex);

    ServiceRegistry.forProject(
      project.id,
    ).deviceController.rebuildTrackDeviceRouting(trackId);
    project.engine.processingGraphApi.compile();
  }

  @override
  void rollback(ProjectModel project) {
    final track = _getTrack(
      project,
      trackId,
      'MoveTrackDeviceCommand.rollback',
    );
    _moveDevice(track, deviceId, _oldIndex);

    ServiceRegistry.forProject(
      project.id,
    ).deviceController.rebuildTrackDeviceRouting(trackId);
    project.engine.processingGraphApi.compile();
  }
}

TrackModel _getTrack(ProjectModel project, Id trackId, String caller) {
  final track = project.tracks[trackId];
  if (track == null) {
    throw StateError('$caller(): Track $trackId not found.');
  }

  return track;
}

int _moveDevice(TrackModel track, Id deviceId, int newIndex) {
  final oldIndex = track.devices.indexWhere((device) => device.id == deviceId);
  if (oldIndex == -1) {
    throw StateError(
      'MoveTrackDeviceCommand: Device $deviceId not found on track '
      '${track.id}.',
    );
  }

  final device = track.devices.removeAt(oldIndex);
  final boundedIndex = min(newIndex, track.devices.length);
  track.devices.insert(boundedIndex, device);

  return oldIndex;
}
