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
import 'package:crypto/crypto.dart';

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
    argParser.addFlag(
      'skip-prompts',
      abbr: 'y',
      help: 'Skip confirmation prompts.',
    );
    argParser.addFlag(
      'root-only',
      help: 'Only clean up generated files in the root package.',
    );
  }

  @override
  Future<void> run() async {
    if (!argResults!['skip-prompts']) {
      print(
        'This will delete ALL files/folders matching the following patterns:',
      );
      print('  - lib/**/*.g.dart');
      print('  - lib/**/*.g.part');
      if (!argResults!['root-only']) {
        print('  - codegen/**/*.g.dart');
        print('  - codegen/**/*.g.part');
      }
      print('  - engine/src/generated');
      print('This will also run');
      print('    dart run build_runner clean');
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
        Directory.fromUri(
          getPackageRootPath().resolve('lib/'),
        ).listSync(recursive: true).where((f) {
          return f.path.endsWith('.g.dart') || f.path.endsWith('.g.part');
        });

    for (final file in dartLibFilesToDelete) {
      file.deleteSync();
      deleteCount++;
    }

    if (!argResults!['root-only']) {
      final dartCodegenFilesToDelete =
          Directory.fromUri(
            getPackageRootPath().resolve('codegen/'),
          ).listSync(recursive: true).where((f) {
            return f.path.endsWith('.g.dart') || f.path.endsWith('.g.part');
          });

      for (final file in dartCodegenFilesToDelete) {
        file.deleteSync();
        deleteCount++;
      }
    }

    try {
      final engineGeneratedFolder = Directory.fromUri(
        getPackageRootPath().resolve('engine/src/generated/'),
      );

      deleteCount += engineGeneratedFolder.listSync(recursive: true).length;

      engineGeneratedFolder.deleteSync(recursive: true);
    } on PathNotFoundException catch (_) {}

    print('Deleted $deleteCount files.');

    print('Running dart run build_runner clean...');
    final processInRoot = await Process.start(
      'dart',
      ['run', 'build_runner', 'clean'],
      workingDirectory: getPackageRootPath().toFilePath(
        windows: Platform.isWindows,
      ),
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await processInRoot.exitCode;

    if (exitCode != 0) {
      print(
        Colorize(
          '\n\nError: Code cleanup failed. Could not run build_runner clean in root package.',
        ).red(),
      );
      exit(exitCode);
    }

    if (!argResults!['root-only']) {
      final processInCodegen = await Process.start(
        'dart',
        ['run', 'build_runner', 'clean'],
        workingDirectory: getPackageRootPath()
            .resolve('codegen/')
            .toFilePath(windows: Platform.isWindows),
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await processInCodegen.exitCode;

      if (exitCode != 0) {
        print(
          Colorize(
            '\n\nError: Code cleanup failed. Could not run build_runner clean in codegen package.',
          ).red(),
        );
        exit(exitCode);
      }
    }

    print(Colorize('\n\nCode cleanup complete.').lightGreen());
  }
}

class _CodegenGenerateCommand extends Command<dynamic> {
  @override
  String get name => 'generate';

  @override
  String get description => 'Generates code for Anthem.';

  _CodegenGenerateCommand() {
    argParser.addFlag(
      'watch',
      abbr: 'w',
      help:
          'Starts build_runner in watch mode, which will regenerate code as files change.',
    );
    argParser.addFlag(
      'root-only',
      help: 'Only generate code in the root package.',
    );
    argParser.addFlag(
      'explicit-format-for-ci',
      help:
          'Explicitly formats generated code to work around code generation still applying the old-style formatter.',
    );
  }

  @override
  Future<void> run() async {
    final packageRootPath = getPackageRootPath();

    // If we're watching, run the build_runner in watch mode, and just run in
    // root package.
    if (argResults!['watch']) {
      print('Watching for changes in root package...');

      final process = await Process.start(
        'dart',
        ['run', 'build_runner', 'watch', '--delete-conflicting-outputs'],
        workingDirectory: packageRootPath.toFilePath(
          windows: Platform.isWindows,
        ),
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print(Colorize('\n\nError: Code generation failed.').red());
      }

      return;
    }

    for (final subpath in [null, if (!argResults!['root-only']) 'codegen/']) {
      final workingDirectory = subpath == null
          ? packageRootPath
          : packageRootPath.resolve(subpath);

      _DiffChecker? diffChecker;

      if (subpath == null) {
        diffChecker = _DiffChecker(
          Directory.fromUri(workingDirectory.resolve('engine/src/generated/')),
          Directory.fromUri(
            workingDirectory.resolve('engine/src/generated/.backup/'),
          ),
        );
      }

      print(
        Colorize(
          'Generating code in ${workingDirectory.toFilePath(windows: Platform.isWindows)}...',
        ).lightGreen(),
      );

      diffChecker?.save();

      final process = await Process.start(
        'dart',
        ['run', 'build_runner', 'build', '--delete-conflicting-outputs'],
        workingDirectory: workingDirectory.toFilePath(
          windows: Platform.isWindows,
        ),
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        print(Colorize('\n\nError: Code generation failed.').red());
        diffChecker?.cleanup();
        exit(exitCode);
      }

      print(Colorize('\nChecking for C++ file changes...').lightGreen());
      diffChecker?.restore();
      diffChecker?.cleanup();
    }

    // The new Dart 3.7 formatter isn't applied to code generated files for some
    // resaon, so we have to apply it manually.
    //
    // This should be removed later, as this will probably be fixed soon after
    // the time of writing.
    if (argResults!['explicit-format-for-ci']) {
      print('Formatting generated code...');
      final files = Directory.fromUri(packageRootPath)
          .listSync(recursive: true)
          .where((f) {
            return f.path.endsWith('.g.dart') || f.path.endsWith('.mocks.dart');
          });

      for (final file in files) {
        final process = await Process.start(
          'dart',
          ['format', file.path],
          workingDirectory: packageRootPath.toFilePath(
            windows: Platform.isWindows,
          ),
          mode: ProcessStartMode.inheritStdio,
        );

        final exitCode = await process.exitCode;

        if (exitCode != 0) {
          print(Colorize('\n\nError: Code formatting failed.').red());
          exit(exitCode);
        }
      }
    }

    print(Colorize('\n\nCode generation complete.').lightGreen());
  }
}

/// Backs up an existing folder with generated files, and replaces new generated
/// with the backed up files if they haven't changed.
///
/// When the C++ compiler checks whether to rebuild something, it will check for
/// changes to the input files. These checks are done by comparing the
/// modification times of the files, and if they haven't changed, it won't
/// rebuild them.
///
/// When we run the code generator, no matter what files have acutally changed,
/// the C++ compiler must rebuild all of the generated files, which cascades
/// into a rebuild of most of the engine since most of the engine depends on the
/// generated files.
///
/// This class prevents this by allowing us to back up the engine's generated
/// files before code generation runs. Then, after code generation is complete,
/// we can check if the contents of the new files are actually different. If any
/// of the new files are identical, we can replace the new file with the old
/// file, so the compiler doesn't think the files have changed and doesn't
/// rebuild them.
class _DiffChecker {
  final Directory _generatedDir;
  final Directory _backupDir;

  /// If true, the diff checker will not perform any operations. This will happen
  /// on a fresh build.
  late bool _noop;

  _DiffChecker(this._generatedDir, this._backupDir) {
    if (_backupDir.existsSync()) {
      print(
        Colorize(
          'Backup directory must not already exist. You will need to manually delete the folder at ${_backupDir.path}.',
        ).red(),
      );

      throw Exception('Backup directory must not already exist.');
    }

    _noop = !_generatedDir.existsSync();
  }

  void save() {
    if (_noop) return;

    _backupDir.createSync(recursive: true);

    _generatedDir.listSync(recursive: true).forEach((file) {
      if (file is! File) return;

      final relativePath = file.path.replaceFirst(_generatedDir.path, '');
      final backupFile = File('${_backupDir.path}/$relativePath');
      backupFile.createSync(recursive: true);
      file.copySync(backupFile.path);
    });
  }

  void restore() {
    if (_noop) return;

    if (!_backupDir.existsSync()) {
      throw Exception('Backup directory does not exist.');
    }

    int count = 0;

    _backupDir.listSync(recursive: true).forEach((file) {
      if (file is! File) return;

      final relativePath = file.path.replaceFirst(_backupDir.path, '');
      final generatedFile = File('${_generatedDir.path}/$relativePath');

      // If the file used to exist but doesn't exist anymore, we can ignore it.
      if (!generatedFile.existsSync()) {
        return;
      }

      final backupBytes = file.readAsBytesSync();
      final backupHash = sha256.convert(backupBytes);
      final generatedBytes = generatedFile.readAsBytesSync();
      final generatedHash = sha256.convert(generatedBytes);

      if (backupHash == generatedHash) {
        // If the files are identical, we want to copy from the backup to the
        // generated file.
        file.copySync(generatedFile.path);
      } else {
        count++;
      }
    });

    print(
      Colorize('$count ${count == 1 ? 'file' : 'files'} changed.').lightGreen(),
    );
  }

  void cleanup() {
    if (_noop) return;

    _backupDir.deleteSync(recursive: true);
  }
}
