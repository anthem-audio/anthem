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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anthem/engine_api/length_prefixed_json_decoder.dart';
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:logging/logging.dart';

final _log = Logger('engine_connector');

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

  late final LengthPrefixedJsonDecoder _responseDecoder;

  EngineConnectorBase({
    required this.kDebugMode,
    required this.noHeartbeat,
    this._onReply,
  }) {
    _responseDecoder = LengthPrefixedJsonDecoder(
      onMessage: _handleDecodedMessage,
    );
  }

  void startHeartbeatTimer() {
    _heartbeatCheckTimer = Timer.periodic(
      // Maybe a bit long if this is our only way to tell if the engine died
      const Duration(seconds: 10),
      (_) {
        if (!_heartbeatReceived) {
          _log.warning(
            'Engine heartbeat reply was not received within 10 seconds. '
            'Disposing engine connector.',
          );
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

  void onReceive(Uint8List bytes) {
    if (_onReply == null) return;

    try {
      _responseDecoder.add(bytes);
    } on FormatException catch (_) {
      // Malformed framing or JSON means the IPC stream can no longer be
      // interpreted reliably. Shut down the connector and surface the error.
      dispose();
      rethrow;
    }
  }

  void _handleDecodedMessage(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'Expected an engine response to be a JSON object, got '
        '${json.runtimeType}.',
      );
    }

    final response = Response.fromJson(json);

    if (response is HeartbeatReply) {
      acknowledgeHeartbeat();
      return;
    }

    try {
      _onReply?.call(response);
    } catch (error, stackTrace) {
      _log.severe(
        'Unhandled exception while processing engine response '
        '${response.runtimeType}.',
        error,
        stackTrace,
      );
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
