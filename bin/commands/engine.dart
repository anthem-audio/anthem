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

class EngineCommand extends Command<dynamic> {
  @override
  String get name => 'engine';

  @override
  String get description => 'Utilities for devleoping the Anthem engine.';

  EngineCommand() {
    addSubcommand(_BuildEngineCommand());
  }
}

class _BuildEngineCommand extends Command<dynamic> {
  @override
  String get name => 'build';

  @override
  String get description => 'Builds the Anthem engine.';

  _BuildEngineCommand() {
    argParser.addFlag('release', abbr: 'r', negatable: false, defaultsTo: true);
    argParser.addFlag('debug', abbr: 'd', negatable: false, defaultsTo: false);
  }

  @override
  Future<void> run() async {
    print(Colorize('Building the Anthem engine...\n\n')..lightGreen());

    // Check for generated files. If there aren't any, provide an error.
    final packageRootPath = getPackageRootPath();
    final generatedCppFiles = Directory.fromUri(
      packageRootPath.resolve('engine/src/generated'),
    ).listSync(recursive: true);

    if (generatedCppFiles.isEmpty) {
      print(Colorize('''Error: No generated files found. Run
    dart run anthem:cli codegen generate
to generate the files.''')..red());
      return;
    }

    print(
        '''Note: Code generation must be run to keep the generated files up-to-date.

Some things to keep in mind:
 - The following command can be used to keep the generated files up to date:
       dart run anthem:cli codegen generate --watch
 - Both Dart and C++ files may be generated by a given Dart source file.
 - If the Dart source file imports something that is used in its generated
   code, then the change may not be detected. In this case, you will need to
   run:
       dart run anthem:cli codegen clean
   and
       dart run anthem:cli codegen generate
   to regenerate the files.
 - There is code in this build script to check for outdated IPC message files,
   but this is not foolproof, and does not work for generated model files. If
   you are having unexpected build errors related to missing or seemingly-
   outdated files, or if the compiled code is not updating as expected, try
   running the above commands.


''');

    if (await _isIpcOutdated()) {
      print(Colorize(
          '''Error: IPC message files are outdated, and cannot be updated
normally due to a limitation in package:build. Run
    dart run anthem:cli codegen clean
    dart run anthem:cli codegen generate
to generate the files, then run this script again.''')
        ..red());
      return;
    }

    print(Colorize('Creating build directory...')..lightGreen());
    final buildDirPath = packageRootPath.resolve('engine/build');
    final buildDir = Directory.fromUri(buildDirPath);
    buildDir.createSync();

    // final env = <String, String>{
    // };

    print(Colorize('Running CMake...')..lightGreen());
    final cmakeProcess = await Process.start(
      'cmake',
      [
        if (Platform.isLinux) '-DCMAKE_C_COMPILER=clang',
        if (Platform.isLinux) '-DCMAKE_CXX_COMPILER=clang++',

        // Note: On Linux, if you get an error like:
        // CMake Warning:
        //   Manually-specified variables were not used by the project:
        // 
        //     CMAKE_BUILD_TYPE
        //
        // Then you may need to set the debug/release flag in the same way that
        // Windows (and eventually macOS) does below in the build command. E.g.:
        //    cmake --build . --config (Release/Debug)
        if (Platform.isLinux) '-DCMAKE_BUILD_TYPE=${argResults!['debug'] ? 'Debug' : 'Release'}',

        '..',
      ],
      workingDirectory: buildDirPath.toFilePath(windows: Platform.isWindows),
      mode: ProcessStartMode.inheritStdio,
    );

    final cmakeExitCode = await cmakeProcess.exitCode;
    if (cmakeExitCode != 0) {
      print(Colorize('\n\nError: CMake failed.').red());
      exit(exitCode);
    }

    print(Colorize('Running build...')..lightGreen());
    final buildProcess = await Process.start(
      'cmake',
      [
        '--build',
        '.',
        '--target',
        'AnthemEngine',
        if (Platform.isWindows || Platform.isMacOS) '--config',
        if (Platform.isWindows || Platform.isMacOS) argResults!['debug'] ? 'Debug' : 'Release',
      ],
      workingDirectory: buildDirPath.toFilePath(windows: Platform.isWindows),
      mode: ProcessStartMode.inheritStdio,
    );

    final buildExitCode = await buildProcess.exitCode;
    if (buildExitCode != 0) {
      print(Colorize('\n\nError: Build failed.').red());
      exit(exitCode);
    }

    print(Colorize('\n\nBuild complete.').lightGreen());
  }
}

Future<bool> _isIpcOutdated() async {
  final packageRootPath = getPackageRootPath();
  final messagesFiles = Directory.fromUri(
    packageRootPath.resolve('lib/engine_api/messages'),
  ).listSync(recursive: true);

  final generatedFiles = messagesFiles.where((file) {
    return file.path.endsWith('.g.dart');
  });
  final sourceFiles = messagesFiles.where((file) {
    return file.path.endsWith('.dart') && !file.path.endsWith('.g.dart');
  });

  final newestGeneratedFileDateFuture = Future.wait(generatedFiles.map((file) {
    return file.stat().then((f) => f.modified);
  })).then((dates) => dates.reduce((a, b) => a.isAfter(b) ? a : b));
  final newestGeneratedFileDate = await newestGeneratedFileDateFuture;

  final newestSourceFileDateFuture = Future.wait(sourceFiles.map((file) {
    return file.stat().then((f) => f.modified);
  })).then((dates) => dates.reduce((a, b) => a.isAfter(b) ? a : b));
  final newestSourceFileDate = await newestSourceFileDateFuture;

  return newestGeneratedFileDate.isBefore(newestSourceFileDate);
}
