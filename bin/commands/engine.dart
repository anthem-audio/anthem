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
// cspell:ignore DCMAKE fsanitize emcmake

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';

import '../cli_helpers.dart';

class EngineCommand extends Command<dynamic> {
  @override
  String get name => 'engine';

  @override
  String get description =>
      'Build, clean, format, lint, or test the Anthem engine.';

  EngineCommand() {
    addSubcommand(_BuildEngineCommand());
    addSubcommand(_BuildLameCommand());
    addSubcommand(_CleanEngineCommand());
    addSubcommand(_FormatEngineCommand());
    addSubcommand(_LintEngineCommand());
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
      help: 'Builds the engine with address sanitizer enabled.',
    );

    argParser.addFlag(
      'wasm',
      defaultsTo: false,
      help:
          'Builds the engine with a WebAssembly target, and copies the output to the Flutter web directory. '
          'This is only tested on Linux, though it is likely also possible on macOS. Windows users should use WSL2 for this.',
    );

    argParser.addFlag(
      'skip-configuration',
      defaultsTo: false,
      help:
          'Skips the configuration step (cmake ..). A regular build must have been run once for the same configuration, otherwise this will fail.',
    );

    argParser.addOption(
      'jobs',
      abbr: 'j',
      help:
          'Maximum number of parallel build jobs to pass to CMake. Use 1 for single-threaded compilation.',
    );

