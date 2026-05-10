/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/gain_parameter_mapping.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/commands/pattern_commands.dart';
import 'package:anthem/logic/commands/pattern_note_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/model/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anthem/engine_api/engine_connector_desktop.dart';

var id = 0;
Id getId() => id++;

const skipEngineIntegrationTests = false;

Future<T> _sendRequestAndWaitForReply<T extends Response>({
  required EngineConnector engineConnector,
  required Request request,
  required Stream<Response> replyStream,
}) async {
  final replyFuture = replyStream.firstWhere((reply) => reply.id == request.id);

  final encoder = JsonUtf8Encoder();
  engineConnector.send(encoder.convert(request.toJson()) as Uint8List);

  return (await replyFuture) as T;
}

void main() {
  var path = Platform.script;
  while (path.pathSegments.length > 1 &&
      File(path.resolve('pubspec.yaml').toFilePath()).existsSync() == false) {
    path = path.resolve('../');
  }

  final releaseEnginePath = path.resolve(
    'engine/build_release/AnthemEngine_artefacts/Release/AnthemEngine${Platform.isWindows ? '.exe' : ''}',
  );

  final debugEnginePath = path.resolve(
    'engine/build/AnthemEngine_artefacts/Debug/AnthemEngine${Platform.isWindows ? '.exe' : ''}',
  );

  Uri? enginePath;

  // This looks for the debug build of the engine first, then the release build.
  //
  // In CI, we use the release build since that's what we're releasing, and it means
  // we don't have to build twice. When developing locally, we expect that the debug
  // engine will be the most up-to-date, so we use that by default.
  if (File(
    debugEnginePath.toFilePath(windows: Platform.isWindows),
  ).existsSync()) {
    enginePath = debugEnginePath;
  } else if (File(
    releaseEnginePath.toFilePath(windows: Platform.isWindows),
  ).existsSync()) {
    enginePath = releaseEnginePath;
  } else {
    throw Exception(
      'No engine found at $releaseEnginePath or $debugEnginePath. '
      'Please build the engine before running the tests.',
    );
  }

  group('Heartbeat tests', () {
    test('No heartbeat', timeout: Timeout(Duration(seconds: 120)), () async {
      final exitStreamController = StreamController<void>.broadcast();

      var exitCalled = false;
      exitStreamController.stream.first.then((_) => exitCalled = true);

      var heartbeatWaitCompleter = Completer<void>();

      final _ = EngineConnector(
        12345678, // Can't collide with any other tests
        enginePathOverride: enginePath!.toFilePath(windows: Platform.isWindows),
        kDebugMode: true,
        noHeartbeat: true,
        onExit: () => exitStreamController.add(null),
      );

      expect(
        exitCalled,
        isFalse,
        reason: 'The engine should not crash when it first starts.',
      );

      final startTime = DateTime.now();

      Timer.periodic(Duration(milliseconds: 500), (timer) {
        if (exitCalled) {
          heartbeatWaitCompleter.complete();
          timer.cancel();
        }

        if (DateTime.now().difference(startTime).inSeconds > 30) {
          heartbeatWaitCompleter.complete();
          timer.cancel();
        }
      });

      await heartbeatWaitCompleter.future;

      expect(
        exitCalled,
        isTrue,
        reason: 'The engine should exit if it does not receive a heartbeat.',
      );
    });

    test('Heartbeat', timeout: Timeout(Duration(seconds: 120)), () async {
      final exitStreamController = StreamController<void>.broadcast();

      var exitCalled = false;
      exitStreamController.stream.first.then((_) => exitCalled = true);

      var heartbeatWaitCompleter = Completer<void>();

      final engineConnector = EngineConnector(
        12345678 + 1, // Can't collide with any other tests
        enginePathOverride: enginePath!.toFilePath(windows: Platform.isWindows),
        kDebugMode: true,
        onExit: () => exitStreamController.add(null),
      );

      expect(
        await engineConnector.onInit,
        isTrue,
        reason: 'The engine connector should initialize successfully.',
      );

      // Heartbeat startup belongs to Engine.start(). Engine wraps
      // EngineConnector. Since we are testing the bare EngineConnector, we need
      // to start the heartbeat timer manually.
      engineConnector.startHeartbeatTimer();

      exitCalled = false;

      exitStreamController.stream.first.then((_) => exitCalled = true);

      expect(
        exitCalled,
        isFalse,
        reason: 'The engine should not crash when it first starts.',
      );

      heartbeatWaitCompleter = Completer<void>();

      Timer(Duration(seconds: 15), () {
        heartbeatWaitCompleter.complete();
      });

      await heartbeatWaitCompleter.future;

      expect(
        exitCalled,
        isFalse,
        reason: 'The engine should not exit if it receives a heartbeat.',
      );

      engineConnector.dispose();
      await exitStreamController.stream.first;

      expect(
        exitCalled,
        isTrue,
        reason: 'The engine should exit when disposed.',
      );
    });
  }, skip: skipEngineIntegrationTests);

  group('Gain parameter mapping tests', () {
    test(
      'samples the engine gain curve without sending a project model',
      timeout: Timeout(Duration(seconds: 120)),
      () async {
        final exitStreamController = StreamController<void>.broadcast();
        final replyStreamController = StreamController<Response>.broadcast();

        final engineConnector = EngineConnector(
          12345678 + 2,
          enginePathOverride: enginePath!.toFilePath(
            windows: Platform.isWindows,
          ),
          kDebugMode: true,
          onReply: replyStreamController.add,
          onExit: () => exitStreamController.add(null),
        );

        expect(
          await engineConnector.onInit,
          isTrue,
          reason: 'The engine connector should initialize successfully.',
        );

        const parameterSamples = <double>[
          0.0,
          0.01,
          0.01001,
          0.02,
          0.25,
          0.5,
          0.75,
          gainParameterZeroDbNormalized,
          1.0,
        ];
        final sampleRequest = TestSampleGainCurveRequest(
          id: engineConnector.getRequestId(),
          parameterValues: parameterSamples,
        );

        final sampleResponse =
            await _sendRequestAndWaitForReply<TestSampleGainCurveResponse>(
              engineConnector: engineConnector,
              request: sampleRequest,
              replyStream: replyStreamController.stream,
            );

        expect(sampleResponse.dbValues, hasLength(parameterSamples.length));
        expect(
          sampleResponse.isNegativeInfinity,
          hasLength(parameterSamples.length),
        );

        for (var i = 0; i < parameterSamples.length; i++) {
          final expectedDb = gainParameterValueToDb(parameterSamples[i]);
          if (expectedDb.isInfinite && expectedDb.isNegative) {
            expect(sampleResponse.isNegativeInfinity[i], isTrue);
          } else {
            expect(sampleResponse.isNegativeInfinity[i], isFalse);
            expect(sampleResponse.dbValues[i], closeTo(expectedDb, 0.0003));
          }
        }

        await _sendRequestAndWaitForReply<ExitReply>(
          engineConnector: engineConnector,
          request: Exit(id: engineConnector.getRequestId()),
          replyStream: replyStreamController.stream,
        );

        await exitStreamController.stream.first.timeout(Duration(seconds: 5));

        await replyStreamController.close();
        await exitStreamController.close();
      },
    );
  }, skip: skipEngineIntegrationTests);

  group('Model sync tests', () {
    late ProjectModel project;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      project = ProjectModel.create(
        enginePath!.toFilePath(windows: Platform.isWindows),
      );
      ServiceRegistry.initializeProject(project);
      await project.engine.start(initializeAudio: false);
      expect(
        project.engine.engineState,
        EngineState.running,
        reason:
            'Model sync tests require the engine IPC and model sync layers to start successfully.',
      );
    });

    tearDownAll(() async {
      await project.engine.stop();
      ServiceRegistry.removeProject(project.id);
    });

    test('Test initial state', () async {
      // The initial state should be sent to the engine when it starts via
      // project.engine.modelSyncApi.initModel().

      final initialState =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      expect(
        initialState['sequence'],
        isNotNull,
        reason: 'The initial state should contain a sequence.',
      );
      expect(
        initialState['processingGraph'],
        isNotNull,
        reason: 'The initial state should contain a processing graph.',
      );
      expect(
        initialState['isDirty'],
        isNotNull,
        reason:
            'The initial state should contain isDirty - this is not in the project file.',
      );
    });

    test('Add a bunch of patterns', () async {
      final patternCount = 100;
      final expectedPatternNames = <String>{};

      for (var i = 0; i < patternCount; i++) {
        final command = PatternAddRemoveCommand.add(
          pattern: PatternModel(
            idAllocator: ProjectEntityIdAllocator.test(getId),
            name: 'Pattern $i',
          ),
        );
        project.execute(command);
        expectedPatternNames.add('Pattern $i');
      }

      final state =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      final patternMap = state['sequence']!['patterns'] as Map<String, dynamic>;

      expect(
        patternMap.length,
        equals(patternCount),
        reason: 'The pattern map should contain $patternCount patterns.',
      );

      final actualPatternNames = patternMap.values
          .cast<Map<String, dynamic>>()
          .map((pattern) => pattern['name'] as String)
          .toSet();

      expect(
        actualPatternNames,
        equals(expectedPatternNames),
        reason: 'The synced pattern set should match the project pattern set.',
      );
    });

    // test('Delete every even pattern', () async {
    //   final originalPatternListSize = project.sequence.patternOrder.length;

    //   for (var i = originalPatternListSize - 1; i >= 0; i--) {
    //     if (i.isEven) {
    //       final command = DeletePatternCommand(
    //         pattern:
    //             project.sequence.patterns[project.sequence.patternOrder[i]]!,
    //         index: i,
    //       );
    //       project.execute(command);
    //     }
    //   }

    //   final state =
    //       jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
    //           as Map<String, dynamic>;

    //   final patternMap = state['sequence']!['patterns'] as Map<String, dynamic>;
    //   final patternIdList =
    //       (state['sequence']!['patternOrder'] as List<dynamic>).cast<String>();

    //   expect(
    //     patternMap.length,
    //     equals(originalPatternListSize ~/ 2),
    //     reason:
    //         'The pattern map should contain ${originalPatternListSize ~/ 2} patterns.',
    //   );

    //   for (var i = 0; i < patternIdList.length; i++) {
    //     final id = patternIdList[i];
    //     final pattern = patternMap[id] as Map<String, dynamic>;
    //     expect(
    //       pattern['name'],
    //       equals('Pattern ${i * 2 + 1}'),
    //       reason: 'Pattern ${i * 2 + 1} should have the correct name.',
    //     );
    //   }
    // });

    test('Add a track device and some notes', () async {
      final instrumentTrackId = project.trackOrder.first;
      final instrumentTrack = project.tracks[instrumentTrackId]!;

      project.execute(
        DeviceAddRemoveCommand.add(
          project: project,
          trackId: instrumentTrack.id,
          device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
        ),
      );
      final instrumentNodeId = instrumentTrack.devices.single.nodeIds.single;

      final command = AddNoteCommand(
        patternID: project.sequence.patterns.keys.first,
        note: NoteModel(
          idAllocator: ProjectEntityIdAllocator.test(getId),
          key: 64,
          velocity: 127,
          length: 256,
          offset: 123,
          pan: 0,
        ),
      );

      project.execute(command);

      final state =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      final trackMap = state['tracks'] as Map<String, dynamic>;
      final syncedInstrumentTrack =
          trackMap[instrumentTrackId.toString()] as Map<String, dynamic>;
      final syncedDevices = syncedInstrumentTrack['devices'] as List<dynamic>;
      expect(
        syncedDevices,
        hasLength(1),
        reason: 'The track should reference the device.',
      );
      expect(
        (syncedDevices.single as Map<String, dynamic>)['nodeIds'],
        contains(instrumentNodeId),
        reason: 'The device should own the tone generator node.',
      );

      final pattern =
          state['sequence']!['patterns'][project.sequence.patterns.keys.first
                  .toString()]
              as Map<String, dynamic>;
      final notes = pattern['notes'] as Map<String, dynamic>;
      expect(
        notes.length,
        equals(1),
        reason: 'The pattern should contain 1 note.',
      );

      final note = notes.values.single as Map<String, dynamic>;
      expect(
        note['key'],
        equals(64),
        reason: 'The note should have the correct key.',
      );
      expect(
        note['velocity'],
        equals(127),
        reason: 'The note should have the correct velocity.',
      );
      expect(
        note['length'],
        equals(256),
        reason: 'The note should have the correct length.',
      );
      expect(
        note['offset'],
        equals(123),
        reason: 'The note should have the correct offset.',
      );
      expect(
        note['pan'],
        equals(0),
        reason: 'The note should have the correct pan.',
      );
    });

    test('Change all the note properties', () async {
      final patternId = project.sequence.patterns.keys.first;
      final note = project
          .sequence
          .patterns[project.sequence.patterns.keys.first]!
          .notes
          .values
          .first;

      project.execute(
        SetNoteAttributeCommand(
          patternID: patternId,
          noteID: note.id,
          attribute: NoteAttribute.key,
          oldValue: note.key,
          newValue: 65,
        ),
      );

      project.execute(
        SetNoteAttributeCommand(
          patternID: patternId,
          noteID: note.id,
          attribute: NoteAttribute.velocity,
          oldValue: note.velocity,
          newValue: 126,
        ),
      );

      final state =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      final pattern =
          state['sequence']!['patterns'][patternId.toString()]
              as Map<String, dynamic>;
      final notes = pattern['notes'] as Map<String, dynamic>;
      expect(
        notes.length,
        equals(1),
        reason: 'The pattern should contain 1 note.',
      );

      final updatedNote = notes.values.single as Map<String, dynamic>;
      expect(
        updatedNote['key'],
        equals(65),
        reason: 'The note should have the correct key.',
      );
      expect(
        updatedNote['velocity'],
        equals(126),
        reason: 'The note should have the correct velocity.',
      );
    });
  }, skip: skipEngineIntegrationTests);
}
