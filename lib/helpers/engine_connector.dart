/*
  Copyright (C) 2023 Joshua Wade

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
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

typedef ConnectFuncNative = Void Function();
typedef ConnectFuncDart = void Function();

typedef CleanupPreviousMessageQueuesFuncNative = Void Function();
typedef CleanupPreviousMessageQueuesFuncDart = void Function();

typedef GetMessageSendBufferFuncNative = Pointer<Uint8> Function();
typedef GetMessageSendBufferFuncDart = Pointer<Uint8> Function();

typedef GetMessageReceiveBufferFuncNative = Pointer<Uint8> Function();
typedef GetMessageReceiveBufferFuncDart = Pointer<Uint8> Function();

typedef SendFromBufferFuncNative = Void Function(Int64 size);
typedef SendFromBufferFuncDart = void Function(int size);

typedef GetLastReceivedMessageSizeFuncNative = Int64 Function();
typedef GetLastReceivedMessageSizeFuncDart = int Function();

typedef ReceiveFuncNative = Bool Function();
typedef ReceiveFuncDart = bool Function();

typedef TryReceiveFuncNative = Bool Function();
typedef TryReceiveFuncDart = bool Function();

class EngineConnector {
  DynamicLibrary engineConnectorLib;

  late ConnectFuncDart _connect;
  late CleanupPreviousMessageQueuesFuncDart _cleanupPreviousMessageQueues;
  late GetMessageSendBufferFuncDart _getMessageSendBuffer;
  late GetMessageReceiveBufferFuncDart _getMessageReceiveBuffer;
  late GetLastReceivedMessageSizeFuncDart _getLastReceivedMessageSize;
  late SendFromBufferFuncDart _sendFromBuffer;

  // Buffer for writing messages
  late Pointer<Uint8> _messageSendBuffer;
  late Pointer<Uint8> _messageReceiveBuffer;

  late Isolate receiveIsolate;
  late ReceivePort mainToIsolateReceivePort;

  late Process engineProcess;

  Function(Uint8List reply)? onReply;

  late Future<void> onInit;
  bool _initialized = false;

  final List<Uint8List> _bufferedRequests = [];

  EngineConnector(this.engineConnectorLib, [this.onReply]) {
    _cleanupPreviousMessageQueues = engineConnectorLib.lookupFunction<
        CleanupPreviousMessageQueuesFuncNative,
        CleanupPreviousMessageQueuesFuncDart>('cleanupPreviousMessageQueues');
    _connect = engineConnectorLib
        .lookupFunction<ConnectFuncNative, ConnectFuncDart>('connect');
    _getMessageSendBuffer = engineConnectorLib.lookupFunction<
        GetMessageSendBufferFuncNative,
        GetMessageSendBufferFuncDart>('getMessageSendBuffer');
    _getMessageReceiveBuffer = engineConnectorLib.lookupFunction<
        GetMessageReceiveBufferFuncNative,
        GetMessageReceiveBufferFuncDart>('getMessageReceiveBuffer');
    _getLastReceivedMessageSize = engineConnectorLib.lookupFunction<
        GetLastReceivedMessageSizeFuncNative,
        GetLastReceivedMessageSizeFuncDart>('getLastReceivedMessageSize');
    _sendFromBuffer = engineConnectorLib.lookupFunction<
        SendFromBufferFuncNative, SendFromBufferFuncDart>('sendFromBuffer');

    onInit = _init();

    // If any requests came in before the engine was started, send them now.
    onInit.then((value) {
      for (final request in _bufferedRequests) {
        send(request);
      }
    });
  }

  Future<void> _init() async {
    // We have to clean up any possibly-not-cleaned-up message queues first, or
    // the engine process will crash.
    _cleanupPreviousMessageQueues();

    // We start the engine process before trying to connect. The connect
    // function blocks when trying to open the engine's message queue, so the
    // engine's message queue must already exist before we try to connect.
    final mainExecutablePath = File(Platform.resolvedExecutable);
    engineProcess = await Process.start(
      '${mainExecutablePath.parent.path}/data/flutter_assets/assets/Engine.exe',
      [],
    );

    // Now that the engine has created its message queue and is waiting for
    // ours, we will create our message queue and open the engine's message
    // queue.
    _connect();

    _messageSendBuffer = _getMessageSendBuffer();
    _messageReceiveBuffer = _getMessageReceiveBuffer();

    mainToIsolateReceivePort = ReceivePort();

    // Spawn an isolate to listen for replies from the engine
    Isolate.spawn(
      responseReceiverIsolate,
      mainToIsolateReceivePort.sendPort,
    ).then(
      (isolate) {
        receiveIsolate = isolate;
      },
    );

    mainToIsolateReceivePort.listen((_) {
      getReplyFromEngine();
    });

    _initialized = true;
  }

  void send(Uint8List request) {
    if (!_initialized) {
      _bufferedRequests.add(request);
      return;
    }

    final size = request.length;

    if (size > 65536) {
      throw Exception(
          'Flatbuffers message was too large. We should dynamically reallocate here instead of throwing. This is a bug.');
    }

    // Copy message to buffer
    for (var i = 0; i < size; i++) {
      _messageSendBuffer.elementAt(i).value = request.elementAt(i);
    }

    // Send the message
    _sendFromBuffer(size);
  }

  void getReplyFromEngine() {
    if (onReply == null) return;

    final size = _getLastReceivedMessageSize();

    final buffer = Uint8List(size);

    // Copy message from receive buffer
    for (var i = 0; i < size; i++) {
      buffer[i] = _messageReceiveBuffer.elementAt(i).value;
    }

    onReply!(buffer);
  }

  void dispose() {
    engineProcess.kill();
  }
}

void responseReceiverIsolate(SendPort sendPort) {
  const path = './data/flutter_assets/assets/EngineConnector.dll';
  final engineConnectorLib = DynamicLibrary.open(path);

  final receive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('receive');
  final tryReceive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('tryReceive');

  if (kReleaseMode) {
    // This involves blocking the isolate, which breaks hot reloading.
    while (true) {
      // Block this thread while waiting for a response
      final success = receive();

      if (!success) break;

      // Once we get a response, notify the main thread
      sendPort.send(null);
    }
  } else {
    // In debug mode, we don't block this isolate. Instead, we check the
    // message queue on a fast timer and fetch a response if we know there is
    // one.
    Timer.periodic(
      const Duration(milliseconds: 10),
      (timer) {
        final success = tryReceive();

        if (!success) return;

        // Once we get a response, notify the main thread
        sendPort.send(null);
      },
    );
  }
}
