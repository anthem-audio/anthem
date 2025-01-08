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

class CodegenCommand extends Command<dynamic> {
  @override
  String get name => 'codegen';

  @override
  String get description => 'Commands for running code generation.';

  CodegenCommand() {
    addSubcommand(_CodegenCleanCommand());
    addSubcommand(_CodegenGenerateCommand());
  }
}

class _CodegenCleanCommand extends Command<dynamic> {
  @override
  String get name => 'clean';

  @override
  String get description => 'Cleans up generated files.';

  _CodegenCleanCommand() {
    argParser.addFlag('skip-prompts',
        abbr: 'y', help: 'Skip confirmation prompts.');
  }

  @override
  Future<void> run() async {
    if (!argResults!['skip-prompts']) {
      print(
          'This will delete ALL files/folders matching the following patterns:');
      print('  - lib/**/*.g.dart');
      print('  - lib/**/*.g.part');
      print('  - codegen/**/*.g.dart');
      print('  - codegen/**/*.g.part');
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

    final dartLibFilesToDelete =
        Directory.fromUri(getPackageRootPath().resolve('lib/'))
            .listSync(recursive: true)
            .where((f) {
      return f.path.endsWith('.g.dart') || f.path.endsWith('.g.part');
    });

    for (final file in dartLibFilesToDelete) {
      file.deleteSync();
      deleteCount++;
    }

    final dartCodegenFilesToDelete =
        Directory.fromUri(getPackageRootPath().resolve('codegen/'))
            .listSync(recursive: true)
            .where((f) {
      return f.path.endsWith('.g.dart') || f.path.endsWith('.g.part');
    });

    for (final file in dartCodegenFilesToDelete) {
      file.deleteSync();
      deleteCount++;
    }

    try {
      final engineGeneratedFolder = Directory.fromUri(
        getPackageRootPath().resolve('engine/src/generated/'),
      );

      deleteCount += engineGeneratedFolder.listSync(recursive: true).length;

      engineGeneratedFolder.deleteSync(recursive: true);
    } on PathNotFoundException catch (_) {}

    print('Deleted $deleteCount files.');
  }
}

class _CodegenGenerateCommand extends Command<dynamic> {
  @override
  String get name => 'generate';

  @override
  String get description => 'Generates code for Anthem.';

  _CodegenGenerateCommand() {
    argParser.addFlag('watch',
        abbr: 'w',
        help:
            'Starts build_runner in watch mode, which will regenerate code as files change.');
    argParser.addFlag('root-only',
        help: 'Only generate code in the root package.');
  }

  @override
  Future<void> run() async {
    print(Colorize('Generating code...\n\n').lightGreen());

    final packageRootPath = getPackageRootPath();

    // If we're watching, run the build_runner in watch mode, and just run in
    // root package.
    if (argResults!['watch']) {
      print('Watching for changes in root package...');

      final process = await Process.start(
        'dart',
        [
          'run',
          'build_runner',
          'watch',
          '--delete-conflicting-outputs',
        ],
        workingDirectory:
            packageRootPath.toFilePath(windows: Platform.isWindows),
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print(Colorize('\n\nError: Code generation failed.').red());
      }

      return;
    }

    for (final subpath in [null, if (!argResults!['root-only']) 'codegen/']) {
      final workingDirectory =
          subpath == null ? packageRootPath : packageRootPath.resolve(subpath);

      print(Colorize(
              'Generating code in ${workingDirectory.toFilePath(windows: Platform.isWindows)}...')
          .lightGreen());

      final process = await Process.start(
        'dart',
        [
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ],
        workingDirectory:
            workingDirectory.toFilePath(windows: Platform.isWindows),
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print(Colorize('\n\nError: Code generation failed.').red());
        exit(exitCode);
      }
    }

    print(Colorize('\n\nCode generation complete.').lightGreen());
  }
}
