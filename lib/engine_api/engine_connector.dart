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

import 'package:anthem/generated/messages_generated.dart';

/// Set this to override the path to the engine.
///
/// This will allow you to stop the engine from Anthem, compile a new engine,
/// and start the new enine, all without re-building the Anthem UI.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? enginePathOverride = null;

final mainExecutablePath = File(Platform.resolvedExecutable);
final dyLibPath = Platform.isWindows
    ? '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/EngineConnector.dll'
    : '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/libEngineConnector.so';
final engineConnectorLib = DynamicLibrary.open(dyLibPath);

typedef ConnectFuncNative = Bool Function(Int64 engineID);
typedef ConnectFuncDart = bool Function(int engineID);

typedef FreeEngineConnectionFuncNative = Void Function(Int64 engineID);
typedef FreeEngineConnectionFuncDart = void Function(int engineID);

typedef CleanUpMessageQueuesFuncNative = Void Function(Int64 engineID);
typedef CleanUpMessageQueuesFuncDart = void Function(int engineID);

typedef GetMessageSendBufferFuncNative = Pointer<Uint8> Function(
    Int64 engineID);
typedef GetMessageSendBufferFuncDart = Pointer<Uint8> Function(int engineID);

typedef GetMessageReceiveBufferFuncNative = Pointer<Uint8> Function(
    Int64 engineID);
typedef GetMessageReceiveBufferFuncDart = Pointer<Uint8> Function(int engineID);

typedef SendFromBufferFuncNative = Void Function(Int64 engineID, Int64 size);
typedef SendFromBufferFuncDart = void Function(int engineID, int size);

typedef GetLastReceivedMessageSizeFuncNative = Int64 Function(Int64 engineID);
typedef GetLastReceivedMessageSizeFuncDart = int Function(int engineID);

typedef ReceiveFuncNative = Bool Function(Int64 engineID);
typedef ReceiveFuncDart = bool Function(int engineID);

