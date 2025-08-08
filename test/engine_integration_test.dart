/*
  Copyright (C) 2025 Joshua Wade

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
import 'dart:ui';

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/commands/pattern_note_commands.dart';
import 'package:anthem/commands/project_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anthem/engine_api/engine_connector.dart';

var id = 0;
int getId() => id++;

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
  });

  group('Model sync tests', () {
    late ProjectModel project;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      project = ProjectModel.create(
        enginePath!.toFilePath(windows: Platform.isWindows),
      );
      await project.engine.start();
      while (project.engine.engineState != EngineState.running) {
        await project.engine.engineStateStream.first;
      }
    });

    tearDownAll(() async {
      await project.engine.stop();
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
        initialState['isSaved'],
        isNotNull,
        reason:
            'The initial state should contain isSaved - this is not in the project file.',
      );
    });

    test('Add a bunch of patterns', () async {
      final patternCount = 100;

      for (var i = 0; i < patternCount; i++) {
        final command = AddPatternCommand(
          pattern: PatternModel.create(name: 'Pattern $i'),
          index: i,
        );
        project.execute(command);
      }

      final state =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      final patternMap = state['sequence']!['patterns'] as Map<String, dynamic>;
      final patternIdList =
          (state['sequence']!['patternOrder'] as List<dynamic>).cast<String>();

      expect(
        patternMap.length,
        equals(patternCount),
        reason: 'The pattern map should contain $patternCount patterns.',
      );
      expect(
        patternIdList.length,
        equals(patternCount),
        reason: 'The pattern order should contain $patternCount patterns.',
      );

      for (var i = 0; i < patternCount; i++) {
        final id = patternIdList[i];
        final pattern = patternMap[id] as Map<String, dynamic>;
        expect(
          pattern['name'],
          equals('Pattern $i'),
          reason: 'Pattern $i should have the correct name.',
        );
      }
    });

    test('Delete every even pattern', () async {
      final originalPatternListSize = project.sequence.patternOrder.length;

      for (var i = originalPatternListSize - 1; i >= 0; i--) {
        if (i.isEven) {
          final command = DeletePatternCommand(
            pattern:
                project.sequence.patterns[project.sequence.patternOrder[i]]!,
            index: i,
          );
          project.execute(command);
        }
      }

      final state =
          jsonDecode(await project.engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      final patternMap = state['sequence']!['patterns'] as Map<String, dynamic>;
      final patternIdList =
          (state['sequence']!['patternOrder'] as List<dynamic>).cast<String>();

      expect(
        patternMap.length,
        equals(originalPatternListSize ~/ 2),
        reason:
            'The pattern map should contain ${originalPatternListSize ~/ 2} patterns.',
      );

      for (var i = 0; i < patternIdList.length; i++) {
        final id = patternIdList[i];
        final pattern = patternMap[id] as Map<String, dynamic>;
        expect(
          pattern['name'],
          equals('Pattern ${i * 2 + 1}'),
          reason: 'Pattern ${i * 2 + 1} should have the correct name.',
        );
      }
    });

    test('Add a generator and some notes', () async {
      project.execute(
        AddGeneratorCommand(
          generatorId: 'generator1',
          node: NodeModel.uninitialized(),
          name: 'Genrator name',
          generatorType: GeneratorType.instrument,
          color: const Color(0xFF000000),
        ),
      );

      final generator = project.generators['generator1']!;

      final command = AddNoteCommand(
        generatorID: generator.id,
        patternID: project.sequence.patternOrder[0],
        note: NoteModel(
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

      final generatorMap = state['generators'] as Map<String, dynamic>;
      expect(
        generatorMap['generator1'],
        isNotNull,
        reason: 'The generator should be in the state.',
      );

      final pattern =
          state['sequence']!['patterns'][project.sequence.patternOrder[0]]
              as Map<String, dynamic>;
      final notes = pattern['notes']!['generator1'] as List<dynamic>;
      expect(
        notes.length,
        equals(1),
        reason: 'The pattern should contain 1 note.',
      );

      final note = notes[0] as Map<String, dynamic>;
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
      final patternId = project.sequence.patternOrder[0];
      final note = project
          .sequence
          .patterns[project.sequence.patternOrder[0]]!
          .notes['generator1']![0];

      project.execute(
        SetNoteAttributeCommand(
          patternID: patternId,
          generatorID: 'generator1',
          noteID: note.id,
          attribute: NoteAttribute.key,
          oldValue: note.key,
          newValue: 65,
        ),
      );

      project.execute(
        SetNoteAttributeCommand(
          patternID: patternId,
          generatorID: 'generator1',
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
          state['sequence']!['patterns'][patternId] as Map<String, dynamic>;
      final notes = pattern['notes']!['generator1'] as List<dynamic>;
      expect(
        notes.length,
        equals(1),
        reason: 'The pattern should contain 1 note.',
      );

      final updatedNote = notes[0] as Map<String, dynamic>;
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
  });
}
