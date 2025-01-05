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

import 'package:args/command_runner.dart';

import 'commands/build.dart';

/// Main entry point for the CLI command.
/// 
/// Usage:
/// 
/// ```sh
/// dart run anthem:cli command [arguments]
/// ```
void main(List<String> args) {
  final runner = CommandRunner<dynamic>('anthem:cli', 'Utilities for developing Anthem.')
    ..addCommand(BuildCommand());

  runner.run(args);
}
