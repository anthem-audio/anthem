// Copyright (C) 2026 Joshua Wade
// SPDX-License-Identifier: GPL-3.0-or-later

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import '../cli_helpers.dart';

class EngineRuntimeTestCommand extends Command<void> {
  @override
  String get name => 'runtime-test';
  @override
  String get description => 'Tests the Rust runtime through real Dart IPC.';

  EngineRuntimeTestCommand() {
    argParser
      ..addFlag(
        'wasm',
        negatable: false,
        help: 'Run in Chrome with the threaded WASM engine.',
      )
      ..addFlag(
        'release',
        negatable: false,
        help: 'Use the release engine build.',
      )
      ..addFlag(
        'skip-build',
        negatable: false,
        help: 'Reuse the existing engine build.',
      )
      ..addOption(
        'compiler',
        allowed: ['js', 'wasm', 'both'],
        defaultsTo: 'both',
        help: 'Dart compiler for browser scenarios.',
      );
  }

  @override
  Future<void> run() async {
    final root = getPackageRootPath().toFilePath();
    final wasm = argResults!['wasm'] as bool;
    final release = argResults!['release'] as bool;
    if (!(argResults!['skip-build'] as bool)) {
      await _run(Platform.resolvedExecutable, [
        'run',
        'anthem:cli',
        'engine',
        'build',
        '--backend',
        'rust',
        release ? '--release' : '--debug',
        if (wasm) '--wasm',
      ], root);
    }
    if (!wasm) {
      final engine = path.join(
        root,
        'engine-rust',
        'target',
        release ? 'release' : 'debug',
        'anthem-engine${Platform.isWindows ? '.exe' : ''}',
      );
      await _run(
        'flutter',
        ['test', '--no-pub', 'test/engine_runtime/native.dart'],
        root,
        environment: {'ANTHEM_RUST_ENGINE': engine},
      );
      return;
    }
    final compiler = argResults!['compiler'] as String;
    for (final target in [
      if (compiler != 'wasm') 'js',
      if (compiler != 'js') 'wasm',
    ]) {
      final output = path.join(root, 'build', 'engine-runtime-tests', target);
      await _run('flutter', [
        'build',
        'web',
        '--no-pub',
        if (target == 'wasm') '--wasm',
        '--no-web-resources-cdn',
        '--target',
        'test/engine_runtime/browser.dart',
        '--output',
        output,
      ], root);
      await runBrowserRuntimeTests(output, target: target);
    }
  }
}

Future<void> _run(
  String executable,
  List<String> arguments,
  String root, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: root,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows && executable == 'flutter',
  );
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(executable, arguments, 'Command failed', code);
  }
}

/// Hosts the normal Flutter web build with the isolation headers required for
/// shared memory. The Dart scenario reports its result over this same origin.
Future<void> runBrowserRuntimeTests(
  String directory, {
  required String target,
}) async {
  final result = Completer<Map<String, dynamic>>();
  final files = createStaticHandler(directory, defaultDocument: 'index.html');
  final server = await shelf_io.serve(
    (shelf.Request request) async {
      final shelf.Response response;
      if (request.url.path == '__result' && request.method == 'POST') {
        final value =
            jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        if (!result.isCompleted) result.complete(value);
        response = shelf.Response.ok('received');
      } else {
        response = await files(request);
      }
      return response.change(
        headers: {
          'Cross-Origin-Opener-Policy': 'same-origin',
          'Cross-Origin-Embedder-Policy': 'require-corp',
          'Cache-Control': 'no-store',
        },
      );
    },
    InternetAddress.loopbackIPv4,
    0,
  );
  final profile = await Directory(directory).createTemp('chrome-profile-');
  Process? browser;
  final log = StringBuffer();
  try {
    browser = await Process.start(_chrome(), [
      '--headless',
      '--enable-logging=stderr',
      '--disable-dev-shm-usage',
      '--no-first-run',
      '--no-default-browser-check',
      '--user-data-dir=${profile.absolute.path}',
      'http://127.0.0.1:${server.port}/',
    ]);
    browser.stdout.transform(utf8.decoder).listen(log.write);
    browser.stderr.transform(utf8.decoder).listen(log.write);
    unawaited(
      browser.exitCode.then((code) {
        if (!result.isCompleted) {
          result.completeError(
            StateError('Chrome exited with $code before reporting a result.'),
          );
        }
      }),
    );
    final value = await result.future.timeout(const Duration(minutes: 3));
    await File(
      path.join(directory, 'result.json'),
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(value)}\n');
    if (value['success'] != true) {
      throw StateError('${value['error']}\n${value['stack']}');
    }
    print('Dart ($target) ↔ Rust WASM runtime scenarios passed.');
  } catch (_) {
    final lines = const LineSplitter().convert(log.toString());
    print(lines.take(25).join('\n'));
    if (lines.length > 25) {
      print('Full browser output: ${path.join(directory, 'chrome.log')}');
    }
    rethrow;
  } finally {
    browser?.kill();
    if (browser != null) await browser.exitCode;
    await server.close(force: true);
    await File(path.join(directory, 'chrome.log'))
        .writeAsString(log.toString());
    // createTemp places this profile directly under the selected build output.
    final absoluteProfile = path.normalize(profile.absolute.path);
    if (path.isWithin(
      path.normalize(Directory(directory).absolute.path),
      absoluteProfile,
    )) {
      try {
        await profile.delete(recursive: true);
      } on FileSystemException {
        /* Chrome may still be releasing files on Windows. */
      }
    }
  }
}

String _chrome() {
  final configured = Platform.environment['CHROME_EXECUTABLE'];
  if (configured != null) return configured;
  final candidates = Platform.isWindows
      ? [
          r'C:\Program Files\Google\Chrome\Application\chrome.exe',
          r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        ]
      : Platform.isMacOS
      ? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome']
      : [
          '/usr/bin/google-chrome',
          '/usr/bin/chromium',
          '/usr/bin/chromium-browser',
        ];
  return candidates.firstWhere(
    (candidate) => File(candidate).existsSync(),
    orElse: () => throw StateError(
      'Set CHROME_EXECUTABLE to run browser integration tests.',
    ),
  );
}
