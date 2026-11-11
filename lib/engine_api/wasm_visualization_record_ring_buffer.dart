/*
  Copyright (C) 2026 Joshua Wade

  This file is part of Anthem.

  Anthem is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Anthem is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Anthem. If not, see <https://www.gnu.org/licenses/>.
*/

// cspell:ignore HEAPU

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Zero-copy reader for the visualization record ring stored in the engine's
/// shared WebAssembly memory. Cursor operations remain in the common C++ ring
/// implementation; Dart only obtains a view of the acquired payload.
final class WasmVisualizationRecordRingBufferReader {
  final JSObject _appInstance;
  final JSFunction _tryAcquire;
  final JSFunction _getData;
  final JSFunction _getSize;
  final JSFunction _release;
  final JSFunction _availableBytes;

  bool _hasAcquiredRecord = false;
  bool _closed = false;

  WasmVisualizationRecordRingBufferReader(JSObject appInstance)
    : _appInstance = appInstance,
      _tryAcquire = _getFunction(appInstance, '_tryAcquireVisualizationRecord'),
      _getData = _getFunction(
        appInstance,
        '_getAcquiredVisualizationRecordData',
      ),
      _getSize = _getFunction(
        appInstance,
        '_getAcquiredVisualizationRecordSize',
      ),
      _release = _getFunction(appInstance, '_releaseVisualizationRecord'),
      _availableBytes = _getFunction(
        appInstance,
        '_getVisualizationRecordAvailableBytes',
      );

  int get availableBytes {
    if (_closed) throw StateError('The visualization reader has been closed.');
    return _callNumber(
      _availableBytes,
      '_getVisualizationRecordAvailableBytes',
    );
  }

  Uint8List? tryAcquire() {
    if (_closed) throw StateError('The visualization reader has been closed.');
    if (_hasAcquiredRecord) {
      throw StateError('Release the current record before acquiring another.');
    }

    final result = _callNumber(_tryAcquire, '_tryAcquireVisualizationRecord');
    if (result == 0) {
      return null;
    }
    if (result != 1) {
      throw StateError('The engine failed to acquire a visualization record.');
    }

    _hasAcquiredRecord = true;
    try {
      final data = _callNumber(_getData, '_getAcquiredVisualizationRecordData');
      final size = _callNumber(_getSize, '_getAcquiredVisualizationRecordSize');
      if (data <= 0 || size < 0) {
        throw StateError(
          'The engine returned an invalid visualization record.',
        );
      }

      final heap = _appInstance.getProperty('HEAPU8'.toJS) as JSUint8Array;
      final length = (heap.getProperty('length'.toJS) as JSNumber).toDartInt;
      if (data > length || size > length - data) {
        throw StateError(
          'The visualization record is outside WebAssembly memory.',
        );
      }
      final recordView = heap.callMethod(
        'subarray'.toJS,
        data.toJS,
        (data + size).toJS,
      ) as JSUint8Array;
      _hasAcquiredRecord = true;
      return recordView.toDart;
    } catch (_) {
      release();
      rethrow;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_hasAcquiredRecord) {
      _callNumber(_release, '_releaseVisualizationRecord');
      _hasAcquiredRecord = false;
    }
  }

  void release() {
    if (!_hasAcquiredRecord) {
      throw StateError('No visualization record is currently acquired.');
    }
    if (_callNumber(_release, '_releaseVisualizationRecord') != 1) {
      throw StateError('The engine failed to release a visualization record.');
    }
    _hasAcquiredRecord = false;
  }

  static JSFunction _getFunction(JSObject appInstance, String name) {
    final function = appInstance.getProperty(name.toJS);
    if (!function.isA<JSFunction>()) {
      throw StateError('EngineEmscriptenInterface: $name is not a function.');
    }
    return function as JSFunction;
  }

  static int _callNumber(JSFunction function, String name) {
    final result = function.callAsFunction();
    if (!result.isA<JSNumber>()) {
      throw StateError(
        'EngineEmscriptenInterface: $name did not return a number.',
      );
    }
    return (result as JSNumber).toDartInt;
  }
}
