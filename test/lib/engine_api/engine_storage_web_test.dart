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

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/project_file/archive.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/engine_api/engine_connector_web.dart';
import 'package:anthem/logic/commands/processor_state_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:anthem/logic/storage/file_fingerprint.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/browser_engine_test_helpers.dart';
import '../../helpers/browser_asset_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skipEngineTests =
      globalContext.getProperty('SharedArrayBuffer'.toJS).isA<JSFunction>()
      ? false
      : 'The browser engine requires shared memory; use Flutter --wasm '
            'to run it in an isolated test iframe.';
  setUpAll(() async {
    useBrowserPackageAssets();
    await loadBrowserModule('AnthemFileSystem');
    await loadBrowserModule('AnthemEngine', usesWorkers: true);
  });

  late ProjectModel project;
  late ServiceRegistry services;
  setUp(() {
    project = ProjectModel.create();
    services = ServiceRegistry.initializeProject(project);
  });
  tearDown(() async {
    await project.dispose();
    await services.projectStorage.discard();
    ServiceRegistry.removeProject(project.id);
  });

  Future<void> start() async {
    await services.projectEngineController.start(startAudio: false);
    expect(project.engine.engineState, EngineState.running);
    await project.engine.renderApi.startRenderAudioSession(
      sampleRate: 48000,
      blockSize: 128,
      outputChannelCount: 2,
    );
    await services.processingGraphController.publish();
  }

  test(
    'C++ snapshots are readable in Dart and survive browser engine restarts',
    () async {
      await start();
      final node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.3,
      );
      final snapshot = await services.processingGraphController.saveSnapshot(
        node.id,
      );
      addTearDown(snapshot.dispose);
      final reader = await services.projectStorage.openScope();
      try {
        final grant = reader.acquireRead(snapshot.relativePath);
        final before = await files.readFile(grant.absolutePath);
        expect(utf8.decode(before.sublist(0, 8)), 'ANTHST01');
        final metadataLength = ByteData.sublistView(
          before,
          8,
          12,
        ).getUint32(0, Endian.little);
        expect(metadataLength, inInclusiveRange(1, before.length - 12));
        expect(
          jsonDecode(utf8.decode(before.sublist(12, 12 + metadataLength))),
          containsPair('version', 1),
        );
        expect(
          (await reader.getFingerprint(grant.token)).toJson(),
          FileFingerprint.fromBytes(before).toJson(),
        );
        reader.releaseRead(grant.token);
        await project.engine.stop();
        expect(project.engine.engineState, EngineState.stopped);
        expect(snapshot.isDisposed, isFalse);
        final afterStop = reader.acquireRead(snapshot.relativePath);
        expect(await files.readFile(afterStop.absolutePath), before);
        reader.releaseRead(afterStop.token);

        await start();
        await services.parameterController.setValue(
          node: node,
          port: port,
          value: 0.7,
        );
        await services.processingGraphController.loadSnapshot(
          node.id,
          snapshot,
        );
        expect(port.parameterValue, closeTo(0.3, 0.000001));
      } finally {
        await reader.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );

  test(
    'project ZIP restores captured processor state after source files are removed',
    () async {
      await start();
      final node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.35,
      );
      final prepared = await PreparedProjectSave.prepare(
        project,
        services.projectStorage,
      );
      late final Uint8List zip;
      try {
        await services.parameterController.setValue(
          node: node,
          port: port,
          value: 0.85,
        );
        zip = await encodeProjectArchive(prepared);
      } finally {
        await prepared.close();
      }
      await project.engine.stop();
      await services.projectStorage.discard();
      final extracted = await extractProjectArchiveBytes(zip);
      final storage = ProjectStorage.temporary(
        rootDirectory: extracted.rootDirectory,
      );
      ProjectModel? imported;
      try {
        final json = await decodeProjectFileBytes(
          await files.readFile(extracted.documentPath),
        );
        json['id'] = getProjectId();
        imported = ProjectModel.fromJson(json);
        await storage.restoreProjectFiles(
          Map<String, String>.from(jsonDecode(imported.fileRetentions) as Map),
        );
        final registry = ServiceRegistry.initializeProject(imported)
          ..register(storage);
        await registry.projectEngineController.start(startAudio: false);
        await imported.engine.renderApi.startRenderAudioSession(
          sampleRate: 48000,
          blockSize: 128,
          outputChannelCount: 2,
        );
        await registry.processingGraphController.publish();
        final restored = imported.processingGraph.nodes[node.id]!.getPortById(
          UtilityProcessorModel.gainPortId,
        );
        expect(restored.parameterValue, closeTo(0.35, 0.000001));
      } finally {
        await imported?.dispose();
        await storage.discard();
        if (imported != null) ServiceRegistry.removeProject(imported.id);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );

  test(
    'snapshot undo and redo retain files across browser engine restarts',
    () async {
      await start();
      final node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.2,
      );
      final snapshot = await services.processingGraphController.saveSnapshot(
        node.id,
      );
      final command = LoadProcessorSnapshotCommand(
        nodeId: node.id,
        snapshot: snapshot,
      );
      snapshot.dispose();
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.8,
      );
      await project.execute(command);
      expect(port.parameterValue, closeTo(0.2, 0.000001));
      await project.engine.stop();
      await start();
      await project.undo();
      expect(port.parameterValue, closeTo(0.8, 0.000001));
      await project.redo();
      expect(port.parameterValue, closeTo(0.2, 0.000001));
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );

  test(
    'invalid snapshots report an error and preserve the running processor',
    () async {
      await start();
      final node = project
          .tracks[project.trackOrder.first]!
          .requireProcessing
          .utilityNode!;
      final port = node.getPortById(UtilityProcessorModel.gainPortId);
      await services.parameterController.setValue(
        node: node,
        port: port,
        value: 0.4,
      );
      final snapshot = await services.processingGraphController.saveSnapshot(
        node.id,
      );
      addTearDown(snapshot.dispose);
      final access = await services.projectStorage.openScope();
      try {
        final read = access.acquireRead(snapshot.relativePath);
        await files.writeFile(
          read.absolutePath,
          utf8.encode('invalid snapshot'),
        );
        access.releaseRead(read.token);
        await services.parameterController.setValue(
          node: node,
          port: port,
          value: 0.6,
        );
        await expectLater(
          services.processingGraphController.loadSnapshot(node.id, snapshot),
          throwsStateError,
        );
        expect(project.engine.engineState, EngineState.running);
        expect(port.parameterValue, closeTo(0.6, 0.000001));
        expect(node.canEditParameters, isTrue);
      } finally {
        await access.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );

  test(
    'cancelling browser engine startup waits for runtime shutdown',
    () async {
      final starting = project.engine.start(initializeAudio: false);
      final stopping = project.engine.stop();
      await starting;
      await stopping;
      expect(project.engine.engineState, EngineState.stopped);
      await start();
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );

  test(
    'a shutdown timeout does not abandon browser runtime cleanup',
    () async {
      final connector = EngineConnector(
        0,
        kDebugMode: false,
        noHeartbeat: true,
      );
      addTearDown(connector.shutdown);
      await expectLater(
        connector.shutdown(timeout: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      await connector.shutdown(timeout: const Duration(seconds: 30));
      expect(connector.processExitCode, 0);
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: skipEngineTests,
  );
}
