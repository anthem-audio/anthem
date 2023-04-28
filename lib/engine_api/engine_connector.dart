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

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'package:anthem/generated/messages_generated.dart';

const path = './data/flutter_assets/assets/EngineConnector.dll';
final engineConnectorLib =
    DynamicLibrary.open('./data/flutter_assets/assets/EngineConnector.dll');

typedef ConnectFuncNative = Void Function(Pointer<Utf8>);
typedef ConnectFuncDart = void Function(Pointer<Utf8>);

typedef CleanUpMessageQueuesFuncNative = Void Function(Pointer<Utf8>);
typedef CleanUpMessageQueuesFuncDart = void Function(Pointer<Utf8>);

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

/// Provides a way to communicate with the engine process.
///
/// The [EngineConnector] class manages an engine process. It uses a dynamic
/// library written in C++ to communicate with the process.
///
/// The [send] method can be used to send a byte array to the engine. This
/// should be a serialized FlatBuffers message. A message can be sent like so:
///
/// ```dart
/// final engineConnectorID = getID();
/// final engineConnector = EngineConnector(
///   engineConnectorID,
///   (Uint8List reply) {
///     final response = Response(reply);
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
/// ).toBytes();
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

  /// Message queues need an agreed-upon ID to be set up, since they're
  /// brokered by the operating system. This ID is used so we can have multiple
  /// engines running at once, since otherwise the message queues for the
  /// different engines would clash with each other.
  final String _id;

  late ConnectFuncDart _connect;
  late CleanUpMessageQueuesFuncDart _cleanUpMessageQueues;
  late GetMessageSendBufferFuncDart _getMessageSendBuffer;
  late GetMessageReceiveBufferFuncDart _getMessageReceiveBuffer;
  late GetLastReceivedMessageSizeFuncDart _getLastReceivedMessageSize;
  late SendFromBufferFuncDart _sendFromBuffer;

  // Buffer for writing messages
  late Pointer<Uint8> _messageSendBuffer;
  late Pointer<Uint8> _messageReceiveBuffer;

  late Isolate receiveIsolate;
  late ReceivePort mainToIsolateReceivePort;

  Process? engineProcess;

  Function(Uint8List reply)? onReply;

  late Future<void> onInit;
  bool _initialized = false;

  /// If any requests are sent before the engine starts and IPC is set up, this
  /// list will hold the requests until the engine is initialized, at which
  /// point they will all be sent.
  final List<Uint8List> _bufferedRequests = [];

  /// Timer that sends a heartbeat message to the engine every 5 seconds. If
  /// the engine doesn't receive one after 10 seconds, it will stop itself.
  late Timer _engineHeartbeatTimer;

  EngineConnector(this._id, [this.onReply]) {
    _cleanUpMessageQueues = engineConnectorLib.lookupFunction<
        CleanUpMessageQueuesFuncNative,
        CleanUpMessageQueuesFuncDart>('cleanUpMessageQueues');
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

    _engineHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        final heartbeat = RequestObjectBuilder(
          id: getRequestId(),
          commandType: CommandTypeId.Heartbeat,
          command: HeartbeatObjectBuilder(),
        ).toBytes();
        send(heartbeat);
      },
    );
  }

  /// Starts the engine process, sets up IPC, and starts the reply listener
  /// isolate.
  Future<void> _init() async {
    if (kDebugMode) {
      print('Starting engine with ID: $_id');
    }

    // We start the engine process before trying to connect. The connect
    // function blocks when trying to open the engine's message queue, so the
    // engine's message queue must already exist before we try to connect.
    final mainExecutablePath = File(Platform.resolvedExecutable);
    engineProcess = await Process.start(
      '${mainExecutablePath.parent.path}/data/flutter_assets/assets/AnthemEngine.exe',
      [_id],
    );

    // Now that the engine has created its message queue and is waiting for
    // ours, we will create our message queue and open the engine's message
    // queue.
    final idPtr = _id.toNativeUtf8();
    _connect(idPtr);
    calloc.free(idPtr);

    _messageSendBuffer = _getMessageSendBuffer();
    _messageReceiveBuffer = _getMessageReceiveBuffer();

    mainToIsolateReceivePort = ReceivePort();

    // Spawn an isolate to listen for replies from the engine
    Isolate.spawn(
      _responseReceiverIsolate,
      mainToIsolateReceivePort.sendPort,
    ).then(
      (isolate) {
        receiveIsolate = isolate;
      },
    );

    SendPort? sendPort;

    mainToIsolateReceivePort.listen((message) {
      // The first message is the send port
      if (sendPort == null) {
        sendPort = message;
        return;
      }

      // Copy the message from the buffer in the dynamic library
      _copyReplyAndNotify();

      // Tell the receiver thread that we're done using the buffer
      sendPort!.send(null);
    });

    _initialized = true;
  }

  /// Sends the given [Uint8List] buffer to the engine.
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

  /// If there is a listener for engine replies, copies the most recent reply
  /// from the engine and notifies the listener.
  void _copyReplyAndNotify() {
    if (onReply == null) return;

    final size = _getLastReceivedMessageSize();

    final buffer = Uint8List(size);

    // Copy message from receive buffer
    for (var i = 0; i < size; i++) {
      buffer[i] = _messageReceiveBuffer.elementAt(i).value;
    }

    onReply!(buffer);
  }

  /// Stops the engine process and isolate, and cleans up the message queues.
  void dispose() {
    // Kill engine process
    engineProcess?.kill();

    // Kill isolate that is waiting for engine replies
    receiveIsolate.kill();

    // Stop the timer that sends heartbeat messages to the engine
    _engineHeartbeatTimer.cancel();

    // Clean up message queues. These will be persisted by the OS if we don't
    // clean them up.
    final idPtr = _id.toNativeUtf8();
    _cleanUpMessageQueues(idPtr);
    calloc.free(idPtr);
  }
}

