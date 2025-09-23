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

// cspell:ignore HEAPU

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

import 'engine_emscripten_interface.dart';

/// Implements the Dart side of the shared memory ring buffer used for
/// communication between the the UI and the engine when running under WASM.
///
/// See comms_ring_buffer_wasm.h for the C++ side of this.
class WasmSharedMemoryRingBuffer {
  EngineEmscriptenInterface engineInterface;

  final int _headPtr;
  final int _tailPtr;
  final int _capacity;
  final int _mask;
  final int _dataPtr;
  final int _ticketPtr;

  int get capacity => _capacity;

  WasmSharedMemoryRingBuffer({
    required this.engineInterface,
    required int headPtr,
    required int tailPtr,
    required int capacity,
    required int mask,
    required int dataPtr,
    required int ticketPtr,
  }) : _headPtr = headPtr,
       _tailPtr = tailPtr,
       _capacity = capacity,
       _mask = mask,
       _dataPtr = dataPtr,
       _ticketPtr = ticketPtr;

  JSUint8Array getHeapU8() =>
      engineInterface.appInstance.getProperty('HEAPU8'.toJS) as JSUint8Array;
  JSUint32Array getHeapU32() =>
      engineInterface.appInstance.getProperty('HEAPU32'.toJS) as JSUint32Array;
  JSInt32Array getHeapI32() =>
      engineInterface.appInstance.getProperty('HEAP32'.toJS) as JSInt32Array;

  /// Atomically loads a value from the given pointer in the given heap.
  int _atomicLoad(JSTypedArray heap, int ptr) {
    final atomicObject = window.getProperty('Atomics'.toJS) as JSObject;
    return (atomicObject.callMethod('load'.toJS, heap, ptr.toJS) as JSNumber)
        .toDartInt;
  }

  /// Atomically stores a value to the given pointer in the given heap.
  void _atomicStore(JSTypedArray heapU32, int ptr, int value) {
    final atomicObject = window.getProperty('Atomics'.toJS) as JSObject;
    atomicObject.callMethod('store'.toJS, heapU32, ptr.toJS, value.toJS);
  }

  /// Returns the number of elements currently in the buffer.
  int size() {
    final heapU32 = getHeapU32();

    final head = _atomicLoad(heapU32, _headPtr ~/ 4);
    final tail = _atomicLoad(heapU32, _tailPtr ~/ 4);
    return (head - tail) & _mask;
  }

  /// Tries to enqueue a value into the buffer. Returns true if successful,
  /// false if the buffer is full.
  bool tryEnqueue(int value) {
    final heapU32 = getHeapU32();

    final head = _atomicLoad(heapU32, _headPtr ~/ 4);
    final tail = _atomicLoad(heapU32, _tailPtr ~/ 4);
    if (((head + 1) & _mask) == (tail & _mask)) {
      // Buffer is full.
      return false;
    }

    final heapU8 = getHeapU8();

    final nextHead = (head + 1) & _mask;
    _atomicStore(heapU8, _dataPtr + head, value);
    _atomicStore(heapU32, _headPtr ~/ 4, nextHead);

    return true;
  }

  /// Tries to dequeue a value from the buffer. Returns null if the buffer is
  /// empty.
  int? tryDequeue() {
    final heapU32 = getHeapU32();

    final head = _atomicLoad(heapU32, _headPtr ~/ 4);
    final tail = _atomicLoad(heapU32, _tailPtr ~/ 4);
    if ((head & _mask) == (tail & _mask)) {
      // Buffer is empty.
      return null;
    }

    final heapU8 = getHeapU8();

    final nextTail = (tail + 1) & _mask;
    final value = _atomicLoad(heapU8, _dataPtr + tail);
    _atomicStore(heapU32, _tailPtr ~/ 4, nextTail);
    return value;
  }

  int getTicketValue(JSInt32Array heapI32) {
    return _atomicLoad(heapI32, _ticketPtr ~/ 4);
  }

  Future<void> waitForTicketSignal(JSInt32Array heapI32, int lastSeenTicket) {
    final atomicObject = window.getProperty('Atomics'.toJS) as JSObject;

    // waitAsync is in all major browsers except Firefox, where it just landed
    // in nightly. Fingers crossed it will make Firefox 145.

    final result =
        atomicObject.callMethod(
              'waitAsync'.toJS,
              heapI32,
              (_ticketPtr ~/ 4).toJS,
              lastSeenTicket.toJS,
            )
            as JSObject;

    final asyncField = result.getProperty('async'.toJS) as JSBoolean;
    if (asyncField.toDart) {
      final promiseField = result.getProperty('value'.toJS) as JSPromise;
      return promiseField.toDart.then((_) {});
    }

    // If async is false, that means the value was not equal to lastSeenTicket.
    return Future.value(null);
  }

  void incrementTicket(JSUint32Array heapI32) {
    final atomicObject = window.getProperty('Atomics'.toJS) as JSObject;
    atomicObject.callMethod(
      'add'.toJS,
      heapI32,
      (_ticketPtr ~/ 4).toJS,
      1.toJS,
    );
  }

  void notifyTicketChange(JSInt32Array heapI32) {
    final atomicObject = window.getProperty('Atomics'.toJS) as JSObject;
    atomicObject.callMethod(
      'notify'.toJS,
      heapI32,
      (_ticketPtr ~/ 4).toJS,
      1.toJS,
    );
  }
}