typedef TryReceiveFuncNative = Bool Function(Int64 engineID);
typedef TryReceiveFuncDart = bool Function(int engineID);

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

  /// Message queues need an agreed-upon ID to be set up, since they're
  /// brokered by the operating system. This ID is used so we can have multiple
  /// engines running at once, since otherwise the message queues for the
  /// different engines would clash with each other.
  final int _id;

  late CleanUpMessageQueuesFuncDart _cleanUpMessageQueues;
  late FreeEngineConnectionFuncDart _freeEngineConnection;
  late GetMessageSendBufferFuncDart _getMessageSendBuffer;
  late GetMessageReceiveBufferFuncDart _getMessageReceiveBuffer;
  late GetLastReceivedMessageSizeFuncDart _getLastReceivedMessageSize;

  // Buffer for writing messages
  late Pointer<Uint8> _messageSendBuffer;
  late Pointer<Uint8> _messageReceiveBuffer;

  late Isolate requestIsolate;
  late ReceivePort requestIsolateReceivePort;
  SendPort? requestIsolateSendPort;
  Timer? requestIsolateTimeout;

  late Isolate receiveIsolate;
  late ReceivePort responseIsolateReceivePort;

  Process? engineProcess;

  void Function(Response reply)? onReply;
  void Function()? onCrash;

  late Future<bool> onInit;
  bool _initialized = false;

  /// If any requests are sent before the engine starts and IPC is set up, this
  /// list will hold the requests until the engine is initialized, at which
  /// point they will all be sent.
  final List<RequestObjectBuilder> _bufferedRequests = [];

  /// Timer that sends a heartbeat message to the engine every 5 seconds. If
  /// the engine doesn't receive one after 10 seconds, it will stop itself.
  late Timer _engineHeartbeatTimer;

  EngineConnector(this._id, {this.onReply, this.onCrash}) {
    _cleanUpMessageQueues = engineConnectorLib.lookupFunction<
        CleanUpMessageQueuesFuncNative,
        CleanUpMessageQueuesFuncDart>('cleanUpMessageQueues');
    _freeEngineConnection = engineConnectorLib.lookupFunction<
        CleanUpMessageQueuesFuncNative,
        CleanUpMessageQueuesFuncDart>('freeEngineConnection');
    _getMessageSendBuffer = engineConnectorLib.lookupFunction<
        GetMessageSendBufferFuncNative,
        GetMessageSendBufferFuncDart>('getMessageSendBuffer');
    _getMessageReceiveBuffer = engineConnectorLib.lookupFunction<
        GetMessageReceiveBufferFuncNative,
        GetMessageReceiveBufferFuncDart>('getMessageReceiveBuffer');
    _getLastReceivedMessageSize = engineConnectorLib.lookupFunction<
        GetLastReceivedMessageSizeFuncNative,
        GetLastReceivedMessageSizeFuncDart>('getLastReceivedMessageSize');

    onInit = _init();

    // If any requests came in before the engine was started, send them now.
    onInit.then((success) {
      if (!success) return;
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
        );
        send(heartbeat);
      },
    );
  }

  /// Starts the engine process, sets up IPC, and starts the reply listener
  /// isolate.
  Future<bool> _init() async {
    if (kDebugMode) {
      print('Starting engine with ID: $_id');
    }

    _cleanUpMessageQueues(_id);

    // We start the engine process before trying to connect. The connect
    // function blocks when trying to open the engine's message queue, so the
    // engine's message queue must already exist before we try to connect.
    final anthemPathStr = enginePathOverride ??
        (Platform.isWindows
            ? '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/AnthemEngine.exe'
            : '${mainExecutablePath.parent.path}/data/flutter_assets/assets/engine/AnthemEngine');

    // If we're in debug mode, start with a command line window so we can see logging
    if (kDebugMode) {
      if (Platform.isWindows) {
        engineProcess = await Process.start(
          'powershell',
          [
            '-Command',
            '& {Start-Process -FilePath "$anthemPathStr" -ArgumentList "$_id" -Wait}'
          ],
        );
      } else if (Platform.isLinux) {
        // Can't figure out a good way to start in a shell window on Linux, so
        // this mirrors the engine output to our standard out.
        engineProcess = await Process.start(
          anthemPathStr,
          [_id.toString()],
        );
        engineProcess!.stdout.listen((msg) {
          for (final line in String.fromCharCodes(msg).split('\n')) {
            // ignore: avoid_print
            print('[Engine $_id] $line');
          }
        });
        engineProcess!.stderr.listen((msg) {
          for (final line in String.fromCharCodes(msg).split('\n')) {
            // ignore: avoid_print
            print('[Engine $_id stderr] $line');
          }
        });
      }
    } else {
      engineProcess = await Process.start(
        anthemPathStr,
        [_id.toString()],
      );
    }

    // Now that the engine has created its message queue and is waiting for
    // ours, we will create our message queue and open the engine's message
    // queue. We do this in an isolate, since this operation blocks the current
    // thread.
    final initIsolateReceivePort = ReceivePort();
    final initIsolate =
        await Isolate.spawn(_initIsolate, initIsolateReceivePort.sendPort);
    final initCompleter = Completer<bool>();

    // The first message is the send port, which we use to send the engine ID
    // to the isolate. The second message lets us know that the init process is
    // done.
    initIsolateReceivePort.listen((message) {
      if (message is SendPort) {
        message.send(_id);
        return;
      }

      final result = message as bool;
      initCompleter.complete(result);
    });

    final result = await initCompleter.future;

    if (!result) {
      return false;
    }

    initIsolate.kill();

    _messageSendBuffer = _getMessageSendBuffer(_id);
    _messageReceiveBuffer = _getMessageReceiveBuffer(_id);

    requestIsolateReceivePort = ReceivePort();

    final requestSenderIsolateFuture = Isolate.spawn(
      _requestSenderIsolate,
      requestIsolateReceivePort.sendPort,
    );

    requestSenderIsolateFuture.then(
      (isolate) {
        requestIsolate = isolate;
      },
    );

    requestIsolateReceivePort.listen((message) {
      // The first message is the send port
      if (requestIsolateSendPort == null) {
        requestIsolateSendPort = message;

        // The request isolate expects the first message to be the engine ID
        requestIsolateSendPort!.send(_id);

        return;
      }

      // Cancel the timeout, since we got a response
      requestIsolateTimeout?.cancel();
    });

    responseIsolateReceivePort = ReceivePort();

    // Spawn an isolate to listen for replies from the engine
    final responseIsolateFuture = Isolate.spawn(
      _responseReceiverIsolate,
      responseIsolateReceivePort.sendPort,
    );

    responseIsolateFuture.then(
      (isolate) {
        receiveIsolate = isolate;
      },
    );

    SendPort? responseIsolateSendPort;

    responseIsolateReceivePort.listen((message) {
      // The first message is the send port
      if (responseIsolateSendPort == null) {
        responseIsolateSendPort = message;

        // The response isolate expects the first message to be the engine ID
        responseIsolateSendPort!.send(_id);

        return;
      }

      // Copy the message from the buffer in the dynamic library
      _copyReplyAndNotify();

      // Tell the receiver thread that we're done using the buffer
      responseIsolateSendPort!.send(null);
    });

    _heartbeatCheckTimer = Timer.periodic(
      // Maybe a bit long if this is our only way to tell if the engine died
      const Duration(seconds: 10),
      (_) {
        if (!_heartbeatReceived) {
          onCrash?.call();
          _heartbeatCheckTimer?.cancel();
        }

        _heartbeatReceived = false;
      },
    );

    _initialized = true;

    await requestSenderIsolateFuture;
    await responseIsolateFuture;

    return true;
  }

  /// Sends the given [Request] to the engine.
  void send(RequestObjectBuilder request) {
    final bytes = request.toBytes();

    if (!_initialized) {
      _bufferedRequests.add(request);
      return;
    }

    final size = bytes.length;

    if (size > 65536) {
      throw Exception(
          'Flatbuffers message was too large. We should dynamically reallocate here instead of throwing. This is a bug.');
    }

    // Copy message to buffer
    for (var i = 0; i < size; i++) {
      _messageSendBuffer.elementAt(i).value = bytes.elementAt(i);
    }

    // TODO: If the timer is active, we must buffer the request, since we
    // can't send multiple at once.

    // Tell the request isolate to send the message in the request buffer
    requestIsolateSendPort?.send(size);

    // TODO: Remove this when we add request buffering
    if (requestIsolateSendPort == null) return;

    // Schedule a timeout, since the send might fail and cause the isolate to
    // block indefinitely
    requestIsolateTimeout = Timer(
      const Duration(seconds: 1),
      () {
        onCrash?.call();
      },
    );
  }

  bool _heartbeatReceived = true;
  Timer? _heartbeatCheckTimer;

  /// If there is a listener for engine replies, copies the most recent reply
  /// from the engine and notifies the listener.
  void _copyReplyAndNotify() {
    if (onReply == null) return;

    final size = _getLastReceivedMessageSize(_id);

    final buffer = Uint8List(size);

    // Copy message from receive buffer
    for (var i = 0; i < size; i++) {
      buffer[i] = _messageReceiveBuffer.elementAt(i).value;
    }

    final response = Response(buffer);

    // Heartbeats are handled here and not passed on. If we haven't received a
    // heartbeat reply in a certain amount of time, then we can assume the
    // engine is dead.
    if (response.returnValueType == ReturnValueTypeId.HeartbeatReply) {
      _heartbeatReceived = true;
      return;
    }

    onReply!(response);
  }

  /// Stops the engine process and isolate, and cleans up the message queues.
  void dispose() {
    // Stop the heartbeat check timer
    _heartbeatCheckTimer?.cancel();

    // Kill engine process
    engineProcess?.kill();

    // Kill isolate that is waiting for engine replies
    receiveIsolate.kill();

    // Stop the timer that sends heartbeat messages to the engine
    _engineHeartbeatTimer.cancel();

    // Clean up message queues. These will be persisted by the OS if we don't
    // clean them up.
    _cleanUpMessageQueues(_id);

    // Free any memory that the dynamic library allocated for the connection
    _freeEngineConnection(_id);
  }
}

