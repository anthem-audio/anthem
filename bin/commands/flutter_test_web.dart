/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Runs only the browser suites selected by browser_test_suites.yaml.
Future<void> runFlutterWebTests({
  required Uri packageRootPath,
  required String compiler,
  required bool widgets,
  required String reporter,
  required bool list,
  required void Function(String) usageException,
}) async {
  final root = path.normalize(packageRootPath.toFilePath());
  final manifestFile = File(path.join(root, 'test/browser_test_suites.yaml'));
  final manifest = loadYaml(await manifestFile.readAsString()) as YamlMap;

  List<String> paths(String key) {
    final entries = (manifest[key] as YamlList).cast<String>().toList();
    for (final entry in entries) {
      final resolved = path.normalize(path.join(root, entry));
      if (!path.isWithin(root, resolved) ||
          FileSystemEntity.typeSync(resolved) ==
              FileSystemEntityType.notFound) {
        usageException('Invalid $key test path: $entry');
      }
    }
    return entries;
  }

  final dartTests = paths('dart')..sort();
  final excluded = paths('exclude').toSet();
  final flutterTests = <String>[];
  final flutterPackages = <String, List<String>>{};
  for (final directory in paths('flutter')) {
    var package = Directory(path.join(root, directory));
    while (!File(path.join(package.path, 'pubspec.yaml')).existsSync()) {
      if (package.path == package.parent.path) {
        usageException('No Flutter package found for $directory.');
      }
      package = package.parent;
    }
    await for (final entity in Directory(
      path.join(root, directory),
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      final relative = path
          .relative(entity.path, from: root)
          .replaceAll('\\', '/');
      if (!dartTests.contains(relative) && !excluded.contains(relative)) {
        flutterTests.add(relative);
        (flutterPackages[package.path] ??= []).add(
          path.relative(entity.path, from: package.path).replaceAll('\\', '/'),
        );
      }
    }
  }
  flutterTests.sort();

  if (list) {
    print('Standalone Dart tests ($compiler):');
    dartTests.forEach(print);
    if (widgets) {
      print('\nFlutter tests (JavaScript):');
      flutterTests.forEach(print);
    }
    return;
  }
  if (widgets && Platform.isWindows) {
    usageException(
      'Flutter\'s Chrome test runner has Windows URL path bugs. '
      'Run flutter_test --web without --widgets on Windows; '
      'run the full suite on Linux/macOS or CI. '
      'See docs/testing.md.',
    );
  }
  if (dartTests.isEmpty || (widgets && flutterTests.isEmpty)) {
    usageException('The browser test selection is empty.');
  }

  await Directory(
    path.join(root, '.dart_tool/web-tests'),
  ).create(recursive: true);
  final dartExecutable = path.join(
    path.dirname(Platform.resolvedExecutable),
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
  await _runTests(dartExecutable, [
    'test',
    '--platform',
    'chrome',
    '--compiler',
    compiler == 'both' ? 'dart2js,dart2wasm' : compiler,
    '--timeout',
    '60s',
    '--reporter',
    reporter,
    '--file-reporter',
    'json:.dart_tool/web-tests/dart-results.json',
    ...dartTests,
  ], root);

  if (widgets) {
    // Flutter's browser compiler serves files from one package's test
    // directory. Run workspace packages separately so their tests resolve.
    for (final entry in flutterPackages.entries) {
      final packageName = entry.key == root
          ? 'root'
          : path.relative(entry.key, from: root).replaceAll('\\', '/');
      final resultFile = path.join(
        root,
        '.dart_tool/web-tests/flutter-$packageName-results.json',
      );
      await _runTests('flutter', [
        'test',
        '--platform',
        'chrome',
        '--timeout',
        '60s',
        '--reporter',
        reporter,
        '--file-reporter',
        'json:$resultFile',
        ...entry.value..sort(),
      ], entry.key);
    }
  }
}

Future<void> _runTests(
  String executable,
  List<String> arguments,
  String root,
) async {
  print('Running $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: root,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) exit(result);
}
