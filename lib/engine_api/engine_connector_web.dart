/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

import 'dart:typed_data';

import 'package:anthem/engine_api/engine_emscripten_interface.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/visualization_record.dart';
import 'package:flutter/foundation.dart';

class EngineConnector extends EngineConnectorBase {
  late EngineEmscriptenInterface engineInterface = EngineEmscriptenInterface(
    'AnthemEngine',
    onMessageReceived: (bytes) {
      onReceive(bytes);
    },
    onPollVisualization: pollVisualizationRecords,
  );

  bool _isInitialized = false;
  bool _disposed = false;

  final List<Uint8List> _pendingMessages = [];

  EngineConnector(
    int id, {
    required super.kDebugMode,
    super.onReply,
    void Function()? onExit,
    super.noHeartbeat = false,
    String? enginePathOverride,
  }) {
    onInit = engineInterface
        .init()
        .then((_) {
          if (_disposed) return false;
          final reader = engineInterface.visualizationRingBufferReader;
          visualizationRecordConsumer = VisualizationRecordConsumer(
            tryAcquire: reader.tryAcquire,
            release: reader.release,
            onRecord: handleVisualizationRecord,
            availableBytes: () => reader.availableBytes,
          );
          _init();
          return true;
        })
        .catchError((Object error) {
          dispose();
          return false;
        });
  }

  void _init() {
    _isInitialized = true;
    for (var message in _pendingMessages) {
      send(message);
    }
    _pendingMessages.clear();
  }

  @override
  void send(Uint8List bytes) {
    if (_disposed) return;
    if (!_isInitialized) {
      _pendingMessages.add(bytes);
      return;
    }

    // Send the length of the request
    final bytesList = !kIsWasm ? Uint32List(1) : Uint64List(1);
    bytesList[0] = bytes.length;
    if (kIsWasm) {
      engineInterface.sendMessage(bytesList.buffer.asUint8List());
    } else {
      final len32 = bytesList.buffer.asUint8List();
      Uint8List len64 = Uint8List(8);
      final endianValue = Endian.host == Endian.little ? 0 : 4;
      for (var i = 0; i < 4; i++) {
        len64[i + endianValue] = len32[i];
      }
      engineInterface.sendMessage(
        // Uint8List.fromList([0, 0, 0, 0].followedBy(len32).toList()),
        Uint8List.fromList(len32.followedBy([0, 0, 0, 0]).toList()),
      );
    }

    engineInterface.sendMessage(bytes);
  }

  @override
  void finalizeVisualizationSharedMemorySetup() {
    // Web does not use an OS shared-memory identifier. Its visualization
    // transport will live directly in shared WebAssembly memory.
  }

  @override
  void dispose() {
    _disposed = true;
    _isInitialized = false;
    super.dispose();
    engineInterface.dispose();
    _pendingMessages.clear();
  }
}