/// Isolate thread function to connect to the engine.
///
/// Connecting to a new enigne involves starting the engine process and then
/// repeatedly checking for the engine-to-UI message queue that should be
/// created by the engine. This task blocks the thread that does it, so we
/// offload this work to an isolate. This allows Flutter to continue rendering
/// frames while the engine is starting.
///
/// This isolate sends a message when it's done.
void _initIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final engineConnectorLib = DynamicLibrary.open(dyLibPath);
  final connect = engineConnectorLib
      .lookupFunction<ConnectFuncNative, ConnectFuncDart>('connect');

  // This isolate should be given the ID of the engine as the first and only
  // message.
  receivePort.first.then((id) {
    final result = connect(id as int);
    sendPort.send(result);
  });
}

/// Isolate thread function for sending messages to the engine.
///
/// When sending a request to the engine, we copy the bytes for the request
/// into a buffer allocated by the engine connector dynamic library, and then
/// we notify this isolate to send the message.
///
/// We do this because the `message_queue` `send()` function has a chance of
/// blocking the current thread indefinitely. This will happen if the engine
/// process dies for some reason, though it may happen for other reasons as
/// well.
///
/// If we tell this thread to send a message and it doesn't reply after a
/// certain amount of time, then we will report that the engine has crashed.
void _requestSenderIsolate(SendPort sendPort) {
  final engineConnectorLib = DynamicLibrary.open(dyLibPath);

  final sendFromBuffer = engineConnectorLib.lookupFunction<
      SendFromBufferFuncNative, SendFromBufferFuncDart>('sendFromBuffer');

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  int? engineID;

  // The main thread will send a message with the message size when it wants
  // this thread to send from the dynamic library's buffer.
  receivePort.listen((message) {
    // The first message will alwyas be the engine ID
    if (engineID == null) {
      engineID = message as int;
      return;
    }

    // Send the current buffer
    sendFromBuffer(engineID!, message as int);

    // Notify the main thread when we're done
    sendPort.send(null);
  });
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
  final engineConnectorLib = DynamicLibrary.open(dyLibPath);

  final receive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('receive');
  final tryReceive = engineConnectorLib
      .lookupFunction<ReceiveFuncNative, ReceiveFuncDart>('tryReceive');

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  Completer<void> engineIDCompleter = Completer();
  Completer<void>? mainThreadCopyFromBufferCompleter;

  int? engineID;

  // The main thread will send an empty message when it's done reading the
  // message buffer.
  receivePort.listen((message) {
    // The first message will be the engine ID
    if (engineID == null) {
      engineID = message as int;
      engineIDCompleter.complete();
    }

    mainThreadCopyFromBufferCompleter?.complete();
  });

  await engineIDCompleter.future;

  if (!kDebugMode) {
    // This involves blocking the isolate, which breaks hot reloading.
    while (true) {
      // Block this thread while waiting for a response
      final success = receive(engineID!);

      if (!success) break;

      // Once we get a response, notify the main thread
      sendPort.send(null);

      // Wait for the UI thread to copy the reply
      mainThreadCopyFromBufferCompleter = Completer();
      await mainThreadCopyFromBufferCompleter.future;
    }
  } else {
    bool timerActive = false;

    // In debug mode, we don't block this isolate. Instead, we check the
    // message queue on a fast timer and fetch a response if we know there is
    // one.
    Timer.periodic(
      const Duration(milliseconds: 5),
      (timer) async {
        // If a previous iteration of the timer is active but paused on an
        // await, don't run another iteration.
        if (timerActive) {
          return;
        }
        timerActive = true;

        // Shouldn't be possible, but just in case
        if (mainThreadCopyFromBufferCompleter?.isCompleted == false) {
          return;
        }

        while (true) {
          final success = tryReceive(engineID!);

          if (!success) break;

          // Once we get a response, notify the main thread
          sendPort.send(null);

          // Wait for the UI thread to copy the reply
          mainThreadCopyFromBufferCompleter = Completer();
          await mainThreadCopyFromBufferCompleter!.future;
        }

        timerActive = false;
      },
    );
  }
}
