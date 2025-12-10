/*
  Copyright (C) 2025 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

// cspell:ignore dhttpd

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';
import 'package:shelf_static/shelf_static.dart';

/// Enables serving `flutter run` or an existing build/web directory behind a
/// proxy that adds the necessary COOP/COEP headers.
///
/// As of Flutter 3.38, this is not necessary for development as the headers can
/// be added by a new web_dev_config.yaml in the project root. However, it is
/// still needed when serving an existing build/web directory.
class FlutterRunWebWithProxyCommand extends Command<dynamic> {
  FlutterRunWebWithProxyCommand() {
    argParser.addFlag(
      'serve-existing-build',
      help:
          'Serve (packageRoot)/build/web with dhttpd behind the proxy instead of running "flutter run".',
      negatable: false,
    );

    argParser.addFlag(
      'no-wasm',
      help: 'Run flutter web without --wasm, which will build with dart2js.',
      negatable: false,
    );
  }

  @override
  String get description =>
      'Runs "flutter run -d web-server --wasm" behind a proxy for COOP/COEP, which allows the engine to run without errors.';

  @override
  String get name => 'flutter_run_web_with_proxy';

  @override
  Future<void> run() async {
    // Always ensure dhttpd is available.
    await _ensureDhttpdActivated();

    final devServerPort = await getUnusedPort();
    final proxyPort = await getUnusedPort();

    // Parse flags early so we can decide how to wire the proxy.
    final useExistingBuild =
        (argResults?['serve-existing-build'] as bool?) ?? false;
    final noWasm = (argResults?['no-wasm'] as bool?) ?? false;

    // Resolve package root (used for static mounts and/or build/web).
    final packageRoot = await _findPackageRoot(Directory.current);

    print(
      '${Colorize('The proxy server will be started at').lightGreen()} http://localhost:$proxyPort',
    );
    print(
      Colorize(
        'Copy this link if needed, then press enter to continue...',
      ).lightGreen(),
    );
    stdin.readLineSync();

    // When serving the dev server (useExistingBuild == false), also mount /src and /include.
    await startProxyServer(
      proxyPort: proxyPort,
      devServerPort: devServerPort,
      packageRoot: packageRoot,
      mountEngineDirs: !useExistingBuild,
    );

    if (useExistingBuild) {
      if (noWasm) {
        print(
          Colorize(
            'Warning: --no-wasm has no effect when serving an existing build.',
          ).yellow(),
        );
      }

      // Validate build/web.
      final buildWebDir = Directory(
        '${packageRoot.path}${Platform.pathSeparator}build${Platform.pathSeparator}web',
      );

      if (!buildWebDir.existsSync()) {
        stderr.writeln(
          'Error: Expected directory not found: ${buildWebDir.path}\n'
          'Build your web app first (e.g., "flutter build web"), or omit --serve-existing-build.',
        );
        exitCode = 2;
        return;
      }

      final dhttpdProc = await _startDhttpd(devServerPort, buildWebDir);

      print(
        'Proxy: http://localhost:$proxyPort  →  dhttpd (static build): http://localhost:$devServerPort',
      );

      // Pipe dhttpd output to console.
      dhttpdProc.stdout.listen(stdout.add);
      dhttpdProc.stderr.listen(stderr.add);

      final code = await dhttpdProc.exitCode;
      exit(code);
    } else {
      final flutterProc = await startDevelopmentServer(devServerPort, noWasm);

      print(
        'Proxy: http://localhost:$proxyPort  →  Flutter dev server: http://localhost:$devServerPort',
      );
      print('Mounted static paths:');
      print(
        '  /src     → ${packageRoot.path}${Platform.pathSeparator}engine${Platform.pathSeparator}src',
      );
      print(
        '  /include → ${packageRoot.path}${Platform.pathSeparator}engine${Platform.pathSeparator}include',
      );

      // Pipe Flutter output to console.
      flutterProc.stdout.listen(stdout.add);
      flutterProc.stderr.listen(stderr.add);

      // Exit when Flutter exits.
      final code = await flutterProc.exitCode;
      exit(code);
    }
  }

  Future<int> getUnusedPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<Process> startDevelopmentServer(int port, bool noWasm) async {
    // Use --web-port (HTTP server) rather than --dds-port (VM service).
    final args = [
      'run',
      '-d',
      'web-server',
      if (!noWasm) '--wasm',
      '--web-port',
      port.toString(),
      '--web-hostname',
      'localhost',
    ];
    print('Starting: flutter ${args.join(' ')}');
    return await Process.start('flutter', args, runInShell: true);
  }

  Future<void> startProxyServer({
    required int proxyPort,
    required int devServerPort,
    required Directory packageRoot,
    required bool mountEngineDirs,
  }) async {
    final target = 'http://localhost:$devServerPort';
    final httpProxy = proxyHandler(target);

    // Optional static mounts (only when running the dev server).
    final mounts = <Handler>[];
    if (mountEngineDirs) {
      final srcDir = Directory(
        '${packageRoot.path}${Platform.pathSeparator}engine${Platform.pathSeparator}src',
      );
      final includeDir = Directory(
        '${packageRoot.path}${Platform.pathSeparator}engine${Platform.pathSeparator}include',
      );

      if (srcDir.existsSync()) {
        mounts.add(_staticMount('/src', srcDir));
      }
      if (includeDir.existsSync()) {
        mounts.add(_staticMount('/include', includeDir));
      }
    }

    // Inject COOP/COEP/CORP on every response.
    final coopCoep = createMiddleware(
      responseHandler: (Response res) {
        return res.change(
          headers: {
            ...res.headers,
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
            'Cross-Origin-Resource-Policy': 'same-origin',
          },
        );
      },
    );

    // Disable caching during dev
    final noCache = createMiddleware(
      responseHandler: (Response res) {
        return res.change(
          headers: {...res.headers, 'Cache-Control': 'no-store'},
        );
      },
    );

    // Build a cascade: static mounts first, then the reverse proxy.
    var cascade = Cascade();
    for (final h in mounts) {
      cascade = cascade.add(h);
    }
    cascade = cascade.add(httpProxy);
    final composed = cascade.handler;

    // Compose middlewares around the pipeline.
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(coopCoep)
        .addMiddleware(noCache)
        .addHandler(composed);

    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      proxyPort,
    );

    print(
      'Reverse proxy listening at http://${server.address.host}:${server.port}',
    );
  }

  /// Mounts [dir] at [urlPrefix] (e.g., "/src" or "/include"). If the request
  /// path is exactly the prefix or starts with "(prefix)/", the prefix is
  /// *consumed* via `req.change(path: (prefix))` and the request is delegated
  /// to the static handler with the remaining subpath.
  Handler _staticMount(String urlPrefix, Directory dir) {
    // Normalize to a bare segment without leading/trailing slashes: e.g. "src"
    final mounted = urlPrefix.replaceAll(RegExp(r'^/+|/+$'), '');

    final staticHandler = createStaticHandler(
      dir.path,
      listDirectories: true,
      defaultDocument: null,
      useHeaderBytesForContentType: true,
    );

    return (Request req) {
      final path = req.url.path; // e.g. "src/main.cpp" or "include/foo/bar.h"

      if (path == mounted || path.startsWith('$mounted/')) {
        // Consume the mount prefix. After this, forwarded.url.path is the
        // remainder (e.g. "main.cpp"), and handlerPath is advanced to "/src/".
        final forwarded = req.change(path: mounted);
        return staticHandler(forwarded);
      }

      // Not our prefix; let Cascade try the next handler.
      return Response.notFound('Not Found');
    };
  }

  Future<void> _ensureDhttpdActivated() async {
    // Always activate to ensure it's installed/up-to-date.
    final result = await Process.run('dart', [
      'pub',
      'global',
      'activate',
      'dhttpd',
    ], runInShell: true);
    // Forward output for visibility.
    if ((result.stdout as Object?) != null &&
        result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout);
    }
    if ((result.stderr as Object?) != null &&
        result.stderr.toString().isNotEmpty) {
      stderr.write(result.stderr);
    }
    if (result.exitCode != 0) {
      stderr.writeln(
        'Failed to activate dhttpd (exit code ${result.exitCode}).',
      );
      exit(result.exitCode);
    }
  }

  Future<Process> _startDhttpd(int port, Directory root) async {
    final args = [
      'pub',
      'global',
      'run',
      'dhttpd',
      '--host',
      'localhost',
      '--port',
      port.toString(),
      '--path',
      root.path,
    ];
    print('Starting: dart ${args.join(' ')}');
    return await Process.start('dart', args, runInShell: true);
  }

  Future<Directory> _findPackageRoot(Directory start) async {
    Directory current = start.absolute;
    while (true) {
      final pubspec = File(
        '${current.path}${Platform.pathSeparator}pubspec.yaml',
      );
      if (pubspec.existsSync()) {
        return current;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        // Reached filesystem root; default to starting directory.
        return start.absolute;
      }
      current = parent;
    }
  }
}
