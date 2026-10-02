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

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';

import '../cli_helpers.dart';
import 'flutter_test_web.dart';

class FlutterTestCommand extends Command<dynamic> {
  FlutterTestCommand() {
    argParser
      ..addFlag(
        'web',
        negatable: false,
        help: 'Run browser tests in Chrome instead of the VM/host suites.',
      )
      ..addOption(
        'compiler',
        allowed: ['dart2js', 'dart2wasm', 'both'],
        defaultsTo: 'both',
        help: 'With --web: compilers for standalone Dart tests.',
      )
      ..addFlag(
        'widgets',
        negatable: false,
        help: 'With --web: also run Flutter unit/widget tests (Linux/macOS).',
      )
      ..addOption(
        'reporter',
        allowed: ['expanded', 'compact', 'github'],
        help: 'Console test reporter (browser default: expanded).',
      )
      ..addFlag(
        'list',
        negatable: false,
        help: 'With --web: list selected test files without running them.',
      );
  }

  @override
  String get name => 'flutter_test';

  @override
  String get description => 'Runs VM/host tests, or browser tests with --web.';

  @override
  Future<void> run() async {
    if (argResults!.rest.isNotEmpty) {
      usageException('This command does not accept positional arguments.');
    }
    final packageRootPath = getPackageRootPath();

    if (argResults!['web'] as bool) {
      await runFlutterWebTests(
        packageRootPath: packageRootPath,
        compiler: argResults!['compiler'] as String,
        widgets: argResults!['widgets'] as bool,
        reporter: argResults!['reporter'] as String? ?? 'expanded',
        list: argResults!['list'] as bool,
        usageException: usageException,
      );
      return;
    }
    for (final option in ['compiler', 'widgets', 'list']) {
      if (argResults!.wasParsed(option)) {
        usageException('--$option requires --web.');
      }
    }
    final reporterArguments = argResults!.wasParsed('reporter')
        ? ['--reporter', argResults!['reporter'] as String]
        : <String>[];

    print(Colorize('Running Flutter tests...').lightGreen());
    await _runCommand(
      executable: 'flutter',
      arguments: ['test', ...reporterArguments, 'test', 'codegen/test'],
      workingDirectory: packageRootPath,
      failureMessage: 'Flutter tests failed.',
    );

    final analyzerPluginPath = packageRootPath.resolve(
      'tools/anthem_analyzer_plugin/',
    );

    print(Colorize('\nRunning analyzer plugin tests...').lightGreen());
    await _runCommand(
      executable: 'dart',
      arguments: ['test', ...reporterArguments],
      workingDirectory: analyzerPluginPath,
      failureMessage: 'Analyzer plugin tests failed.',
    );

    final nativeIpcPath = packageRootPath.resolve('native/anthem_native_ipc/');

    print(Colorize('\nRunning native IPC package tests...').lightGreen());
    await _runCommand(
      executable: 'dart',
      arguments: ['test', ...reporterArguments],
      workingDirectory: nativeIpcPath,
      failureMessage: 'Native IPC package tests failed.',
    );

    print(Colorize('\n\nFlutter testing complete.').lightGreen());
  }
}

Future<void> _runCommand({
  required String executable,
  required List<String> arguments,
  required Uri workingDirectory,
  required String failureMessage,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory.toFilePath(windows: Platform.isWindows),
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );

  final commandExitCode = await process.exitCode;
  if (commandExitCode != 0) {
    print(Colorize('\n\nError: $failureMessage').red());
    exit(commandExitCode);
  }
}
