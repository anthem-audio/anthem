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
import '../integration_test/verify_failure_artifacts.dart';
import '../integration_test/test_plugin_manifest.dart';

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
        help:
            'Desktop device (linux, macos, or windows); defaults to the host.',
      )
      ..addOption(
        'engine',
        help: 'Explicit existing engine executable. Otherwise build the debug engine.',
      )
      ..addOption(
        'test-plugin-manifest',
        help: 'Existing test-plugins.json from engine build-test-plugins. Otherwise build debug fixtures when needed.',
      )
      ..addOption(
        'target',
        defaultsTo: 'integration_test',
        help: 'Integration test file or directory to run.',
      )
      ..addOption(
        'output',
        help: 'Artifact directory. Defaults to a new build/integration_test run directory.',
      )
      ..addOption(
        'seed',
        help:
            'Shuffle test ordering with this integer seed to check isolation.',
      )
      ..addFlag(
        'test-failure-handling',
        negatable: false,
        help: 'Run deliberately failing scenarios to check diagnostic capture and engine cleanup.',
      );
  }

  @override
  Future<void> run() async {
    final seed = argResults!['seed'] as String?;
    if (seed != null && (int.tryParse(seed) == null || int.parse(seed) < 0)) {
      throw UsageException('--seed must be a nonnegative integer.', usage);
    }
    final device = argResults!['device'] as String? ?? Platform.operatingSystem;
    if (!['linux', 'macos', 'windows'].contains(device) ||
        device != Platform.operatingSystem) {
      throw UsageException(
        'This suite requires a linux, macos, or windows desktop device on the current host.',
        usage,
      );
    }
    final root = Directory.fromUri(getPackageRootPath()).absolute;
    final testFailureHandling = argResults!['test-failure-handling'] as bool;
    if (testFailureHandling && argResults!['target'] != 'integration_test') {
      throw UsageException(
        '--test-failure-handling selects its own deliberately failing scenarios.',
        usage,
      );
    }
    final target = File.fromUri(
      root.uri.resolve(
        testFailureHandling
            ? 'integration_test/support/failure_artifacts_probe.dart'
            : argResults!['target'] as String,
      ),
    );
    if (!target.existsSync() && !Directory(target.path).existsSync()) {
      throw UsageException('Test target does not exist: ${target.path}', usage);
    }
    final testFiles =
        target.existsSync()
              ? [target]
              : Directory(target.path)
                    .listSync(recursive: true, followLinks: false)
                    .whereType<File>()
                    .where((file) => file.path.endsWith('_test.dart'))
                    .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (testFiles.isEmpty) {
      throw UsageException(
        'No *_test.dart files found in ${target.path}.',
        usage,
      );
    }
    final needsFixtures = testFiles.any(
      (file) => [
        'startup_test.dart',
        'plugin_test.dart',
      ].contains(file.uri.pathSegments.last),
    );
    final integrationRoot = Directory.fromUri(
      root.uri.resolve('integration_test'),
    );
    final integrationPrefix =
        '${integrationRoot.path}${Platform.pathSeparator}';
    if (testFiles.any((file) => !file.path.startsWith(integrationPrefix))) {
      throw UsageException(
        'Desktop integration targets must be inside ${integrationRoot.path}. '
        'Flutter runs files outside that directory as widget tests.',
        usage,
      );
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
            '${root.path}/engine/build/AnthemEngine_artefacts/Debug/AnthemEngine${Platform.isWindows ? '.exe' : ''}',
      ).absolute;
      if (!engine.existsSync()) {
        throw UsageException(
          'Engine executable does not exist: ${engine.path}',
          usage,
        );
      }
      File? pluginManifest;
      TestPluginManifest? fixtures;
      if (needsFixtures) {
        final suppliedManifest = argResults!['test-plugin-manifest'] as String?;
        if (suppliedManifest == null) {
          if (await _run(
                Platform.resolvedExecutable,
                [
                  'run',
                  'anthem:cli',
                  'engine',
                  'build-test-plugins',
                  '--debug',
                  '--jobs',
                  '2',
                ],
                root,
                transcript,
              ) !=
              0) {
            exitCode = 1;
            return;
          }
        }
        pluginManifest = File(
          suppliedManifest ??
              '${root.path}/engine/build_test_plugins/test-plugins.json',
        ).absolute;
        try {
          fixtures = TestPluginManifest.read(pluginManifest);
        } catch (error) {
          throw UsageException(
            'Cannot use test plugin fixtures: $error',
            usage,
          );
        }
      }
      final version = await Process.run(
        flutter,
        ['--version'],
        workingDirectory: root.path,
        runInShell: Platform.isWindows,
      );
      if (testFailureHandling) {
        await File('${output.path}/verification.json')
            .writeAsString(jsonEncode({'status': 'pending', 'runId': runId}));
      }
      await File('${output.path}/run.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'device': device,
          'runId': runId,
          'target': target.path,
          'testFiles': testFiles.map((file) => file.path).toList(),
          'engine': engine.path,
          'testPluginManifest': pluginManifest?.path,
          'testPlugins': fixtures?.toJson(),
          'audio': false,
          'orderingSeed': seed,
          'testFailureHandling': testFailureHandling,
          'flutterVersion': version.stdout.toString(),
          'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      // Flutter's desktop device closes its log stream when an app exits.
      // Give each file a fresh Flutter process and log reader. Run sequentially
      // because desktop builds share an output directory.
      exitCode = 0;
      for (final testFile in testFiles) {
        final result = await _run(
          flutter,
          [
            'test',
            testFile.path,
            '-d',
            device,
            '--reporter',
            'expanded',
            '--dart-define=ANTHEM_TEST_ENGINE=${engine.path}',
            '--dart-define=ANTHEM_TEST_ARTIFACTS=${output.path}',
            '--dart-define=ANTHEM_TEST_RUN_ID=$runId',
            if (pluginManifest != null)
              '--dart-define=ANTHEM_TEST_PLUGIN_MANIFEST=${pluginManifest.path}',
            if (seed != null) '--test-randomize-ordering-seed=$seed',
          ],
          root,
          transcript,
        );
        // Finish the remaining files, preserving the first failing exit code.
        if (exitCode == 0) exitCode = result;
      }
      if (testFailureHandling) {
        try {
          await verifyFailureArtifacts(
            output,
            testExitCode: exitCode,
            runId: runId,
            includeUnresponsiveEngine: !Platform.isWindows,
          );
          print(
            'Intentional failures, screenshots, snapshots, and engine cleanup verified.',
          );
          exitCode = 0;
        } catch (error) {
          print('Failure handling verification failed: $error');
          exitCode = 1;
        }
      }
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
      runInShell:
          Platform.isWindows &&
          (executable.endsWith('.bat') || executable.endsWith('.cmd')),
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
