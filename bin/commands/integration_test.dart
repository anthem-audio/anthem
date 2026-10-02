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

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_helpers.dart';

/// Desktop app/engine scenarios, independent from the fast Flutter test suite.
class IntegrationTestCommand extends Command<void> {
  @override
  String get name => 'integration-test';
  @override
  String get description =>
      'Run desktop application integration scenarios with a real engine.';

  IntegrationTestCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Desktop device (linux or macos); defaults to the host.',
      )
      ..addOption(
        'engine',
        help:
            'Explicit existing engine executable. Otherwise build the debug engine.',
      )
      ..addOption(
        'target',
        defaultsTo: 'integration_test/startup_test.dart',
        help: 'Integration test file to run.',
      )
      ..addOption(
        'output',
        help:
            'Artifact directory. Defaults to a new build/integration_test run directory.',
      )
      ..addOption(
        'seed',
        help:
            'Shuffle test ordering with this integer seed to check isolation.',
      );
  }

  @override
  Future<void> run() async {
    final seed = argResults!['seed'] as String?;
    if (seed != null && (int.tryParse(seed) == null || int.parse(seed) < 0)) {
      throw UsageException('--seed must be a nonnegative integer.', usage);
    }
    final device = argResults!['device'] as String? ?? Platform.operatingSystem;
    if (!['linux', 'macos'].contains(device) ||
        device != Platform.operatingSystem) {
      throw UsageException(
        'This suite requires a linux or macos desktop device on the current host.',
        usage,
      );
    }
    final root = Directory.fromUri(getPackageRootPath()).absolute;
    final target = File.fromUri(
      root.uri.resolve(argResults!['target'] as String),
    );
    if (!target.existsSync()) {
      throw UsageException('Test target does not exist: ${target.path}', usage);
    }
    final flutter = findExecutable('flutter');
    if (flutter == null) {
      throw UsageException('Flutter must be on PATH.', usage);
    }

    final runId =
        '${DateTime.now().toUtc().toIso8601String().replaceAll(":", "-")}-$pid';
    final outputArgument = argResults!['output'] as String?;
    final output = Directory(
      outputArgument ?? '${root.path}/build/integration_test/$runId',
    ).absolute;
    await output.create(recursive: true);
    final lockFile = File('${root.path}/build/integration_test/runner.lock');
    await lockFile.parent.create(recursive: true);
    final lock = await lockFile.open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
    } on FileSystemException {
      await lock.close();
      throw UsageException(
        'Another integration runner owns this checkout. Wait for it to finish; '
        'Flutter desktop targets share build output.',
        usage,
      );
    }
    final transcript = File('${output.path}/runner.log').openWrite();
    print('Integration test artifacts: ${output.path}');
    try {
      final configured = argResults!['engine'] as String?;
      if (configured == null) {
        if (!File('${root.path}/lib/model/project.g.dart').existsSync()) {
          throw UsageException(
            'Run dart run anthem:cli codegen generate before building the engine.',
            usage,
          );
        }
        if (await _run(
              Platform.resolvedExecutable,
              ['run', 'anthem:cli', 'engine', 'build', '--debug'],
              root,
              transcript,
            ) !=
            0) {
          exitCode = 1;
          return;
        }
      }
      // Deliberately never select the copy in assets/engine: it can be stale.
      final engine = File(
        configured ??
            '${root.path}/engine/build/AnthemEngine_artefacts/Debug/AnthemEngine',
      ).absolute;
      if (!engine.existsSync()) {
        throw UsageException(
          'Engine executable does not exist: ${engine.path}',
          usage,
        );
      }
      final version = await Process.run(flutter, [
        '--version',
      ], workingDirectory: root.path);
      await File('${output.path}/run.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'device': device,
          'target': target.path,
          'engine': engine.path,
          'audio': false,
          'orderingSeed': seed,
          'flutterVersion': version.stdout.toString(),
          'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      exitCode = await _run(
        flutter,
        [
          'test',
          target.path,
          '-d',
          device,
          '--reporter',
          'expanded',
          '--dart-define=ANTHEM_TEST_ENGINE=${engine.path}',
          '--dart-define=ANTHEM_TEST_ARTIFACTS=${output.path}',
          if (seed != null) '--test-randomize-ordering-seed=$seed',
        ],
        root,
        transcript,
      );
    } finally {
      try {
        await transcript.flush();
        await transcript.close();
      } finally {
        await lock.unlock();
        await lock.close();
      }
    }
  }

  Future<int> _run(
    String executable,
    List<String> arguments,
    Directory root,
    IOSink transcript,
  ) async {
    transcript.writeln('Running $executable ${arguments.join(" ")}');
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: root.path,
    );
    final output = process.stdout.listen((data) {
      stdout.add(data);
      transcript.add(data);
    }).asFuture<void>();
    final errors = process.stderr.listen((data) {
      stderr.add(data);
      transcript.add(data);
    }).asFuture<void>();
    final result = await process.exitCode;
    await Future.wait([output, errors]);
    transcript.writeln('Exit code: $result');
    return result;
  }
}
