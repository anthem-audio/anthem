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
import 'dart:convert';

import 'package:anthem/engine_api/memory_block.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:flutter/foundation.dart';

abstract class EngineConnectorBase {
  var requestIdGen = 0;

  bool _heartbeatReceived = true;
  Timer? _heartbeatCheckTimer;

  /// Timer that sends a heartbeat message to the engine every 5 seconds. If
  /// the engine doesn't receive one after 10 seconds, it will stop itself.
  Timer? _engineHeartbeatTimer;

  int getRequestId() {
    // 0x001F_FFFF_FFFF_FFFF is the max safe integer in JavaScript.
    if (requestIdGen > 0x001F_FFFF_FFFF_FFFF) {
      requestIdGen = 0;
    }
    return requestIdGen++;
  }

  late final Future<bool> onInit;

  /// Should be set to kDebugMode from Flutter, or false if not running in a
  /// Flutter environment.
  ///
  /// kDebugMode comes from Flutter, and we can't import anything from Flutter
  /// into our engine integration tests. Since we use this class to talk to the
  /// engine in our engine integration tests, we need to pass this in.
  final bool kDebugMode;

  final bool noHeartbeat;

  final void Function(Response reply)? _onReply;

  EngineConnectorBase({
    required this.kDebugMode,
    required this.noHeartbeat,
    void Function(Response)? onReply,
  }) : _onReply = onReply;

  void startHeartbeatTimer() {
    _heartbeatCheckTimer = Timer.periodic(
      // Maybe a bit long if this is our only way to tell if the engine died
      const Duration(seconds: 10),
      (_) {
        if (!_heartbeatReceived) {
          dispose();
        }

        _heartbeatReceived = false;
      },
    );

    _engineHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final id = getRequestId();

      final heartbeat = Heartbeat(id: id);

      final encoder = JsonUtf8Encoder();

      send(encoder.convert(heartbeat.toJson()) as Uint8List);
    });
  }

  void acknowledgeHeartbeat() {
    _heartbeatReceived = true;
  }

  void send(Uint8List bytes);

  final _messageBuffer = MemoryBlock();

  void onReceive(Uint8List message) {
    if (_onReply == null) return;

    // Append incoming data to the buffer
    _messageBuffer.append(message);

    // Process the buffer to extract complete messages
    while (_messageBuffer.buffer.length >= 8) {
      // Extract the message length (8 bytes, 64-bit integer)
      final byteData = ByteData.sublistView(
        Uint8List.fromList(_messageBuffer.buffer),
      );

      var messageLength = 0;

      if (kIsWeb && !kIsWasm) {
        // Read two 32-bit words and combine safely using BigInt to avoid JS 32-bit shifts.
        final lowOffset = Endian.host == Endian.little ? 0 : 4;
        final highOffset = Endian.host == Endian.little ? 4 : 0;

        final low = byteData.getUint32(lowOffset, Endian.host);
        final high = byteData.getUint32(highOffset, Endian.host);

        final bigLen = (BigInt.from(high) << 32) | BigInt.from(low);

        // Guard against values that exceed JS safe integer range.
        const maxSafe = 0x001F_FFFF_FFFF_FFFF; // 2^53 - 1
        if (bigLen > BigInt.from(maxSafe)) {
          throw StateError(
            'Message length exceeds JS safe integer range: $bigLen',
          );
        }

        messageLength = bigLen.toInt();
      } else {
        messageLength = byteData.getUint64(0, Endian.host);
      }

      // Check if the buffer contains the full message
      if (_messageBuffer.buffer.length >= 8 + messageLength) {
        // Extract the full message
        final messageStart = 8;
        final messageEnd = messageStart + messageLength;
        final fullMessage = _messageBuffer.buffer.sublist(
          messageStart,
          messageEnd,
        );

        Response response;
        try {
          response = Response.fromJson(jsonDecode(utf8.decode(fullMessage)));
        } on FormatException catch (_) {
          // If we can't decode, then something is fatally wrong. This is
          // probably a bug, so we should shut down the engine and report the
          // error.
          dispose();

          rethrow;
        }

        // Handle heartbeat reply
        if (response is HeartbeatReply) {
          acknowledgeHeartbeat();
        } else {
          _onReply(response);
        }

        // Remove the processed message from the buffer
        _messageBuffer.removeRange(0, 8 + messageLength);
      } else {
        // Not enough data for a full message yet
        break;
      }
    }
  }

  void dispose() {
    // Stop the heartbeat check timer
    _heartbeatCheckTimer?.cancel();

    // Stop the timer that sends heartbeat messages to the engine
    _engineHeartbeatTimer?.cancel();

    _heartbeatReceived = false;
  }
}
