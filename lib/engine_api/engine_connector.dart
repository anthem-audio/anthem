/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

import 'package:anthem/engine_api/engine_socket_server.dart';
import 'package:flutter/foundation.dart';

import 'package:anthem/generated/messages_generated.dart';

/// Set this to override the path to the engine. Should be a full path.
///
/// This will allow you to stop the engine from Anthem, compile a new engine,
/// and start the new engine, all without re-building the Anthem UI.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? enginePathOverride = null;

final mainExecutablePath = File(Platform.resolvedExecutable);

/// Provides a way to communicate with the engine process.
///
/// The [EngineConnector] class manages an engine process. It uses a socket to
/// communicate with the process.
///
/// The [send] method can be used to send a Flatbuffers message to the engine. A
/// message can be sent like so:
///
/// ```dart
/// final engineConnectorID = getID();
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
/// final request = RequestObjectBuilder(
///   id: id,
///   commandType: CommandTypeId.AddArrangement,
///   command: AddArrangementObjectBuilder(),
/// );
///
/// engineConnector.send(request);
/// ```
class EngineConnector {
  var requestIdGen = 0;

  int getRequestId() {
    if (requestIdGen > 0x7FFFFFFFFFFFFFFE) {
      requestIdGen = 0;
    }
    return requestIdGen++;
  }

  /// This ID is sent to the engine as an argument on launch. The engine will
  /// send this ID back as the first message to the socket when it connects,
  /// which allows us to figure out which engine is associated with a given
  /// socket connection.
  final int _id;

  Process? _engineProcess;

  final void Function(Response reply)? _onReply;
  final void Function()? _onCrash;

  late final Future<bool> onInit;
  bool _initialized = false;

  /// If any requests are sent before the engine starts and IPC is set up, this
  /// list will hold the requests until the engine is initialized, at which
  /// point they will all be sent.
  final List<RequestObjectBuilder> _bufferedRequests = [];

  /// Timer that sends a heartbeat message to the engine every 5 seconds. If
  /// the engine doesn't receive one after 10 seconds, it will stop itself.
  Timer? _engineHeartbeatTimer;

  bool _heartbeatReceived = true;
  Timer? _heartbeatCheckTimer;

  /// Stream subscription for socket messages from the engine.
  StreamSubscription<Uint8List>? _engineReplySub;

  EngineConnector(this._id,
      {void Function(Response)? onReply, void Function()? onCrash})
      : _onCrash = onCrash,
        _onReply = onReply {
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

    if (kDebugMode) {
      print('Starting engine with ID: $_id');
    }

    EngineSocketServer.instance.onMessage(_id, (message) {
      _onReceive(message);
    });

    // Set up a completer to complete when the engine has connected.
    final engineConnectCompleter = Completer<void>();
    EngineSocketServer.instance.onConnect(
      _id,
      () => engineConnectCompleter.complete(),
    );

    final anthemPathStr = enginePathOverride ??
        (Platform.isWindows
            ? '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/AnthemEngine.exe'
            : '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/AnthemEngine');

    // If we're in debug mode, start with a command line window so we can see logging
    if (kDebugMode) {
      if (Platform.isWindows) {
        _engineProcess = await Process.start(
          'powershell',
          [
            '-Command',
            '& {Start-Process -FilePath "$anthemPathStr" -ArgumentList "${EngineSocketServer.instance.port} $_id" -Wait}'
          ],
        );
      } else if (Platform.isLinux) {
        // Can't figure out a good way to start in a shell window on Linux, so
        // this mirrors the engine output to our standard out.
        _engineProcess = await Process.start(
          anthemPathStr,
          [EngineSocketServer.instance.port.toString(), _id.toString()],
        );
        _engineProcess!.stdout.listen((msg) {
          for (final line in String.fromCharCodes(msg).split('\n')) {
            // ignore: avoid_print
            print('[Engine $_id] $line');
          }
        });
        _engineProcess!.stderr.listen((msg) {
          for (final line in String.fromCharCodes(msg).split('\n')) {
            // ignore: avoid_print
            print('[Engine $_id stderr] $line');
          }
        });
      }
    } else {
      _engineProcess = await Process.start(
        anthemPathStr,
        [EngineSocketServer.instance.port.toString(), _id.toString()],
      );
    }

    _heartbeatCheckTimer = Timer.periodic(
      // Maybe a bit long if this is our only way to tell if the engine died
      const Duration(seconds: 10),
      (_) {
        if (!_heartbeatReceived) {
          _onCrash?.call();
          _shutdown();
        }

        _heartbeatReceived = false;
      },
    );

    _engineHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        final id = getRequestId();
        final heartbeat = RequestObjectBuilder(
          id: id,
          commandType: CommandTypeId.Heartbeat,
          command: HeartbeatObjectBuilder(),
        );
        send(heartbeat);
      },
    );

    // Wait for the engine to connect before setting our initialized state to
    // true, since we can't send messages until the engine has actually
    // connected. _initialized is false while we wait, and this causes incoming
    // messages to be queued instead of attempting and failing to send them.
    await engineConnectCompleter.future;

    _initialized = true;

    return true;
  }

  /// Sends the given [Request] to the engine.
  Future<void> send(RequestObjectBuilder request) async {
    final bytes = request.toBytes();

    if (!_initialized) {
      _bufferedRequests.add(request);
      return;
    }

    // Send the length of the request
    final bytesList = Uint64List(1);
    bytesList[0] = bytes.length;
    EngineSocketServer.instance.send(_id, bytesList.buffer.asUint8List());

    // Send the request
    EngineSocketServer.instance.send(_id, bytes);
  }

  final List<int> _messageBuffer = [];

  void _onReceive(Uint8List message) {
    if (_onReply == null) return;

    // Append incoming data to the buffer
    _messageBuffer.addAll(message);

    // Process the buffer to extract complete messages
    while (_messageBuffer.length >= 8) {
      // Extract the message length (8 bytes, 64-bit integer)
      final byteData = ByteData.sublistView(Uint8List.fromList(_messageBuffer));
      final messageLength = byteData.getUint64(0, Endian.host);

      // Check if the buffer contains the full message
      if (_messageBuffer.length >= 8 + messageLength) {
        // Extract the full message
        final fullMessage =
            Uint8List.fromList(_messageBuffer.sublist(8, 8 + messageLength));
        final response = Response(fullMessage);

        // Handle heartbeat reply
        if (response.returnValueType == ReturnValueTypeId.HeartbeatReply) {
          _heartbeatReceived = true;
        } else {
          _onReply!(response);
        }

        // Remove the processed message from the buffer
        _messageBuffer.removeRange(0, 8 + messageLength);
      } else {
        // Not enough data for a full message yet
        break;
      }
    }
  }

  void _shutdown() {
    // Stop the heartbeat check timer
    _heartbeatCheckTimer?.cancel();

    // Kill engine process
    _engineProcess?.kill();

    // Stop the timer that sends heartbeat messages to the engine
    _engineHeartbeatTimer?.cancel();

    // Unsubscribe from engine replies
    _engineReplySub?.cancel();

    _heartbeatReceived = false;
  }

  /// Stops the engine process, and cleans up the messaging infrastructure.
  void dispose() {
    _shutdown();
  }
}
