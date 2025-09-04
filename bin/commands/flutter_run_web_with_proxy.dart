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

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

class FlutterRunWebWithProxyCommand extends Command<dynamic> {
  @override
  String get description =>
      'Runs "flutter run -d web-server --wasm" behind a proxy for COOP/COEP, which allows the engine to run without errors.';

  @override
  String get name => 'flutter_run_web_with_proxy';

  @override
  Future<void> run() async {
    final devServerPort = await getUnusedPort();
    final proxyPort = await getUnusedPort();

    print(
      '${Colorize('The proxy server will be started at').lightGreen()} http://localhost:$proxyPort',
    );
    print(
      Colorize(
        'Copy this link if needed, then press enter to continue...',
      ).lightGreen(),
    );
    stdin.readLineSync();

    await startProxyServer(proxyPort, devServerPort);

    final flutterProc = await startDevelopmentServer(devServerPort);

    print(
      'Proxy: http://localhost:$proxyPort  →  Flutter dev server: http://localhost:$devServerPort',
    );

    // Pipe Flutter output to our console.
    flutterProc.stdout.listen(stdout.add);
    flutterProc.stderr.listen(stderr.add);

    // Exit when Flutter exits.
    final code = await flutterProc.exitCode;
    exit(code);
  }

  Future<int> getUnusedPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<Process> startDevelopmentServer(int port) async {
    // Use --web-port (HTTP server) rather than --dds-port (VM service).
    final args = [
      'run',
      '-d',
      'web-server',
      '--wasm',
      '--web-port',
      port.toString(),
      '--web-hostname',
      'localhost',
    ];
    print('Starting: flutter ${args.join(' ')}');
    return await Process.start('flutter', args, runInShell: true);
  }

  Future<void> startProxyServer(int proxyPort, int devServerPort) async {
    final target = 'http://localhost:$devServerPort';
    final httpProxy = proxyHandler(target);

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

    // Compose middlewares around the HTTP proxy handler.
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(coopCoep)
        .addMiddleware(noCache)
        .addHandler(httpProxy);

    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      proxyPort,
    );

    print(
      'Reverse proxy listening at http://${server.address.host}:${server.port}',
    );
  }
}
