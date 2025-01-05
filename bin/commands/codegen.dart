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

import '../util/misc.dart';

class CodegenCommand extends Command<dynamic> {
  @override
  String get name => 'codegen';

  @override
  String get description => 'Commands for running code generation.';

  CodegenCommand() {
    addSubcommand(_CodegenCleanCommand());
  }
}

class _CodegenCleanCommand extends Command<dynamic> {
  @override
  String get name => 'clean';

  @override
  String get description => 'Cleans up generated files.';

  _CodegenCleanCommand() {
    argParser.addFlag('skip-prompts', abbr: 'y', defaultsTo: false);
  }

  @override
  Future<void> run() async {
    if (!argResults!['skip-prompts']) {
      print(
          'This will delete ALL files/folders matching the following patterns:');
      print('  - lib/**/*.g.dart');
      print('  - lib/**/*.g.part');
      print('  - engine/src/generated');
      print('Are you sure you want to delete all generated files? (y/n)');

      final response = stdin.readLineSync();

      if (response?.toLowerCase() != 'y') {
        print('Aborting.');
        return;
      }
    }

    print('Cleaning up generated files...');

    var deleteCount = 0;

    final dartFilesToDelete =
        Directory.fromUri(getPackageRootPath().resolve('lib'))
            .listSync(recursive: true)
            .where((f) {
      return f.path.endsWith('.g.dart') || f.path.endsWith('.g.part');
    });

    for (final file in dartFilesToDelete) {
      file.deleteSync();
      deleteCount++;
    }

    try {
      final engineGeneratedFolder = Directory.fromUri(
        getPackageRootPath().resolve('engine/src/generated'),
      );

      deleteCount += engineGeneratedFolder.listSync(recursive: true).length;

      engineGeneratedFolder.deleteSync(recursive: true);
    } on PathNotFoundException catch (_) {}

    print('Deleted $deleteCount files.');
  }
}
