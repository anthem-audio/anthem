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

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anthem/commands/pattern_commands.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/model/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/model/project.dart';

var id = 0;
int getId() => id++;

void main() {
  var path = Platform.script;
  while (path.pathSegments.length > 1 &&
      File(path.resolve('pubspec.yaml').toFilePath()).existsSync() == false) {
    path = path.resolve('../');
  }

  final enginePath = path.resolve(
      'engine/build/AnthemEngine_artefacts/Release/AnthemEngine${Platform.isWindows ? '.exe' : ''}');

  test('Engine exists', () {
    // Note: If this fails, the engine has not been built. This uses release
    // mode, since it means we won't have to build the engine twice in CI. If
    // you're running this locally, you may want to build the engine in debug
    // mode instead, and change the path above to point to debug instead of
    // release.
    expect(
        File(enginePath.toFilePath(windows: Platform.isWindows)).existsSync(),
        true);
  });

  group('Heartbeat tests', () {
    test('No heartbeat', () async {
      final exitStreamController = StreamController<void>.broadcast();

      var exitCalled = false;
      exitStreamController.stream.first.then((_) => exitCalled = true);

      var heartbeatWaitCompleter = Completer<void>();

      final _ = EngineConnector(
        0,
        enginePathOverride: enginePath.toFilePath(windows: Platform.isWindows),
        kDebugMode: true,
        noHeartbeat: true,
        onExit: () => exitStreamController.add(null),
      );

      expect(exitCalled, isFalse,
          reason: 'The engine should not crash when it first starts.');

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

      expect(exitCalled, isTrue,
          reason: 'The engine should exit if it does not receive a heartbeat.');
    });

    test('Heartbeat', () async {
      final exitStreamController = StreamController<void>.broadcast();

      var exitCalled = false;
      exitStreamController.stream.first.then((_) => exitCalled = true);

      var heartbeatWaitCompleter = Completer<void>();

      final engineConnector = EngineConnector(
        0,
        enginePathOverride: enginePath.toFilePath(windows: Platform.isWindows),
        kDebugMode: true,
        onExit: () => exitStreamController.add(null),
      );

      exitCalled = false;

      exitStreamController.stream.first.then((_) => exitCalled = true);

      expect(exitCalled, isFalse,
          reason: 'The engine should not crash when it first starts.');

      heartbeatWaitCompleter = Completer<void>();

      Timer(Duration(seconds: 15), () {
        heartbeatWaitCompleter.complete();
      });

      await heartbeatWaitCompleter.future;

      expect(exitCalled, isFalse,
          reason: 'The engine should not exit if it receives a heartbeat.');

      engineConnector.dispose();
      // Wait 5s for the engine to exit
      await Future<void>.delayed(Duration(seconds: 5));
      expect(exitCalled, isTrue,
          reason: 'The engine should exit when disposed.');
    });
  });

  group('Model sync tests', () {
    late ProjectModel project;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      project = ProjectModel.create(
          enginePath.toFilePath(windows: Platform.isWindows));
      await project.engine.start();
      while (project.engine.engineState != EngineState.running) {
        await project.engine.engineStateStream.first;
      }
    });

    test('Test initial state', () async {
      final engine = project.engine;

      engine.modelSyncApi.initModel(jsonEncode(project.toJson()));

      final initialState =
          jsonDecode(await engine.modelSyncApi.debugGetEngineJson())
              as Map<String, dynamic>;

      expect(initialState['song'], isNotNull,
          reason: 'The initial state should contain a song.');
      expect(initialState['processingGraph'], isNotNull,
          reason: 'The initial state should contain a processing graph.');
      expect(initialState['isSaved'], isNotNull,
          reason:
              'The initial state should contain isSaved - this is not in the project file.');
    });

    test('Add a bunch of patterns', () async {
      final engine = project.engine;

      final patternCount = 100;

      for (var i = 0; i < patternCount; i++) {
        final command = AddPatternCommand(
            pattern: PatternModel.create(name: 'Pattern $i'), index: i);
        project.execute(command);
      }

      final state = jsonDecode(await engine.modelSyncApi.debugGetEngineJson())
          as Map<String, dynamic>;

      final patternMap = state['song']!['patterns'] as Map<String, dynamic>;
      final patternIdList =
          (state['song']!['patternOrder'] as List<dynamic>).cast<String>();

      expect(patternMap.length, equals(patternCount),
          reason: 'The pattern map should contain $patternCount patterns.');
      expect(patternIdList.length, equals(patternCount),
          reason: 'The pattern order should contain $patternCount patterns.');

      for (var i = 0; i < patternCount; i++) {
        final id = patternIdList[i];
        final pattern = patternMap[id] as Map<String, dynamic>;
        expect(pattern['name'], equals('Pattern $i'),
            reason: 'Pattern $i should have the correct name.');
      }
    });
  });
}
