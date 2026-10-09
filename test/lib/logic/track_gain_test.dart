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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcessingGraphApi extends Fake implements ProcessingGraphApi {
  @override
  Future<ProcessingGraphNodeInitialization> initializeNodes() async =>
      ProcessingGraphNodeInitialization(didInitialize: true, results: []);

  @override
  Future<void> publish() async {}
}

NodePortModel _gainPort(ProjectModel project, Id trackId) => project
    .tracks[trackId]!
    .requireProcessing
    .utilityNode!
    .getPortById(UtilityProcessorModel.gainPortId);

void _expectGain(
  ProjectModel project,
  Id trackId, {
  required double valueDb,
  required double defaultDb,
}) {
  final port = _gainPort(project, trackId);
  expect(gainParameterValueToDb(port.parameterValue!), closeTo(valueDb, 1e-9));
  expect(
    gainParameterValueToDb(port.parameterResetTarget),
    closeTo(defaultDb, 1e-9),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectModel project;

  setUp(() {
    project = ProjectModel.create();
    project.engine.processingGraphApi = _FakeProcessingGraphApi();
    ServiceRegistry.initializeProject(project);
  });

  tearDown(() {
    ServiceRegistry.removeProject(project.id);
    project.dispose();
  });

  test('new projects start the regular track at -10 dB and master at 0 dB', () {
    _expectGain(
      project,
      project.trackOrder.single,
      valueDb: -10,
      defaultDb: -10,
    );
    _expectGain(
      project,
      project.sendTrackOrder.single,
      valueDb: 0,
      defaultDb: 0,
    );
  });

  for (final isSendTrack in [false, true]) {
    final kind = isSendTrack ? 'send' : 'regular';
    final expectedDb = isSendTrack ? 0.0 : -10.0;

    test('new $kind tracks use their default inside and outside groups', () {
      final controller = ServiceRegistry.forProject(project.id).trackController;
      if (isSendTrack) {
        controller.addSendTrack();
      } else {
        controller.addTrack();
      }
      final trackId = isSendTrack
          ? project.sendTrackOrder.first
          : project.trackOrder.last;
      _expectGain(project, trackId, valueDb: expectedDb, defaultDb: expectedDb);

      controller.groupTracks([trackId]);
      final groupId = isSendTrack
          ? project.sendTrackOrder.first
          : project.trackOrder.last;
      _expectGain(project, groupId, valueDb: 0, defaultDb: 0);

      controller.insertTrackAt(groupId);
      final childId = project.tracks[groupId]!.childTracks.last;
      expect(project.tracks[childId]!.parentTrackId, groupId);
      _expectGain(project, childId, valueDb: expectedDb, defaultDb: expectedDb);
    });
  }

  test('grouping and undo/redo preserve edited child and group levels', () {
    final controller = ServiceRegistry.forProject(project.id).trackController;
    final firstId = project.trackOrder.single;
    controller.addTrack();
    final secondId = project.trackOrder.last;
    _gainPort(project, firstId).parameterValue = gainDbToParameterValue(-4);
    _gainPort(project, secondId).parameterValue = gainDbToParameterValue(-7);

    controller.groupTracks([firstId, secondId]);
    final groupId = project.trackOrder.single;
    _expectGain(project, groupId, valueDb: 0, defaultDb: 0);
    _expectGain(project, firstId, valueDb: -4, defaultDb: -10);
    _expectGain(project, secondId, valueDb: -7, defaultDb: -10);
    _gainPort(project, groupId).parameterValue = gainDbToParameterValue(-2);

    project.undo();
    expect(project.tracks[groupId], isNull);
    expect(project.trackOrder, [firstId, secondId]);
    _expectGain(project, firstId, valueDb: -4, defaultDb: -10);
    _expectGain(project, secondId, valueDb: -7, defaultDb: -10);

    project.redo();
    _expectGain(project, groupId, valueDb: -2, defaultDb: 0);
    _expectGain(project, firstId, valueDb: -4, defaultDb: -10);
    _expectGain(project, secondId, valueDb: -7, defaultDb: -10);
  });

  test('undoing and redoing track creation retains its edited gain', () {
    ServiceRegistry.forProject(project.id).trackController.addTrack();
    final trackId = project.trackOrder.last;
    _gainPort(project, trackId).parameterValue = gainDbToParameterValue(-6);

    project.undo();
    expect(project.tracks[trackId], isNull);

    project.redo();
    _expectGain(project, trackId, valueDb: -6, defaultDb: -10);
  });

  test('reset uses each track default and supports undo/redo', () {
    final services = ServiceRegistry.forProject(project.id);
    final regularId = project.trackOrder.single;
    services.trackController.groupTracks([regularId]);
    final groupId = project.trackOrder.single;
    services.trackController.addSendTrack();
    final sendId = project.sendTrackOrder.first;
    final masterId = project.sendTrackOrder.last;

    for (final (trackId, defaultDb) in [
      (regularId, -10.0),
      (groupId, 0.0),
      (sendId, 0.0),
      (masterId, 0.0),
    ]) {
      final port = _gainPort(project, trackId);
      port.parameterValue = gainDbToParameterValue(-3);
      services.parameterController.resetToDefault(
        node: project.tracks[trackId]!.requireProcessing.utilityNode!,
        port: port,
      );
      _expectGain(project, trackId, valueDb: defaultDb, defaultDb: defaultDb);
      project.undo();
      _expectGain(project, trackId, valueDb: -3, defaultDb: defaultDb);
      project.redo();
      _expectGain(project, trackId, valueDb: defaultDb, defaultDb: defaultDb);
    }
  });

  test(
    'save/load preserves edited levels and track-specific defaults',
    () async {
      final controller = ServiceRegistry.forProject(project.id).trackController;
      final regularId = project.trackOrder.single;
      controller.groupTracks([regularId]);
      final groupId = project.trackOrder.single;
      controller.addSendTrack();
      final sendId = project.sendTrackOrder.first;
      final masterId = project.sendTrackOrder.last;
      _gainPort(project, regularId).parameterValue = gainDbToParameterValue(-6);
      _gainPort(project, groupId).parameterValue = gainDbToParameterValue(-2);
      _gainPort(project, sendId).parameterValue = gainDbToParameterValue(-4);

      final restored = ProjectModel.fromJson(
        await decodeProjectFileBytes(await encodeProjectFile(project)),
      );
      addTearDown(restored.dispose);

      _expectGain(restored, regularId, valueDb: -6, defaultDb: -10);
      _expectGain(restored, groupId, valueDb: -2, defaultDb: 0);
      _expectGain(restored, sendId, valueDb: -4, defaultDb: 0);
      _expectGain(restored, masterId, valueDb: 0, defaultDb: 0);
    },
  );

  test('loading an existing track retains its 0 dB default', () async {
    final trackId = project.trackOrder.single;
    final port = _gainPort(project, trackId);
    // Represent a saved track created before the new default was introduced.
    port.parameterResetValue = gainParameterZeroDbNormalized;
    port.parameterValue = gainDbToParameterValue(-5);

    final restored = ProjectModel.fromJson(
      await decodeProjectFileBytes(await encodeProjectFile(project)),
    );
    addTearDown(restored.dispose);

    _expectGain(restored, trackId, valueDb: -5, defaultDb: 0);
  });

  test('adding a utility device keeps its gain at 0 dB', () {
    final trackId = project.trackOrder.single;
    project.execute(
      DeviceAddRemoveCommand.add(
        project: project,
        trackId: trackId,
        device: DeviceDescriptorForCommand(type: DeviceType.utility),
      ),
    );

    final device = project.tracks[trackId]!.requireProcessing.devices.single;
    final gain = project.processingGraph.nodes[device.nodeIds.single]!
        .getPortById(UtilityProcessorModel.gainPortId);
    expect(gain.parameterValue, gainParameterZeroDbNormalized);
    expect(gain.parameterResetTarget, gainParameterZeroDbNormalized);
    _expectGain(project, trackId, valueDb: -10, defaultDb: -10);
  });
}
