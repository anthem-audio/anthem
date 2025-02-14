/*
  Copyright (C) 2024 Joshua Wade

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

/// Manages TCP connections to engine processes.
///
/// When an engine is started, it will be given a port and an ID as arguments.
/// The engine will connect to the port on localhost, and its first message will
/// include the ID it was given. This allows the server to associate the socket
/// with its ID, and that socket object can then be accessed via [onMessage].
class EngineSocketServer {
  static final _instance = EngineSocketServer._internal();
  static EngineSocketServer get instance => _instance;

  late final ServerSocket _server;
  final _initCompleter = Completer<void>();
  Future<void> get init => _initCompleter.future;

  /// The port of this server.
  int get port => _server.port;

  /// Map of engine ID to associated socket.
  final _engineConnections = <int, Socket>{};

  /// Map of engine ID to associated socket listener subscription.
  final _engineConnectionSubs = <int, StreamSubscription<Uint8List>>{};

  /// Map of engine ID to associated message handler.
  final _engineSocketMessageHandlers = <int, void Function(Uint8List)>{};

  /// Map of engine ID to associated message handler.
  final _engineSocketConnectHandlers = <int, void Function()>{};

  /// Map of engine ID to associated error handler.
  final _engineSocketErrorHandlers = <int, void Function()>{};

  /// Map of engine ID to associated close handler.
  final _engineSocketCloseHandlers = <int, void Function()>{};

  EngineSocketServer._internal() {
    // Create a new server.
    ServerSocket.bind(InternetAddress.loopbackIPv6, 0).then((server) {
      // Once the server is created, notify any listeners that the server is
      // ready.
      _server = server;
      _initCompleter.complete();

      // Add listener for new connections.
      _server.listen((socket) {
        late int engineId;

        late StreamSubscription<Uint8List> sub;

        final id = Uint8List(8);
        var writePtr = 0;
        bool idFound = false;

        sub = socket.listen(
          (message) {
            if (!idFound) {
              final writePtrStart = writePtr;

              var messagePtr = 0;
              while (writePtr < 8 && messagePtr < message.length) {
                id[writePtr] = message[messagePtr];
                writePtr++;
                messagePtr++;
              }

              // If the first message didn't contain the full 8-byte id, wait for
              // the next message.
              if (writePtr < 8) return;

              idFound = true;

              // Get the ID of the engine from the first message of each socket, and
              // use it to assign the socket to our map of server connections.
              final byteData = ByteData.sublistView(id);
              engineId = byteData.getUint64(0, Endian.host);
              _engineConnectionSubs[engineId] = sub;
              _engineConnections[engineId] = socket;

              // If a connection listener has been registered, notify it.
              if (_engineSocketConnectHandlers.containsKey(engineId)) {
                _engineSocketConnectHandlers[engineId]!.call();
                _engineSocketConnectHandlers.remove(engineId);
              }

              // When the socket is closed, remove the socket from our map.
              socket.done
                  .then((_) {
                    cleanUpEngine(engineId);
                  })
                  .catchError((_) {
                    cleanUpEngine(engineId);
                  });

              // If there is any extra data in the first message, capture it and
              // send it to the handler.
              if (message.length > writePtr - writePtrStart) {
                message.sublist(writePtr - writePtrStart);
                _engineSocketMessageHandlers[engineId]?.call(message);
              }
            } else {
              _engineSocketMessageHandlers[engineId]?.call(message);
            }
          },
          onError: (dynamic error) {
            if (_engineSocketErrorHandlers.containsKey(engineId)) {
              _engineSocketErrorHandlers[engineId]!.call();
            }
          },
          onDone: () {
            if (_engineSocketCloseHandlers.containsKey(engineId)) {
              _engineSocketCloseHandlers[engineId]!.call();
            }
          },
          cancelOnError: true,
        );
      });
    });
  }

  /// Gets the socket with the given ID.
  void onMessage(int engineId, void Function(Uint8List) handler) {
    _engineSocketMessageHandlers[engineId] = handler;
  }

  /// Runs the given function once the engine with the given ID connects to the
  /// server. If the engine is already connected, calls the handler immediately.
  void onConnect(int engineId, void Function() handler) {
    if (_engineSocketConnectHandlers.containsKey(engineId)) {
      handler();
    }

    _engineSocketConnectHandlers[engineId] = handler;
  }

  /// Runs the given function if the engine with the given ID encounters an error.
  void onError(int engineId, void Function() handler) {
    _engineSocketErrorHandlers[engineId] = handler;
  }

  /// Runs the given function if the engine with the given ID closes its socket.
  void onClose(int engineId, void Function() handler) {
    _engineSocketCloseHandlers[engineId] = handler;
  }

  /// Sends the message to the given engine's socket
  void send(int engineId, Uint8List data) {
    _engineConnections[engineId]?.add(data);
  }

  /// Cleans up the given engine's connection
  void cleanUpEngine(int engineId) {
    _engineConnections[engineId]?.close();
    _engineConnections.remove(engineId);

    _engineConnectionSubs[engineId]?.cancel();
    _engineConnectionSubs.remove(engineId);

    _engineSocketMessageHandlers.remove(engineId);
    _engineSocketConnectHandlers.remove(engineId);
    _engineSocketErrorHandlers.remove(engineId);
    _engineSocketCloseHandlers.remove(engineId);
  }
}