/// Isolate thread function for receiving responses from the engine.
///
/// Waiting for a response from the engine requires blocking, which we can't do
/// on the main thread. This function runs in an isolate and listens for
/// messages in the engine-to-UI message queue.
///
/// When a reply is received, it is stored in a buffer created by the dynamic
/// library. This function then sends an empty message to the main thread and
/// waits for a reply. The main thread copies the message out of the buffer and
/// sends an empty message to this function, which then continues listening for
/// new messages.
void _responseReceiverIsolate(SendPort sendPort) async {
  const path = './data/flutter_assets/assets/EngineConnector.dll';
  final engineConnectorLib = DynamicLibrary.open(path);

  final receive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('receive');
  final tryReceive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('tryReceive');

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  Completer<void>? mainThreadCopyFromBufferCompleter;

  // The main thread will send an empty message when it's done reading the
  // message buffer.
  receivePort.listen((message) {
    mainThreadCopyFromBufferCompleter?.complete();
  });

  if (kReleaseMode) {
    // This involves blocking the isolate, which breaks hot reloading.
    while (true) {
      // Block this thread while waiting for a response
      final success = receive();

      if (!success) break;

      // Once we get a response, notify the main thread
      sendPort.send(null);

      // Wait for the UI thread to copy the reply
      mainThreadCopyFromBufferCompleter = Completer();
      await mainThreadCopyFromBufferCompleter.future;
    }
  } else {
    // In debug mode, we don't block this isolate. Instead, we check the
    // message queue on a fast timer and fetch a response if we know there is
    // one.
    Timer.periodic(
      const Duration(milliseconds: 5),
      (timer) {
        if (mainThreadCopyFromBufferCompleter?.isCompleted == false) {
          return;
        }

        final success = tryReceive();

        if (!success) return;

        // Once we get a response, notify the main thread
        sendPort.send(null);

        // Wait for the UI thread to copy the reply
        mainThreadCopyFromBufferCompleter = Completer();
      },
    );
  }
}
