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
// cspell:ignore DCMAKE fsanitize

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';

import '../util/misc.dart';

class EngineCommand extends Command<dynamic> {
  @override
  String get name => 'engine';

  @override
  String get description => 'Utilities for developing the Anthem engine.';

  EngineCommand() {
    addSubcommand(_BuildEngineCommand());
    addSubcommand(_CleanEngineCommand());
    addSubcommand(_EngineUnitTestCommand());
  }
}

class _BuildEngineCommand extends Command<dynamic> {
  @override
  String get name => 'build';

  @override
  String get description => 'Builds the Anthem engine.';

  _BuildEngineCommand() {
    argParser.addFlag(
      'release',
      abbr: 'r',
      defaultsTo: false,
      help: 'Builds the engine in release mode.',
    );

    argParser.addFlag(
      'debug',
      abbr: 'd',
      defaultsTo: false,
      help: 'Builds the engine in debug mode.',
    );

    argParser.addFlag(
      'address-sanitizer',
      defaultsTo: false,
      help:
          'Builds the engine with address sanitizer enabled. This does not work with MSVC.',
    );
  }

  @override
  Future<void> run() async {
    if (argResults!['release'] && argResults!['debug']) {
      print(
        Colorize('Error: Cannot build in both release and debug mode.')..red(),
      );
      return;
    }

    if (!argResults!['release'] && !argResults!['debug']) {
      print(
        Colorize('Error: Must build in either release or debug mode.')..red(),
      );
      return;
    }

    if (argResults!['release'] && argResults!['address-sanitizer']) {
      print(
        Colorize(
          'Error: Cannot build in release mode with address sanitizer enabled.',
        )..red(),
      );
      return;
    }

    print(Colorize('Building the Anthem engine...\n\n')..lightGreen());

    // Check for generated files. If there aren't any, provide an error.
    final packageRootPath = getPackageRootPath();
    final generatedCppFiles = Directory.fromUri(
      packageRootPath.resolve('engine/src/generated/'),
    ).listSync(recursive: true);

    if (generatedCppFiles.isEmpty) {
      print(
        Colorize('''Error: No generated files found. Run
    dart run anthem:cli codegen generate
to generate the files.''')..red(),
      );
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


''',
    );

    if (await _isIpcOutdated()) {
      print(
        Colorize('''Error: IPC message files are outdated, and cannot be updated
normally due to a limitation in package:build. Run
    dart run anthem:cli codegen clean
    dart run anthem:cli codegen generate
to generate the files, then run this script again.''')..red(),
      );
      return;
    }

    await _buildCmakeTarget(
      'AnthemEngine',
      addressSanitizer: argResults!['address-sanitizer'],
      debug: argResults!['debug'],
    );

    print(
      Colorize('Copying engine binary to Flutter assets directory...')
        ..lightGreen(),
    );
    final engineBinaryPath = packageRootPath.resolve(
      'engine/build/AnthemEngine_artefacts${argResults!['debug'] ? '/Debug' : '/Release'}/AnthemEngine${Platform.isWindows ? '.exe' : ''}',
    );
    final flutterAssetsDirPath = packageRootPath.resolve('assets/engine/');

    // Create the engine directory in assets if it doesn't exist
    final flutterAssetsDir = Directory.fromUri(flutterAssetsDirPath);
    if (!flutterAssetsDir.existsSync()) {
      flutterAssetsDir.createSync(recursive: true);
    }

    // Copy the engine binary to the Flutter assets directory
    final flutterEngineBinaryPath = flutterAssetsDirPath.resolve(
      'AnthemEngine${Platform.isWindows ? '.exe' : ''}',
    );
    File.fromUri(
      engineBinaryPath,
    ).copySync(flutterEngineBinaryPath.toFilePath(windows: Platform.isWindows));

    print(Colorize('Copy complete.').lightGreen());
  }
}

Future<bool> _isIpcOutdated() async {
  final packageRootPath = getPackageRootPath();
  final messagesFiles = Directory.fromUri(
    packageRootPath.resolve('lib/engine_api/messages/'),
  ).listSync(recursive: true);
  final generatedFile = File.fromUri(
    packageRootPath.resolve(
      './engine/src/generated/lib/engine_api/messages/messages.h',
    ),
  );
  if (!await generatedFile.exists()) {
    // The generated file doesn't exist, so it can't be outdated.
    return false;
  }

  final sourceFiles = messagesFiles.where((file) {
    return file.path.endsWith('.dart') && !file.path.endsWith('.g.dart');
  });

  final generatedFileModifiedDate = (await generatedFile.stat()).modified;

  final newestSourceFileDateFuture = Future.wait(
    sourceFiles.map((file) {
      return file.stat().then((f) => f.modified);
    }),
  ).then((dates) => dates.reduce((a, b) => a.isAfter(b) ? a : b));
  final newestSourceFileDate = await newestSourceFileDateFuture;

  return generatedFileModifiedDate.isBefore(newestSourceFileDate);
}

class _CleanEngineCommand extends Command<dynamic> {
  @override
  String get name => 'clean';

  @override
  String get description => 'Cleans the Anthem engine build.';

  @override
  Future<void> run() async {
    print(Colorize('Cleaning the Anthem engine build...')..lightGreen());

    final packageRootPath = getPackageRootPath();
    final buildDirPath = packageRootPath.resolve('engine/build/');
    final buildAsanDirPath = packageRootPath.resolve('engine/build_asan/');
    final buildDir = Directory.fromUri(buildDirPath);
    final buildAsanDir = Directory.fromUri(buildAsanDirPath);

    print(Colorize('Deleting build directory...')..lightGreen());
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }
    if (buildAsanDir.existsSync()) {
      buildAsanDir.deleteSync(recursive: true);
    }

    print(Colorize('Clean complete.').lightGreen());
  }
}

class _EngineUnitTestCommand extends Command<dynamic> {
  @override
  String get name => 'unit-test';

  @override
  String get description => 'Runs unit tests for the Anthem engine.';

  @override
  Future<void> run() async {
    print(Colorize('Running tests for the Anthem engine...')..lightGreen());

    await _buildCmakeTarget('AnthemTest', debug: true);

    final packageRootPath = getPackageRootPath();
    final testExecutableLocation = packageRootPath.resolve(
      'engine/build${Platform.isWindows ? '/Debug' : ''}/AnthemTest${Platform.isWindows ? '.exe' : ''}',
    );

    final testProcess = await Process.start(
      testExecutableLocation.toFilePath(windows: Platform.isWindows),
      [],
      mode: ProcessStartMode.normal,
    );

    var hasError = false;
    testProcess.stdout.listen(stdout.add);
    testProcess.stderr.listen((e) {
      stderr.add(e);
      hasError = true;
    });

    final testExitCode = await testProcess.exitCode;

    if (hasError) {
      print(Colorize('\n\nError: Tests failed (stderr was not empty).').red());
      exit(exitCode);
    } else if (testExitCode == 0xFFFF_FFFF_C000_0005) {
      // The leak detector isn't happy with a couple items in Anthem right now.
      // So far these are due to missing cleanup of objects whose lifetime is
      // equal to the lifetime of the application, and so they don't represent a
      // "real" memory leak.
      //
      // However, the fact that this always fails means we can't really take
      // advantage of the JUCE leak detector. We should add all our objects to
      // the leak detector, fix these leak detector items, and promote this to a
      // test failure.
      print(
        Colorize(
          '\n\nTests passed, but the JUCE leak detector reported a leak. This is due to us just not cleaning up some things; however, this should be fixed and promoted to an error.',
        ).yellow(),
      );
    }

    print(Colorize('Testing complete.').lightGreen());
  }
}

Future<void> _buildCmakeTarget(
  String target, {
  bool addressSanitizer = false,
  bool debug = false,
}) async {
  if (addressSanitizer) {
    print(
      Colorize(
        'WARNING: Address sanitizer is enabled. The UI will not automatically run this build. You will need to modify engine_connector.dart to do one of the following:',
      )..yellow(),
    );
    print(
      Colorize(
        ' - Use the `./engine/build_asan/...` directory as the engine binary location.',
      )..yellow(),
    );
    print(
      Colorize(
        ' - Not actually run the engine binary, but instead just output the arguments to the console, to allow you to start it manually.',
      )..yellow(),
    );
  }

  final packageRootPath = getPackageRootPath();

  final buildDirName = addressSanitizer ? 'build_asan' : 'build';

  print(Colorize('Creating build directory...')..lightGreen());
  final buildDirPath = packageRootPath.resolve('engine/$buildDirName/');
  final buildDir = Directory.fromUri(buildDirPath);
  buildDir.createSync();

  print(Colorize('Running CMake...')..lightGreen());
  final cmakeProcess = await Process.start(
    'cmake',
    [
      // Note: On Linux, if you get an error like: CMake Warning:
      // Manually-specified variables were not used by the project:
      //
      //     CMAKE_BUILD_TYPE
      //
      // Then you may need to set the debug/release flag in the same way that
      // Windows does below in the build command. E.g.:
      //     cmake --build . --config (Release/Debug)
      if (Platform.isLinux || Platform.isMacOS)
        '-DCMAKE_BUILD_TYPE=${debug ? 'Debug' : 'Release'}',

      if (addressSanitizer && (Platform.isLinux || Platform.isMacOS)) ...[
        '-DCMAKE_C_FLAGS=-fsanitize=address',
        '-DCMAKE_CXX_FLAGS=-fsanitize=address',
        '-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address',
        '-DCMAKE_C_FLAGS_DEBUG=-fsanitize=address',
        '-DCMAKE_CXX_FLAGS_DEBUG=-fsanitize=address',
        '-DCMAKE_EXE_LINKER_FLAGS_DEBUG=-fsanitize=address',
        '-DCMAKE_C_FLAGS_DEBUG=-fno-omit-frame-pointer',
        '-DCMAKE_CXX_FLAGS_DEBUG=-fno-omit-frame-pointer',
        '-DCMAKE_EXE_LINKER_FLAGS_DEBUG=-fno-omit-frame-pointer',
        '-DCMAKE_C_FLAGS_DEBUG=-g',
        '-DCMAKE_CXX_FLAGS_DEBUG=-g',
        '-DCMAKE_EXE_LINKER_FLAGS_DEBUG=-g',
        '-DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address',
      ],

      if (addressSanitizer && Platform.isWindows) ...[
        r'-DCMAKE_C_FLAGS="/fsanitize=address"',
        r'-DCMAKE_CXX_FLAGS="/fsanitize=address"',
      ],

      '..',
    ],
    workingDirectory: buildDirPath.toFilePath(windows: Platform.isWindows),
    environment: {
      if (Platform.isLinux) 'CC': '/usr/bin/clang',
      if (Platform.isLinux) 'CXX': '/usr/bin/clang++',
    },
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
      target,
      // For macOS, I think these are ignored, but they don't seem to break
      // anything.
      if (Platform.isWindows || Platform.isMacOS) '--config',
      if (Platform.isWindows || Platform.isMacOS) debug ? 'Debug' : 'Release',
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
