/*
  Copyright (C) 2025 Joshua Wade

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
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:anthem/engine_api/memory_block.dart';
import 'package:anthem/engine_api/wasm_shared_memory_ring_buffer.dart';

class EngineEmscriptenInterface {
  final String exportName;
  late final JSObject appInstance;

  late final WasmSharedMemoryRingBuffer readBuffer;
  late final WasmSharedMemoryRingBuffer writeBuffer;

  List<MemoryBlock> outgoingMessages = [];

  void Function(Uint8List bytes)? onMessageReceived;

  EngineEmscriptenInterface(this.exportName, {this.onMessageReceived});

  Future<void> init() async {
    final constructorAny = globalContext.getProperty(exportName.toJS);
    if (!constructorAny.isA<JSFunction>()) {
      throw Exception(
        'EngineEmscriptenInterface: $exportName is not a function',
      );
    }

    final constructor = constructorAny as JSFunction;

    final appInstancePromiseAny = constructor.callAsFunction();
    if (!appInstancePromiseAny.isA<JSPromise>()) {
      throw Exception(
        'EngineEmscriptenInterface: $exportName did not return a Promise',
      );
    }

    final appInstancePromise = appInstancePromiseAny as JSPromise;
    final appInstanceAny = await appInstancePromise.toDart;
    if (!appInstanceAny.isA<JSObject>()) {
      throw Exception(
        'EngineEmscriptenInterface: $exportName Promise did not resolve to an object',
      );
    }
    appInstance = appInstanceAny as JSObject;

    final completer = Completer<void>();

    Timer.periodic(Duration(milliseconds: 100), (timer) {
      final isCommsReadyAny = appInstance.getProperty('_isCommsReady'.toJS);
      if (isCommsReadyAny.isA<JSFunction>()) {
        final result = (isCommsReadyAny as JSFunction).callAsFunction();

        // Return type in C++ is bool, but it comes back to JavaScript as a number.
        if (!result.isA<JSNumber>()) {
          timer.cancel();
          completer.completeError(
            Exception(
              'EngineEmscriptenInterface: _isCommsReady did not return a number',
            ),
          );
          return;
        }

        if ((result as JSNumber).toDartInt == 1) {
          timer.cancel();
          completer.complete();
        }
      } else {
        timer.cancel();
        completer.completeError(
          Exception(
            'EngineEmscriptenInterface: _isCommsReady is not a function',
          ),
        );
      }
    });

    await completer.future;

    JSFunction getAsFunction(String functionName) {
      final funcAny = appInstance.getProperty(functionName.toJS);
      if (!funcAny.isA<JSFunction>()) {
        throw Exception(
          'EngineEmscriptenInterface: $functionName is not a function',
        );
      }
      return funcAny as JSFunction;
    }

    final readBufferHeadPtrAny = getAsFunction(
      '_getReadBufferHeadPtr',
    ).callAsFunction();
    if (!readBufferHeadPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferHeadPtr did not return a number',
      );
    }
    final readBufferHeadPtr = readBufferHeadPtrAny as JSNumber;

    final readBufferTailPtrAny = getAsFunction(
      '_getReadBufferTailPtr',
    ).callAsFunction();
    if (!readBufferTailPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferTailPtr did not return a number',
      );
    }
    final readBufferTailPtr = readBufferTailPtrAny as JSNumber;

    final readBufferCapacityAny = getAsFunction(
      '_getReadBufferCapacity',
    ).callAsFunction();
    if (!readBufferCapacityAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferCapacity did not return a number',
      );
    }
    final readBufferCapacity = readBufferCapacityAny as JSNumber;

    final readBufferMaskAny = getAsFunction(
      '_getReadBufferMask',
    ).callAsFunction();
    if (!readBufferMaskAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferMask did not return a number',
      );
    }
    final readBufferMask = readBufferMaskAny as JSNumber;

    final readBufferDataPtrAny = getAsFunction(
      '_getReadBufferDataPtr',
    ).callAsFunction();
    if (!readBufferDataPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferDataPtr did not return a number',
      );
    }
    final readBufferDataPtr = readBufferDataPtrAny as JSNumber;

    final readBufferTicketPtrAny = getAsFunction(
      '_getReadBufferTicketPtr',
    ).callAsFunction();
    if (!readBufferTicketPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getReadBufferTicketPtr did not return a number',
      );
    }
    final readBufferTicketPtr = readBufferTicketPtrAny as JSNumber;

    readBuffer = WasmSharedMemoryRingBuffer(
      engineInterface: this,
      headPtr: readBufferHeadPtr.toDartInt,
      tailPtr: readBufferTailPtr.toDartInt,
      capacity: readBufferCapacity.toDartInt,
      mask: readBufferMask.toDartInt,
      dataPtr: readBufferDataPtr.toDartInt,
      ticketPtr: readBufferTicketPtr.toDartInt,
    );

    final writeBufferHeadPtrAny = getAsFunction(
      '_getWriteBufferHeadPtr',
    ).callAsFunction();
    if (!writeBufferHeadPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferHeadPtr did not return a number',
      );
    }
    final writeBufferHeadPtr = writeBufferHeadPtrAny as JSNumber;

    final writeBufferTailPtrAny = getAsFunction(
      '_getWriteBufferTailPtr',
    ).callAsFunction();
    if (!writeBufferTailPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferTailPtr did not return a number',
      );
    }
    final writeBufferTailPtr = writeBufferTailPtrAny as JSNumber;

    final writeBufferCapacityAny = getAsFunction(
      '_getWriteBufferCapacity',
    ).callAsFunction();
    if (!writeBufferCapacityAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferCapacity did not return a number',
      );
    }
    final writeBufferCapacity = writeBufferCapacityAny as JSNumber;

    final writeBufferMaskAny = getAsFunction(
      '_getWriteBufferMask',
    ).callAsFunction();
    if (!writeBufferMaskAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferMask did not return a number',
      );
    }
    final writeBufferMask = writeBufferMaskAny as JSNumber;

    final writeBufferDataPtrAny = getAsFunction(
      '_getWriteBufferDataPtr',
    ).callAsFunction();
    if (!writeBufferDataPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferDataPtr did not return a number',
      );
    }
    final writeBufferDataPtr = writeBufferDataPtrAny as JSNumber;

    final writeBufferTicketPtrAny = getAsFunction(
      '_getWriteBufferTicketPtr',
    ).callAsFunction();
    if (!writeBufferTicketPtrAny.isA<JSNumber>()) {
      throw Exception(
        'EngineEmscriptenInterface: _getWriteBufferTicketPtr did not return a number',
      );
    }
    final writeBufferTicketPtr = writeBufferTicketPtrAny as JSNumber;

    writeBuffer = WasmSharedMemoryRingBuffer(
      engineInterface: this,
      headPtr: writeBufferHeadPtr.toDartInt,
      tailPtr: writeBufferTailPtr.toDartInt,
      capacity: writeBufferCapacity.toDartInt,
      mask: writeBufferMask.toDartInt,
      dataPtr: writeBufferDataPtr.toDartInt,
      ticketPtr: writeBufferTicketPtr.toDartInt,
    );

    _startReadLoop();
  }

  void sendMessage(Uint8List bytes) {
    outgoingMessages.add(MemoryBlock.fromTypedList(bytes));
    if (!_isSendActive) {
      _sendPendingMessages();
    }
  }

  bool _isSendActive = false;
  int _backoffDurationUs = 0;
  void _sendPendingMessages() {
    _isSendActive = true;

    while (outgoingMessages.isNotEmpty) {
      final message = outgoingMessages.first;
      final messageData = message.buffer;

      for (var i = 0; i < messageData.length; i++) {
        final success = writeBuffer.tryEnqueue(messageData[i]);
        if (!success) {
          // We need to remove the data we already sent from this message
          message.removeRange(0, i);

          _backoffDurationUs += 100;
          Timer(
            Duration(microseconds: _backoffDurationUs),
            () => _sendPendingMessages(),
          );

          return;
        }
      }

      outgoingMessages.removeAt(0);
    }

    final heapI32 = writeBuffer.getHeapI32();
    final heapU32 = writeBuffer.getHeapU32();
    writeBuffer.incrementTicket(heapU32);
    writeBuffer.notifyTicketChange(heapI32);

    _backoffDurationUs = 0;
    _isSendActive = false;
  }

  void _startReadLoop() async {
    while (true) {
      final heapI32 = readBuffer.getHeapI32();
      final ticketValue = readBuffer.getTicketValue(heapI32);

      _tryRead();

      await readBuffer.waitForTicketSignal(heapI32, ticketValue);
    }
  }

  var _introBytesSkipped = 0;
  void _tryRead() {
    var size = readBuffer.size();
    if (size == 0) return;

    // There is an 8-byte intro (64-bit integer), where the engine echos its ID
    // back to us. This is because, from the UI side, we receive a socket
    // connection from the engine, and we don't have any other way of knowing
    // which engine instance it is. On web, we are constructing the engine
    // instance in a way that allows us to call methods on it directly, so we
    // don't need this intro ID to identify the engine. As such, we can just
    // skip these bytes.
    //
    // Note that the actual bytes skipped is 16 - the 8-byte ID itself is
    // prefixed by a header that indicates the size of the message (as with all
    // incoming messages), so we need to skip that too.
    const introBytesToSkip = 16;
    if (_introBytesSkipped < introBytesToSkip) {
      final toSkip = (introBytesToSkip - _introBytesSkipped).clamp(0, size);
      for (var i = 0; i < toSkip; i++) {
        final byte = readBuffer.tryDequeue();
        if (byte == null) {
          break;
        }
        _introBytesSkipped++;
        size--;
      }
    }

    final builder = BytesBuilder(copy: false);
    var messageBytes = Uint8List(size);
    while (size > 0) {
      for (var i = 0; i < size; i++) {
        final byte = readBuffer.tryDequeue();
        if (byte == null) {
          // This should never happen, since we checked the size above.
          break;
        }
        messageBytes[i] = byte;
      }

      // Check the buffer size again - if there is more data to read, we will
      // combine it all into a single message.
      size = readBuffer.size();
      builder.add(messageBytes);
      if (size == 0) break;
      messageBytes = Uint8List(size);
    }

    onMessageReceived?.call(builder.toBytes());
  }
}
