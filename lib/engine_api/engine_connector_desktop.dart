/*
  Copyright (C) 2023 - 2025 Joshua Wade

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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/engine_socket_server.dart';

part 'engine_connector_desktop.debug_engine_path.g.dart';

final mainExecutablePath = File(Platform.resolvedExecutable);

/// Provides a way to communicate with the engine process.
///
/// The [EngineConnector] class manages an engine process. It uses a socket to
/// communicate with the process.
///
/// The [send] method can be used to send messages to the engine. A message can
/// be sent like so:
///
/// ```dart
/// final engineConnectorID = getId();
/// final engineConnector = EngineConnector(
///   engineConnectorID,
///   (Response response) {
///     // Handle reply here...
///   }
/// );
///
/// // ...
///
/// final id = engineConnector.getRequestId();
///
/// final request = Heartbeat(id: id);
///
/// final encoder = JsonUtf8Encoder();
/// final requestBytes = encoder.convert(request.toJson()) as Uint8List;
///
/// engineConnector.send(requestBytes);
/// ```
class EngineConnector extends EngineConnectorBase {
  /// This ID is sent to the engine as an argument on launch. The engine will
  /// send this ID back as the first message to the socket when it connects,
  /// which allows us to figure out which engine is associated with a given
  /// socket connection.
  final int _id;

  Process? _engineProcess;

  final void Function()? _onExit;

  bool _initialized = false;

  /// If any requests are sent before the engine starts and IPC is set up, this
  /// list will hold the requests until the engine is initialized, at which
  /// point they will all be sent.
  final List<Uint8List> _bufferedRequests = [];

  /// Stream subscription for socket messages from the engine.
  StreamSubscription<Uint8List>? _engineReplySub;

  /// Used for integration tests to specify the path to the engine binary.
  final String? enginePathOverride;

  EngineConnector(
    this._id, {
    required super.kDebugMode,
    super.onReply,
    void Function()? onExit,
    super.noHeartbeat = false,
    this.enginePathOverride,
  }) : _onExit = onExit {
    onInit = _init();

    // If any requests came in before the engine was started, send them now.
    onInit.then((success) {
      if (!success) return;
      for (final request in _bufferedRequests) {
        send(request);
      }
    });
  }

  /// Starts the engine process, sets up IPC, and starts the reply listener
  /// isolate.
  Future<bool> _init() async {
    // Wait for the socket server to start, since this is what the engines will
    // connect to. This will only cause a wait when the app is first launched.
    await EngineSocketServer.instance.init;

    EngineSocketServer.instance.onMessage(_id, (message) {
      onReceive(message);
    });

    // Set up a completer to complete when the engine has connected.
    final engineConnectCompleter = Completer<void>();
    EngineSocketServer.instance.onConnect(
      _id,
      () => engineConnectCompleter.complete(),
    );

    EngineSocketServer.instance.onClose(_id, _shutdown);

    String? developmentEnginePath;

    // If we're in debug mode, we look for the engine as compiled in the repo
    if (kDebugMode) {
      // debugEnginePath comes from a generated file
      developmentEnginePath = debugEnginePath;
    }

    final anthemPathStr =
        enginePathOverride ??
        developmentEnginePath ??
        mainExecutablePath.parent.uri
            .resolve(
              './data/flutter_assets/assets/engine/AnthemEngine${Platform.isWindows ? '.exe' : ''}',
            )
            .toFilePath(windows: Platform.isWindows);

    if (!await File(anthemPathStr).exists()) {
      return false;
    }

    // If we're in debug mode, start with a command line window so we can see logging
    if (kDebugMode) {
      if (Platform.isWindows) {
        _setEngineProcess(
          await Process.start('powershell', [
            '-Command',
            '& {Start-Process -FilePath "$anthemPathStr" -ArgumentList "${EngineSocketServer.instance.port} $_id" -Wait}',
          ]),
        );
      } else {
        _setEngineProcess(
          await Process.start(
            anthemPathStr,
            [EngineSocketServer.instance.port.toString(), _id.toString()],
            // There's no singular way to start in a shell window on Linux, so
            // this mirrors the engine output to our standard out.
            mode: ProcessStartMode.inheritStdio,
          ),
        );
      }
    } else {
      _setEngineProcess(
        await Process.start(
          anthemPathStr,
          [EngineSocketServer.instance.port.toString(), _id.toString()],

          // I'm not sure why this is necessary, but the process doesn't start
          // correctly without it on Windows without this.
          mode: Platform.isWindows
              ? ProcessStartMode.inheritStdio
              : ProcessStartMode.normal,
        ),
      );
    }

    if (!noHeartbeat) {
      startHeartbeatTimer();
    }

    // Wait for the engine to connect before setting our initialized state to
    // true, since we can't send messages until the engine has actually
    // connected. _initialized is false while we wait, and this causes incoming
    // messages to be queued instead of attempting and failing to send them.
    await engineConnectCompleter.future;

    _initialized = true;

    return true;
  }

  /// Sends the given bytes to the engine.
  @override
  void send(Uint8List bytes) {
    if (!_initialized) {
      _bufferedRequests.add(bytes);
      return;
    }

    // Send the length of the request
    final bytesList = Uint64List(1);
    bytesList[0] = bytes.length;
    EngineSocketServer.instance.send(_id, bytesList.buffer.asUint8List());

    // Send the request
    EngineSocketServer.instance.send(_id, bytes);
  }

  void _shutdown() {
    // Kill engine process
    _engineProcess?.kill();

    // Unsubscribe from engine replies
    _engineReplySub?.cancel();
  }

  /// Stops the engine process, and cleans up the messaging infrastructure.
  @override
  void dispose() {
    _shutdown();
    super.dispose();
  }

  /// Sets the engine process, and attaches a listener when it stops.
  void _setEngineProcess(Process process) {
    _engineProcess = process;

    _engineProcess!.exitCode.then((exitCode) {
      _onExit?.call();
    });
  }
}
