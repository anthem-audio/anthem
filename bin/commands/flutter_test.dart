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

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';

import '../util/misc.dart';

class FlutterTestCommand extends Command<dynamic> {
  @override
  String get name => 'flutter_test';

  @override
  String get description =>
      'Runs Flutter tests in the root package and analyzer plugin tests in the plugin package.';

  @override
  Future<void> run() async {
    final packageRootPath = getPackageRootPath();

    print(Colorize('Running Flutter tests...').lightGreen());
    await _runCommand(
      executable: 'flutter',
      arguments: ['test', 'test', 'codegen/test'],
      workingDirectory: packageRootPath,
      failureMessage: 'Flutter tests failed.',
    );

    final analyzerPluginPath = packageRootPath.resolve(
      'tools/anthem_analyzer_plugin/',
    );

    print(Colorize('\nRunning analyzer plugin tests...').lightGreen());
    await _runCommand(
      executable: 'dart',
      arguments: ['test'],
      workingDirectory: analyzerPluginPath,
      failureMessage: 'Analyzer plugin tests failed.',
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
