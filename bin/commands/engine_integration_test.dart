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
// import 'dart:convert';
import 'dart:io';
// import 'dart:typed_data';

import 'package:anthem/engine_api/engine_connector.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';

import 'engine_integration_test_options.dart';

class _EngineIntegrationTestCommand extends Command<dynamic> {
  @override
  String get name => 'integration-test';

  @override
  String get description => 'Runs the engine integration tests.';

  _EngineIntegrationTestCommand() {
    addIntegrationTestOptions(argParser);
  }

  @override
  Future<void> run() async {
    if (argResults!['debug'] && argResults!['release']) {
      print(Colorize(
              'Cannot run the engine in both debug and release mode at the same time. Use --debug --no-release or --release --no-debug.')
          .lightRed());
      exit(1);
    }

    if (!argResults!['debug'] && !argResults!['release']) {
      print(Colorize(
              'Must run the engine in either debug or release mode. Use the --debug --no-release or --release --no-debug.')
          .lightRed());
      exit(1);
    }

    try {
      await _runIntegrationTests();
    } on Exception catch (e) {
      print(Colorize(e.toString()).lightRed());
      exit(1);
    }

    // For some reason, the program seems to just not quit unless we do this
    // (tested on Windows).
    exit(0);
  }

  Future<void> _runIntegrationTests() async {
    print(Colorize('Running engine integration tests...').lightGreen());

    // Note that Platform.script works here becuase this is being run in a
    // separate process via `dart run direct/path/to/script`.
    final enginePathFallback = Platform.script.resolve(
        '../../engine/build/AnthemEngine_artefacts${argResults!['debug'] ? '/Debug' : '/Release'}/AnthemEngine${Platform.isWindows ? '.exe' : ''}');

    final enginePath = (argResults!['engine-path'] as String?) ??
        enginePathFallback.toFilePath(windows: Platform.isWindows);

    print(enginePath);

    final engineExecutable = File(enginePath);

    if (!engineExecutable.existsSync()) {
      if (argResults!['engine-path'] == null) {
        final mode = argResults!['debug'] ? 'debug' : 'release';

        print(Colorize('''Engine executable not found at
    $enginePath

The engine must be built in $mode mode before running the integration tests with
$mode mode. This can be done by running the following command:
    dart run anthem:cli engine build --$mode

ALternatively, you can specify the path to the engine executable using the
--engine-path flag.
''').lightRed());
      } else {
        print(Colorize('''No file found at specified engine path:
    $enginePath
''').lightRed());
      }
      exit(1);
    }

    final replyStreamController = StreamController<Response>.broadcast();
    final exitStreamController = StreamController<void>.broadcast();

    _testHeader('No heartbeat');

    var engineConnector = EngineConnector(
      0,
      enginePathOverride: enginePath,
      kDebugMode: true,
      noHeartbeat: true,
      onReply: (r) => replyStreamController.add(r),
      onExit: () => exitStreamController.add(null),
    );

    var exitCalled = false;
    exitStreamController.stream.first.then((_) => exitCalled = true);

    _expect(!exitCalled, 'The engine should not crash when it first starts.');

    var heartbeatWaitCompleter = Completer<void>();

    print('Waiting 15 seconds for engine heartbeat check to fail...');

    Timer(Duration(seconds: 15), () {
      heartbeatWaitCompleter.complete();
    });

    await heartbeatWaitCompleter.future;

    _expect(exitCalled,
        'The engine should exit if it does not receive a heartbeat.');

    _testHeader('Heartbeat');

    engineConnector = EngineConnector(
      0,
      enginePathOverride: enginePath,
      kDebugMode: true,
      onReply: (r) => replyStreamController.add(r),
      onExit: () => exitStreamController.add(null),
    );

    exitCalled = false;

    exitStreamController.stream.first.then((_) => exitCalled = true);

    _expect(!exitCalled, 'The engine should not crash when it first starts.');

    heartbeatWaitCompleter = Completer<void>();

    print('Waiting 15 seconds for engine heartbeat check to pass...');
    Timer(Duration(seconds: 15), () {
      heartbeatWaitCompleter.complete();
    });

    await heartbeatWaitCompleter.future;

    _expect(
        !exitCalled, 'The engine should not exit if it receives a heartbeat.');

    engineConnector.dispose();
    // Wait 5s for the engine to exit
    await Future<void>.delayed(Duration(seconds: 5));
    _expect(exitCalled, 'The engine should exit when disposed.');

    // void sendRequest(Request request) {
    //   final encoder = JsonUtf8Encoder();
    //   final requestBytes = encoder.convert(request.toJson()) as Uint8List;

    //   engineConnector.send(requestBytes);
    // }
  }
}

class _TestFailure implements Exception {
  final String message;

  _TestFailure(this.message);

  @override
  String toString() => message;
}

void _expect(bool condition, [String? message]) {
  if (!condition) {
    throw _TestFailure(
        'Test failed${message != null ? ' at:\n    $message' : '.'}\n\nStack trace:\n${StackTrace.current}');
  } else {
    print('$message - PASS');
  }
}

void _testHeader(String header) {
  print(Colorize('\n$header').lightCyan());
}

void main(List<String> args) async {
  final runner = CommandRunner<dynamic>(
      'integration-test', 'Runs the engine integration tests.')
    ..addCommand(_EngineIntegrationTestCommand());

  try {
    // This is a hack - see the doc comment in engine_integration_test_options.dart
    // for the best explanation of what's going on.
    //
    // This will pass the incoming arguments directly to the integration-test
    // command above.
    await runner.run(['integration-test', ...args]);
  } on UsageException catch (e) {
    print(e);
  }
}