    if (Platform.isWindows) {
      argParser.addFlag(
        'clang',
        defaultsTo: false,
        help:
            'On Windows desktop builds, uses the Ninja generator with clang/clang++ instead of the default MSVC generator. Useful for warning checks and clang-tidy.',
      );
    }
  }

  @override
  Future<void> run() async {
    final release = argResults!['release'] as bool;
    final debug = argResults!['debug'] as bool;
    final addressSanitizer = argResults!['address-sanitizer'] as bool;
    final wasm = argResults!['wasm'] as bool;
    final skipConfiguration = argResults!['skip-configuration'] as bool;
    final useClang = Platform.isWindows ? argResults!['clang'] as bool : false;
    final jobs = _parseJobsOption(argResults!['jobs'] as String?);

    if (release && debug) {
      print(
        Colorize('Error: Cannot build in both release and debug mode.')..red(),
      );
      return;
    }

    if (!release && !debug) {
      print(
        Colorize('Error: Must build in either release or debug mode.')..red(),
      );
      return;
    }

    if (release && addressSanitizer) {
      print(
        Colorize(
          'Error: Cannot build in release mode with address sanitizer enabled.',
        )..red(),
      );
      return;
    }

    if (wasm && useClang) {
      print(
        Colorize(
          'Error: The --clang flag is only for desktop builds. Use --wasm without it for the Emscripten path.',
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
 - If you are having unexpected build errors related to missing or seemingly-
   outdated files, or if the compiled code is not updating as expected, try
   running the above commands.


''',
    );

    final buildDirectoryName = _getBuildDirectoryName(
      wasm: wasm,
      release: release,
      addressSanitizer: addressSanitizer,
      useClang: useClang,
    );

    await _buildCmakeTarget(
      'AnthemEngine',
      wasm: wasm,
      addressSanitizer: addressSanitizer,
      debug: debug,
      useClang: useClang,
      buildDirectoryName: buildDirectoryName,
      skipConfiguration: skipConfiguration,
      jobs: jobs,
    );

    if (wasm) {
      print(
        Colorize('Copying engine binary to Flutter web directory...')
          ..lightGreen(),
      );

      final paths = [
        packageRootPath.resolve('engine/$buildDirectoryName/AnthemEngine.js'),
        packageRootPath.resolve('engine/$buildDirectoryName/AnthemEngine.wasm'),
        packageRootPath.resolve(
          'engine/$buildDirectoryName/AnthemEngine.wasm.map',
        ),
      ];

      final flutterWebDirPath = packageRootPath.resolve('web/engine/');
      final flutterWebDir = Directory.fromUri(flutterWebDirPath);

      if (!flutterWebDir.existsSync()) {
        flutterWebDir.createSync(recursive: true);
      }

      for (final path in paths) {
        print('Copying ${path.path}...');
        final fileName = path.pathSegments.last;
        final flutterEngineBinaryPath = flutterWebDirPath.resolve(fileName);
        if (!File.fromUri(path).existsSync()) {
          print('${path.path} not found.');
          continue;
        }
        File.fromUri(path).copySync(
          flutterEngineBinaryPath.toFilePath(windows: Platform.isWindows),
        );
      }

      print(Colorize('Copy complete.').lightGreen());
    } else {
      print(
        Colorize('Copying engine binary to Flutter assets directory...')
          ..lightGreen(),
      );
      final engineBinaryPath = _resolveExistingEngineBinaryLocation(
        buildDirectoryName: buildDirectoryName,
        debug: debug,
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
      File.fromUri(engineBinaryPath).copySync(
        flutterEngineBinaryPath.toFilePath(windows: Platform.isWindows),
      );

      print(Colorize('Copy complete.').lightGreen());
    }
  }
}

class _BuildLameCommand extends Command<dynamic> {
  @override
  String get name => 'build-lame';

  @override
  String get description => 'Builds LAME and copies it to Flutter assets.';

  _BuildLameCommand() {
    argParser.addOption(
      'jobs',
      abbr: 'j',
      help: 'Maximum number of parallel build jobs to pass to make.',
    );
  }

  @override
  Future<void> run() async {
    final jobs =
        _parseJobsOption(argResults!['jobs'] as String?) ??
        Platform.numberOfProcessors;
    final packageRootPath = getPackageRootPath();
    final lameSourcePath = packageRootPath.resolve('engine/include/lame/');

    if (!File.fromUri(lameSourcePath.resolve('configure')).existsSync()) {
      print(
        Colorize(
          'Error: Could not find LAME source at engine/include/lame.',
        ).red(),
      );
      exit(1);
    }

    print(Colorize('Building LAME...\n\n')..lightGreen());

    final buildRootPath = packageRootPath.resolve(
      'build/lame/${_getLamePlatformId()}/',
    );
    final sourceBuildPath = buildRootPath.resolve('source/');
    final outputBinaryPath = buildRootPath.resolve(_lameExecutableName);

    _recreateBuildDirectory(buildRootPath);
    _copyDirectorySync(
      Directory.fromUri(lameSourcePath),
      Directory.fromUri(sourceBuildPath),
    );
    _normalizeLameBuildLineEndings(sourceBuildPath);

    if (Platform.isWindows) {
      await _buildLameOnWindows(sourceBuildPath, jobs: jobs);
    } else {
      await _buildLameOnUnix(sourceBuildPath, jobs: jobs);
    }

    final builtBinaryPath = _resolveBuiltLameBinaryLocation(sourceBuildPath);
    File.fromUri(
      builtBinaryPath,
    ).copySync(outputBinaryPath.toFilePath(windows: Platform.isWindows));
    await _makeExecutable(outputBinaryPath);

    final flutterAssetsDirPath = packageRootPath.resolve('assets/engine/');
    final flutterAssetsDir = Directory.fromUri(flutterAssetsDirPath);
    if (!flutterAssetsDir.existsSync()) {
      flutterAssetsDir.createSync(recursive: true);
    }

    final flutterLamePath = flutterAssetsDirPath.resolve(_lameExecutableName);
    File.fromUri(
      outputBinaryPath,
    ).copySync(flutterLamePath.toFilePath(windows: Platform.isWindows));
    await _makeExecutable(flutterLamePath);

    print(Colorize('\n\nLAME build complete.').lightGreen());
  }
}

class _CleanEngineCommand extends Command<dynamic> {
  _CleanEngineCommand() {
    argParser.addFlag(
      'y',
      defaultsTo: false,
      help: 'Automatically confirm all prompts.',
    );
  }

  @override
  String get name => 'clean';

  @override
  String get description => 'Cleans the Anthem engine build.';

  @override
  Future<void> run() async {
    final skipPrompts = argResults!['y'] as bool;

    print(Colorize('Cleaning the Anthem engine build...')..lightGreen());

    final packageRoot = getPackageRootPath();
    final engineDirPath = packageRoot.resolve('engine/');

    final folders = Directory.fromUri(engineDirPath)
        .listSync()
        .whereType<Directory>()
        .where((dir) {
          final pathSegments = dir.uri.pathSegments;
          for (var i = pathSegments.length - 1; i >= 0; i--) {
            if (pathSegments[i].isEmpty) continue;
            return pathSegments[i].startsWith('build');
          }
          return false;
        })
        .toList();

    final webEngineDir = Directory.fromUri(packageRoot.resolve('web/engine'));
    if (webEngineDir.existsSync()) {
      folders.add(webEngineDir);
    }

    if (folders.isEmpty) {
      print(
        Colorize('No build directories found, nothing to clean.')..lightGreen(),
      );
      return;
    }

    if (!skipPrompts) {
      print(Colorize('This will remove the following directories:')..yellow());
      for (final dir in folders) {
        print(Colorize(' - ${dir.path}'));
      }
      print(Colorize('Are you sure you want to continue? (y/N)')..yellow());

      final confirmation = stdin.readLineSync();
      if (confirmation?.toLowerCase() != 'y') {
        print(Colorize('Aborting clean operation.')..red());
        return;
      }
    }

    print(Colorize('Deleting build directories...')..lightGreen());
    for (final dir in folders) {
      try {
        dir.deleteSync(recursive: true);
        print(Colorize('Deleted ${dir.path}'));
      } catch (e) {
        print(Colorize('Failed to delete ${dir.uri}: $e')..red());
      }
    }

    print(Colorize('Clean complete.').lightGreen());
  }
}

class _FormatEngineCommand extends Command<dynamic> {
  _FormatEngineCommand() {
    argParser.addFlag(
      'check',
      defaultsTo: false,
      help:
          'Checks whether the engine C++ files are already formatted without modifying them.',
    );
  }

  @override
  String get name => 'format';

  @override
  String get description => 'Formats Anthem-owned engine C++ files.';

  @override
  Future<void> run() async {
    final checkOnly = argResults!['check'] as bool;

    print(
      Colorize(
        checkOnly
            ? 'Checking Anthem engine C++ formatting...'
            : 'Formatting Anthem engine C++ files...',
      )..lightGreen(),
    );

    final clangFormat = _requireLlvmExecutable('clang-format');
    final packageRootPath = getPackageRootPath();
    final files = _getOwnedEngineCppFiles();

    if (files.isEmpty) {
      print(
        Colorize('No engine C++ files found, nothing to format.')..lightGreen(),
      );
      return;
    }

    var hasFailures = false;

    for (final file in files) {
      final process = await Process.start(
        clangFormat,
        [
          if (checkOnly) '--dry-run',
          if (checkOnly) '--Werror',
          if (!checkOnly) '-i',
          file.path,
        ],
        workingDirectory: packageRootPath.toFilePath(
          windows: Platform.isWindows,
        ),
        mode: ProcessStartMode.inheritStdio,
      );

      final formatExitCode = await process.exitCode;
      if (formatExitCode != 0) {
        hasFailures = true;
      }
    }

    if (hasFailures) {
      print(
        Colorize(
          checkOnly
              ? '\n\nError: Engine C++ formatting check failed.'
              : '\n\nError: Engine C++ formatting failed.',
        ).red(),
      );
      exit(1);
    }

    print(
      Colorize(
        checkOnly ? 'Formatting check complete.' : 'Formatting complete.',
      ).lightGreen(),
    );
  }
}

class _LintEngineCommand extends Command<dynamic> {
  _LintEngineCommand() {
    argParser.addFlag(
      'skip-configuration',
      defaultsTo: false,
      help:
          'Skips refreshing the CMake compile database. The lint build directory must already be configured.',
    );
  }

  @override
  String get name => 'lint';

  @override
  String get description => 'Runs clang-tidy on Anthem-owned engine C++ files.';

  @override
  Future<void> run() async {
    final skipConfiguration = argResults!['skip-configuration'] as bool;

    print(Colorize('Linting Anthem engine C++ files...')..lightGreen());

    final clangTidy = _requireLlvmExecutable('clang-tidy');
    final useClangBuild = Platform.isWindows;
    final buildDirectoryName = _getBuildDirectoryName(
      wasm: false,
      release: false,
      addressSanitizer: false,
      useClang: useClangBuild,
    );

    if (!skipConfiguration) {
      await _configureCmakeBuild(
        debug: true,
        useClang: useClangBuild,
        buildDirectoryName: buildDirectoryName,
      );
    }

    final packageRootPath = getPackageRootPath();
    final compileCommandsFile = File.fromUri(
      packageRootPath.resolve(
        'engine/$buildDirectoryName/compile_commands.json',
      ),
    );

    if (!compileCommandsFile.existsSync()) {
      print(
        Colorize(
          'Error: No compile_commands.json found for clang-tidy. Run the lint command without --skip-configuration, or configure the engine build first.',
        ).red(),
      );
      exit(1);
    }

    final extraArgs = await _getClangTidyExtraArgs();
    final files = _getOwnedEngineCppFiles(translationUnitsOnly: true);
    var hasFailures = false;
    var completedFileCount = 0;

    for (final file in files) {
      completedFileCount++;
      final relativeFilePath = _getPathRelativeToRoot(packageRootPath, file);
      print(
        '[$completedFileCount/${files.length}] clang-tidy $relativeFilePath',
      );

      final process = await Process.start(
        clangTidy,
        [
          '-p',
          compileCommandsFile.parent.path,
          '--quiet',
          '--warnings-as-errors=*',
          ...extraArgs,
          file.path,
        ],
        workingDirectory: packageRootPath.toFilePath(
          windows: Platform.isWindows,
        ),
        mode: ProcessStartMode.inheritStdio,
      );

      final lintExitCode = await process.exitCode;
      if (lintExitCode != 0) {
        hasFailures = true;
      }
    }

    if (hasFailures) {
      print(Colorize('\n\nError: clang-tidy found issues.').red());
      exit(1);
    }

    print(Colorize('Lint complete.').lightGreen());
  }
}

class _EngineUnitTestCommand extends Command<dynamic> {
  _EngineUnitTestCommand() {
    argParser.addOption(
      'jobs',
      abbr: 'j',
      help:
          'Maximum number of parallel build jobs to pass to CMake before running tests. Use 1 for single-threaded compilation.',
    );

    if (Platform.isWindows) {
      argParser.addFlag(
        'clang',
        defaultsTo: false,
        help:
            'On Windows, uses the Ninja generator with clang/clang++ instead of the default MSVC generator.',
      );
    }
  }

  @override
  String get name => 'unit-test';

  @override
  String get description => 'Runs unit tests for the Anthem engine.';

  @override
  Future<void> run() async {
    print(Colorize('Running tests for the Anthem engine...')..lightGreen());

    final useClang = Platform.isWindows ? argResults!['clang'] as bool : false;
    final jobs = _parseJobsOption(argResults!['jobs'] as String?);
    final buildDirectoryName = _getBuildDirectoryName(
      wasm: false,
      release: false,
      addressSanitizer: false,
      useClang: useClang,
    );

    await _buildCmakeTarget(
      'AnthemTest',
      debug: true,
      useClang: useClang,
      buildDirectoryName: buildDirectoryName,
      jobs: jobs,
    );

    final testExecutableLocation = _getEngineTestBinaryLocation(
      buildDirectoryName: buildDirectoryName,
      debug: true,
      useClang: useClang,
    );

    final testProcess = await Process.start(
      testExecutableLocation.toFilePath(windows: Platform.isWindows),
      [],
      mode: ProcessStartMode.normal,
    );

    // stderr lines matching any of these patterns are dropped: they're known
    // benign noise that shouldn't fail the run. Blank lines are ignored because
    // LineSplitter emits one between each paragraph of real stderr.
    final stderrIgnorePatterns = <RegExp>[
      RegExp(r'^\s*$'),
      // On headless Linux CI runners /dev/snd/seq doesn't exist; JUCE probes
      // ALSA during MIDI init, ALSA prints this, then JUCE's jassertfalse
      // below fires. Neither is a real failure for our test suite.
      RegExp(
        r'^ALSA lib seq_hw\.c:\d+:\(snd_seq_hw_open\) '
        r'open /dev/snd/seq failed: No such file or directory$',
      ),
      RegExp(r'^JUCE Assertion failure in juce_Midi_linux\.cpp:\d+$'),
    ];

    final stderrLines = <String>[];
    final stdoutSubscription = testProcess.stdout.listen(stdout.add);
    final stderrSubscription = testProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (stderrIgnorePatterns.any((p) => p.hasMatch(line))) return;
          stderr.writeln(line);
          stderrLines.add(line);
        });

    final testExitCode = await testProcess.exitCode;
    await Future.wait([
      stdoutSubscription.asFuture<void>(),
      stderrSubscription.asFuture<void>(),
    ]);

    if (stderrLines.isNotEmpty) {
      print(Colorize('\n\nError: Tests failed (stderr was not empty).').red());
      print(
        Colorize('\nLines captured on stderr (${stderrLines.length}):').red(),
      );
      for (final line in stderrLines) {
        print(Colorize('  $line').red());
      }
      exit(1);
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
  bool wasm = false,
  bool addressSanitizer = false,
  bool debug = false,
  bool useClang = false,
  bool skipConfiguration = false,
  String buildDirectoryName = 'build',
  int? jobs,
}) async {
  if (addressSanitizer && !wasm) {
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

  final buildDirPath = packageRootPath.resolve('engine/$buildDirectoryName/');
  final usesSingleConfigBuild = _usesSingleConfigBuild(
    wasm: wasm,
    useClang: useClang,
  );

  if (!skipConfiguration) {
    await _configureCmakeBuild(
      wasm: wasm,
      addressSanitizer: addressSanitizer,
      debug: debug,
      useClang: useClang,
      buildDirectoryName: buildDirectoryName,
    );
  }

  print(Colorize('Running build...')..lightGreen());

  final buildCommand = [
    'cmake',
    '--build',
    '.',
    '--target',
    target,
    if (jobs != null) '--parallel',
    if (jobs != null) '$jobs',
    if (!usesSingleConfigBuild) '--config',
    if (!usesSingleConfigBuild) debug ? 'Debug' : 'Release',
  ];

  final Process buildProcess;

  if (Platform.isWindows && wasm) {
    buildProcess = await Process.start('wsl', [
      '--cd',
      buildDirPath.toFilePath(windows: Platform.isWindows),
      'bash',
      '-lc',
      buildCommand.map((e) => '"$e"').join(' '),
    ], mode: ProcessStartMode.inheritStdio);
  } else {
    buildProcess = await Process.start(
      buildCommand.first,
      buildCommand.skip(1).toList(),
      workingDirectory: buildDirPath.toFilePath(windows: Platform.isWindows),
      mode: ProcessStartMode.inheritStdio,
    );
  }

  final buildExitCode = await buildProcess.exitCode;
  if (buildExitCode != 0) {
    print(Colorize('\n\nError: Build failed.').red());
    exit(1);
  }

  print(Colorize('\n\nBuild complete.').lightGreen());
}

int? _parseJobsOption(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) {
    return null;
  }

  final parsed = int.tryParse(rawValue);
  if (parsed == null || parsed < 1) {
    print(
      Colorize('Error: --jobs must be an integer greater than or equal to 1.')
        ..red(),
    );
    exit(1);
  }

  return parsed;
}

Future<void> _configureCmakeBuild({
  bool wasm = false,
  bool addressSanitizer = false,
  bool debug = false,
  bool useClang = false,
  String buildDirectoryName = 'build',
}) async {
  final packageRootPath = getPackageRootPath();
  final buildDirPath = packageRootPath.resolve('engine/$buildDirectoryName/');
  final buildDirPathString = buildDirPath.toFilePath(
    windows: Platform.isWindows,
  );
  final usesSingleConfigBuild = _usesSingleConfigBuild(
    wasm: wasm,
    useClang: useClang,
  );
  final compilerEnvironment = _getCmakeCompilerEnvironment(
    wasm: wasm,
    useClang: useClang,
  );

  print(Colorize('Creating build directory...')..lightGreen());
  final buildDir = Directory.fromUri(buildDirPath);
  buildDir.createSync(recursive: true);

  final cmakeCommand = [
    if (wasm) 'emcmake',
    'cmake',
    if (Platform.isWindows && useClang && !wasm) ...['-G', 'Ninja'],

    // Note: On Linux, if you get an error like: CMake Warning:
    // Manually-specified variables were not used by the project:
    //
    //     CMAKE_BUILD_TYPE
    //
    // Then you may need to set the debug/release flag in the same way that
    // Windows does below in the build command. E.g.:
    //     cmake --build . --config (Release/Debug)
    if (usesSingleConfigBuild)
      '-DCMAKE_BUILD_TYPE=${debug ? 'Debug' : 'Release'}',

    if (Platform.isWindows && useClang && !wasm)
      '-DCMAKE_MAKE_PROGRAM=${_toCmakePath(_requireNinjaExecutable())}',

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

    if (addressSanitizer && Platform.isWindows && !wasm) ...[
      r'-DCMAKE_C_FLAGS="/fsanitize=address"',
      r'-DCMAKE_CXX_FLAGS="/fsanitize=address"',
    ],
    '..',
  ];

  print(Colorize('Running CMake...')..lightGreen());
  final Process cmakeProcess;

  if (Platform.isWindows && wasm) {
    cmakeProcess = await Process.start('wsl', [
      '--cd',
      buildDirPathString,
      'bash',
      '-lc',
      cmakeCommand.map((e) => '"$e"').join(' '),
    ], mode: ProcessStartMode.inheritStdio);
  } else {
    cmakeProcess = await Process.start(
      cmakeCommand.first,
      cmakeCommand.skip(1).toList(),
      workingDirectory: buildDirPathString,
      environment: compilerEnvironment,
      mode: ProcessStartMode.inheritStdio,
    );
  }

  final cmakeExitCode = await cmakeProcess.exitCode;
  if (cmakeExitCode != 0) {
    print(Colorize('\n\nError: CMake failed.').red());
    exit(1);
  }
}

String _getBuildDirectoryName({
  required bool wasm,
  required bool release,
  required bool addressSanitizer,
  required bool useClang,
}) {
  var buildDirectoryName = 'build';
  if (useClang) buildDirectoryName += '_clang';
  if (wasm) buildDirectoryName += '_wasm';
  if (release) buildDirectoryName += '_release';
  if (addressSanitizer) buildDirectoryName += '_asan';
  return buildDirectoryName;
}

bool _usesSingleConfigBuild({required bool wasm, required bool useClang}) {
  return Platform.isLinux ||
      Platform.isMacOS ||
      wasm ||
      (Platform.isWindows && useClang);
}

List<File> _getOwnedEngineCppFiles({bool translationUnitsOnly = false}) {
  final packageRootPath = getPackageRootPath();
  final fileExtensions = translationUnitsOnly ? ['.cpp'] : ['.cpp', '.h'];
  final files = <File>[];

  final roots = [
    Directory.fromUri(packageRootPath.resolve('engine/src/')),
    Directory.fromUri(packageRootPath.resolve('engine/test/')),
  ];

  for (final root in roots) {
    if (!root.existsSync()) continue;

    for (final entity in root.listSync(recursive: true).whereType<File>()) {
      if (entity.uri.pathSegments.contains('generated')) continue;

      final entityPath = entity.path.toLowerCase();
      if (fileExtensions.any((extension) => entityPath.endsWith(extension))) {
        files.add(entity);
      }
    }
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String _getPathRelativeToRoot(Uri packageRootPath, File file) {
  final rootPath = packageRootPath.toFilePath(windows: Platform.isWindows);
  final filePath = file.path;

  if (!filePath.startsWith(rootPath)) return filePath;

  return filePath
      .substring(rootPath.length)
      .replaceFirst(RegExp(r'^[\\/]'), '')
      .replaceAll('\\', '/');
}

Map<String, String> _getCmakeCompilerEnvironment({
  required bool wasm,
  required bool useClang,
}) {
  if (wasm) return const {};

  if (Platform.isLinux) {
    return {
      'CC': _requireLlvmExecutable('clang'),
      'CXX': _requireLlvmExecutable('clang++'),
    };
  }

  if (Platform.isWindows && useClang) {
    return {
      'CC': _requireLlvmExecutable('clang'),
      'CXX': _requireLlvmExecutable('clang++'),
    };
  }

  return const {};
}

Future<List<String>> _getClangTidyExtraArgs() async {
  if (!Platform.isMacOS) return const [];

  final processResult = await Process.run('xcrun', ['--show-sdk-path']);
  if (processResult.exitCode != 0) {
    print(
      Colorize(
        'Error: Could not find the macOS SDK path for clang-tidy. xcrun --show-sdk-path failed.',
      ).red(),
    );
    exit(1);
  }

  final sdkPath = (processResult.stdout as String).trim();
  if (sdkPath.isEmpty) {
    print(
      Colorize('Error: xcrun --show-sdk-path returned an empty path.').red(),
    );
    exit(1);
  }

  return ['--extra-arg=-isysroot', '--extra-arg=$sdkPath'];
}

String _requireLlvmExecutable(String executableName) {
  final executablePath = findLlvmExecutable(executableName);
  if (executablePath != null) return executablePath;

  print(
    Colorize(
      'Error: Could not find $executableName. Install LLVM and make it available on PATH, or set ANTHEM_LLVM_BIN to the LLVM bin directory.',
    ).red(),
  );
  exit(1);
}

String _requireNinjaExecutable() {
  final executablePath = findNinjaExecutable();
  if (executablePath != null) return executablePath;

  print(
    Colorize(
      'Error: Could not find ninja. Install Ninja and make it available on PATH before using the Windows clang engine workflow.',
    ).red(),
  );
  exit(1);
}

const _lameConfigureArguments = [
  '--disable-shared',
  '--enable-static',
  '--disable-nasm',
  '--disable-gtktest',
  '--disable-analyzer-hooks',
  '--disable-decoder',
  '--disable-dependency-tracking',
  '--with-fileio=lame',
];

String get _lameExecutableName => Platform.isWindows ? 'lame.exe' : 'lame';

void _normalizeLameBuildLineEndings(Uri sourceBuildPath) {
  // The LAME submodule has Windows checkout behavior, but Autotools needs LF.
  // Normalize only the disposable build copy so the submodule stays untouched.
  for (final entity in Directory.fromUri(
    sourceBuildPath,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (_fileSystemEntityName(entity) == '.git') continue;

    final bytes = entity.readAsBytesSync();
    if (bytes.contains(0)) continue;
    if (!bytes.contains(13)) continue;

    final normalizedBytes = <int>[];
    var changed = false;

    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      if (byte != 13) {
        normalizedBytes.add(byte);
        continue;
      }

      changed = true;
      normalizedBytes.add(10);
      if (i + 1 < bytes.length && bytes[i + 1] == 10) {
        i++;
      }
    }

    if (changed) {
      entity.writeAsBytesSync(normalizedBytes);
    }
  }
}

Future<void> _buildLameOnUnix(Uri sourceBuildPath, {required int jobs}) async {
  final workingDirectory = sourceBuildPath.toFilePath(windows: false);
  final environment = <String, String>{
    if (Platform.isLinux && Platform.environment['CC'] == null)
      'CC': _requireLlvmExecutable('clang'),
  };

  // LAME checks ncurses with initscr(), but the frontend uses tget* symbols
  // that some Linux SDKs split into libtinfo.
  if (Platform.isLinux && await _canLinkLameWithTInfo(environment)) {
    environment['LIBS'] = _appendBuildFlag(
      Platform.environment['LIBS'],
      '-ltinfo',
    );
  }

  await _runInheritedProcess(
    'sh',
    ['./configure', ..._lameConfigureArguments],
    workingDirectory: workingDirectory,
    environment: environment,
  );
  await _runInheritedProcess(
    'make',
    ['-j$jobs'],
    workingDirectory: workingDirectory,
    environment: environment,
  );
}

Future<bool> _canLinkLameWithTInfo(Map<String, String> environment) async {
  final compiler = environment['CC'] ?? Platform.environment['CC'] ?? 'cc';
  final tempDir = Directory.systemTemp.createTempSync(
    'anthem_lame_tinfo_check_',
  );

  try {
    final sourcePath = _joinFileSystemPath(tempDir.path, 'conftest.c');
    final outputPath = _joinFileSystemPath(tempDir.path, 'conftest');

    File(sourcePath).writeAsStringSync('''
int tgetent(char*, const char*);

int main(void) {
  return tgetent(0, "dumb");
}
''');

    final result = await Process.run(compiler, [
      ..._splitBuildFlags(
        environment['CFLAGS'] ?? Platform.environment['CFLAGS'],
      ),
      sourcePath,
      ..._splitBuildFlags(
        environment['LDFLAGS'] ?? Platform.environment['LDFLAGS'],
      ),
      '-ltinfo',
      '-o',
      outputPath,
    ], environment: environment.isEmpty ? null : environment);

    return result.exitCode == 0;
  } on ProcessException {
    return false;
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

String _appendBuildFlag(String? existingValue, String flag) {
  final trimmedValue = existingValue?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) return flag;

  final existingFlags = _splitBuildFlags(trimmedValue);
  if (existingFlags.contains(flag)) return trimmedValue;

  return '$trimmedValue $flag';
}

List<String> _splitBuildFlags(String? value) {
  final trimmedValue = value?.trim();
  if (trimmedValue == null || trimmedValue.isEmpty) return const [];

  return trimmedValue.split(RegExp(r'\s+'));
}

Future<void> _buildLameOnWindows(
  Uri sourceBuildPath, {
  required int jobs,
}) async {
  final msys2Bash = _requireMsys2BashExecutable();
  final msystem = _getMsys2System();
  final sourceBuildPathWindows = sourceBuildPath.toFilePath(windows: true);
  final configureCommand = [
    'sh',
    './configure',
    ..._lameConfigureArguments,
  ].map(_bashQuote).join(' ');

  final script =
      '''
set -euo pipefail
export MSYSTEM=${_bashQuote(msystem)}
mingw_prefix=${_bashQuote(_getMsys2MingwPrefix(msystem))}
export PATH="\$mingw_prefix/bin:/usr/bin:\$PATH"
cd "\$(cygpath -u ${_bashQuote(sourceBuildPathWindows)})"
export CC=clang
export CFLAGS="-O2"
export LDFLAGS="-static"
$configureCommand
make -j$jobs
''';

  await _runInheritedProcess(
    msys2Bash,
    ['-lc', script],
    environment: {'MSYSTEM': msystem, 'CHERE_INVOKING': '1'},
  );
}

String _requireMsys2BashExecutable() {
  final configuredBash = Platform.environment['ANTHEM_MSYS2_BASH'];
  if (configuredBash != null && configuredBash.isNotEmpty) {
    if (File(configuredBash).existsSync()) return configuredBash;

    print(
      Colorize(
        'Error: ANTHEM_MSYS2_BASH is set, but no file exists at $configuredBash.',
      ).red(),
    );
    exit(1);
  }

  const candidatePaths = [
    r'C:\msys64\usr\bin\bash.exe',
    r'C:\msys2\usr\bin\bash.exe',
  ];

  for (final candidatePath in candidatePaths) {
    if (File(candidatePath).existsSync()) return candidatePath;
  }

  print(
    Colorize(
      'Error: Could not find MSYS2 bash. Install MSYS2, or set ANTHEM_MSYS2_BASH to the bash.exe path.',
    ).red(),
  );
  exit(1);
}

String _getMsys2System() {
  final configuredSystem = Platform.environment['ANTHEM_MSYS2_SYSTEM'];
  if (configuredSystem != null && configuredSystem.isNotEmpty) {
    return configuredSystem;
  }

  return _getHostArchitectureName() == 'arm64' ? 'CLANGARM64' : 'CLANG64';
}

String _getMsys2MingwPrefix(String msystem) {
  return switch (msystem.toUpperCase()) {
    'CLANGARM64' => '/clangarm64',
    'CLANG64' => '/clang64',
    _ => throw UnsupportedError('Unsupported MSYS2 system: $msystem'),
  };
}

Uri _resolveBuiltLameBinaryLocation(Uri sourceBuildPath) {
  final candidatePaths = [
    sourceBuildPath.resolve('frontend/.libs/$_lameExecutableName'),
    sourceBuildPath.resolve('frontend/$_lameExecutableName'),
  ];

  for (final candidatePath in candidatePaths) {
    if (File.fromUri(candidatePath).existsSync()) {
      return candidatePath;
    }
  }

  final attemptedPaths = candidatePaths
      .map((path) => path.toFilePath(windows: Platform.isWindows))
      .join('\n - ');
  print(
    Colorize(
      'Error: Could not find built LAME binary. Tried:\n - $attemptedPaths',
    ).red(),
  );
  exit(1);
}

void _recreateBuildDirectory(Uri buildDirectoryPath) {
  final allowedRoot = Directory.fromUri(
    getPackageRootPath().resolve('build/lame/'),
  ).absolute.path;
  final buildDirectory = Directory.fromUri(buildDirectoryPath).absolute;

  if (!_isPathWithinDirectory(buildDirectory.path, allowedRoot)) {
    print(
      Colorize(
        'Error: Refusing to recreate unexpected build directory: ${buildDirectory.path}',
      ).red(),
    );
    exit(1);
  }

  if (buildDirectory.existsSync()) {
    buildDirectory.deleteSync(recursive: true);
  }

  buildDirectory.createSync(recursive: true);
}

bool _isPathWithinDirectory(String path, String directory) {
  var normalizedPath = Directory(path).absolute.path;
  var normalizedDirectory = Directory(directory).absolute.path;

  if (Platform.isWindows) {
    normalizedPath = normalizedPath.toLowerCase();
    normalizedDirectory = normalizedDirectory.toLowerCase();
  }

  final directoryWithSeparator =
      normalizedDirectory.endsWith(Platform.pathSeparator)
      ? normalizedDirectory
      : '$normalizedDirectory${Platform.pathSeparator}';

  return normalizedPath == normalizedDirectory ||
      normalizedPath.startsWith(directoryWithSeparator);
}

void _copyDirectorySync(Directory source, Directory destination) {
  destination.createSync(recursive: true);

  for (final entity in source.listSync(followLinks: false)) {
    final destinationPath = _joinFileSystemPath(
      destination.path,
      _fileSystemEntityName(entity),
    );

    if (entity is Directory) {
      _copyDirectorySync(entity, Directory(destinationPath));
    } else if (entity is File) {
      entity.copySync(destinationPath);
    }
  }
}

String _fileSystemEntityName(FileSystemEntity entity) {
  final normalizedPath = entity.path.replaceAll('\\', '/');
  final pathParts = normalizedPath.split('/').where((part) => part.isNotEmpty);
  return pathParts.last;
}

String _joinFileSystemPath(String directory, String name) {
  final separator = Platform.pathSeparator;
  if (directory.endsWith(separator)) return '$directory$name';
  return '$directory$separator$name';
}

Future<void> _makeExecutable(Uri filePath) async {
  if (Platform.isWindows) return;

  await _runInheritedProcess('chmod', [
    '755',
    filePath.toFilePath(windows: false),
  ]);
}

Future<void> _runInheritedProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment?.isEmpty ?? true ? null : environment,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print(Colorize('\n\nError: Command failed: $executable').red());
    exit(exitCode);
  }
}

String _getLamePlatformId() {
  return '${Platform.operatingSystem}-${_getHostArchitectureName()}';
}

String _getHostArchitectureName() {
  if (Platform.isWindows) {
    final architecture =
        Platform.environment['PROCESSOR_ARCHITECTURE']?.toLowerCase() ?? '';
    final architectureWow64 =
        Platform.environment['PROCESSOR_ARCHITEW6432']?.toLowerCase() ?? '';

    if (architecture.contains('arm64') || architectureWow64.contains('arm64')) {
      return 'arm64';
    }

    return 'x64';
  }

  final result = Process.runSync('uname', ['-m']);
  if (result.exitCode != 0) {
    return 'unknown';
  }

  final machine = (result.stdout as String).trim().toLowerCase();
  return switch (machine) {
    'x86_64' || 'amd64' => 'x64',
    'aarch64' || 'arm64' => 'arm64',
    _ => machine,
  };
}

String _bashQuote(String value) {
  return "'${value.replaceAll("'", r"'\''")}'";
}

String _toCmakePath(String path) {
  return path.replaceAll('\\', '/');
}

Uri _resolveExistingEngineBinaryLocation({
  required String buildDirectoryName,
  required bool debug,
}) {
  final candidatePaths = _getEngineBinaryLocationCandidates(
    buildDirectoryName: buildDirectoryName,
    debug: debug,
  );

  for (final candidatePath in candidatePaths) {
    if (File.fromUri(candidatePath).existsSync()) {
      return candidatePath;
    }
  }

  final attemptedPaths = candidatePaths
      .map((path) => path.toFilePath(windows: Platform.isWindows))
      .join('\n - ');
  print(
    Colorize(
      'Error: Could not find the built Anthem engine binary. Tried:\n - $attemptedPaths',
    ).red(),
  );
  exit(1);
}

List<Uri> _getEngineBinaryLocationCandidates({
  required String buildDirectoryName,
  required bool debug,
}) {
  final packageRootPath = getPackageRootPath();
  final binaryName = 'AnthemEngine${Platform.isWindows ? '.exe' : ''}';

  if (Platform.isWindows) {
    return [
      packageRootPath.resolve(
        'engine/$buildDirectoryName/AnthemEngine_artefacts${debug ? '/Debug' : '/Release'}/$binaryName',
      ),
      packageRootPath.resolve(
        'engine/$buildDirectoryName/${debug ? 'Debug' : 'Release'}/$binaryName',
      ),
    ];
  }

  return [
    packageRootPath.resolve('engine/$buildDirectoryName/$binaryName'),
    packageRootPath.resolve(
      'engine/$buildDirectoryName/AnthemEngine_artefacts/$binaryName',
    ),
    packageRootPath.resolve(
      'engine/$buildDirectoryName/AnthemEngine_artefacts${debug ? '/Debug' : '/Release'}/$binaryName',
    ),
  ];
}

Uri _getEngineTestBinaryLocation({
  required String buildDirectoryName,
  required bool debug,
  required bool useClang,
}) {
  final packageRootPath = getPackageRootPath();
  final binaryName = 'AnthemTest${Platform.isWindows ? '.exe' : ''}';

  if (Platform.isWindows && !useClang) {
    return packageRootPath.resolve(
      'engine/$buildDirectoryName/${debug ? 'Debug' : 'Release'}/$binaryName',
    );
  }

  return packageRootPath.resolve('engine/$buildDirectoryName/$binaryName');
}
