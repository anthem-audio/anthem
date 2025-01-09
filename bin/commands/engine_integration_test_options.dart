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

import 'dart:io';

import 'package:args/args.dart';

/// Adds the options for the engine integration test command to the given
/// [ArgParser].
///
/// This is a bit of a hack, but it prevents duplicating documentation for the
/// engine integration tests.
///
/// All the commands for the anthem:cli script are compiled into a single Dart
/// program when the cli script is run. This used to be the case for the
/// integration tests as well, but this caused issues in CI because:
///  - The integration tests include parts of the model
///  - The model has compile errors until code generation happens
///  - Code generation is done through the anthem:cli command
///
/// This meant that the anthem:cli command couldn't compile when running
/// ```
/// dart run anthem:cli codegen generate
/// ```
/// due to code generation not having been run.
///
/// To fix this, the engine integration tests are compiled as a separate
/// program, and run via `Process.start()` when the integration test subcommand
/// is invoked. However, there is no way with `package:args` to have custom
/// handling for the help command. We need to provide the args to both the
/// actual subcommand (for real parsing) as well as the "shell" command that
/// starts the process (for the help screen), so we define them here, to be
/// imported by both.
void addIntegrationTestOptions(ArgParser argParser) {
  argParser.addOption('engine-path',
      abbr: 'e',
      help: 'Path to the engine executable.',
      valueHelp: 'path/to/engine');

  // On Windows in debug mode, certain crashes give us a dialog box that
  // prevents the engine from exiting. I want these dialogs to remain in
  // normal debug builds, but they can't happen in the integration tests.
  //
  // We could make a special build configuration for the integration tests,
  // but since we still test in debug mode on other platforms, there isn't
  // much benefit for the extra complexity.
  //
  // Instead, we just run the engine in release mode on Windows, and debug
  // mode elsewhere.

  argParser.addFlag('debug',
      abbr: 'd',
      help:
          'Run the debug build of the engine, if no path is supplied. Defaults to false on Windows, and true elsewhere.',
      defaultsTo: !Platform.isWindows);
  argParser.addFlag('release',
      abbr: 'r',
      help:
          'Run the engine in release mode. Defaults to true on Windows, and false elsewhere.',
      defaultsTo: Platform.isWindows);
}
