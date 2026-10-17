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
import 'package:anthem/engine_api/visualization_record.dart';
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

  /// Desktop process observations. In-process connectors have no child PID.
  int? get processId => null;
  int? get processExitCode => null;

  /// Releases the connector and waits for any owned process to exit.
  Future<void> shutdown({Duration timeout = const Duration(seconds: 5)}) async {
    dispose();
  }

  /// Should be set to kDebugMode from Flutter, or false if not running in a
  /// Flutter environment.
  ///
  /// kDebugMode comes from Flutter, and we can't import anything from Flutter
  /// into our engine integration tests. Since we use this class to talk to the
  /// engine in our engine integration tests, we need to pass this in.
  final bool kDebugMode;

  final bool noHeartbeat;

  /// Receives every decoded JSON message, including heartbeat responses.
  ///
  /// The receiver dispatches requests, responses, and events.
  final void Function(IpcMessage message)? _onMessage;

  /// Reports that this connector can no longer exchange messages.
  final void Function()? _onConnectionClosed;

  void Function(VisualizationRecord record)? onVisualizationRecord;
  VisualizationRecordConsumer? visualizationRecordConsumer;
  Timer? _visualizationContinuation;
  bool _disposed = false;

  void pollVisualizationRecords() {
    if (_disposed) return;
    try {
      visualizationRecordConsumer?.poll();
      if (visualizationRecordConsumer?.reachedBudget == true &&
          _visualizationContinuation == null) {
        _visualizationContinuation = Timer(Duration.zero, () {
          _visualizationContinuation = null;
          pollVisualizationRecords();
        });
      }
    } catch (error, stackTrace) {
      _log.severe('Failed to read visualization records.', error, stackTrace);
      dispose();
    }
  }

  void handleVisualizationRecord(VisualizationRecord record) {
    try {
      onVisualizationRecord?.call(record);
    } catch (error, stackTrace) {
      _log.severe('Failed to process visualization update.', error, stackTrace);
    }
  }

  late final LengthPrefixedJsonDecoder _messageDecoder;

  EngineConnectorBase({
    required this.kDebugMode,
    required this.noHeartbeat,
    this._onMessage,
    this._onConnectionClosed,
  }) {
    _messageDecoder = LengthPrefixedJsonDecoder(
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
      sendMessage(Heartbeat(id: id));
    });
  }

  void acknowledgeHeartbeat() {
    _heartbeatReceived = true;
  }

  /// Sends a serialized JSON payload using the platform's IPC transport.
  ///
  /// Implementations add transport framing as needed. Callers should use
  /// [sendMessage] to serialize messages and handle send failures.
  void sendBytes(Uint8List bytes);

  /// Called after the engine confirms that it opened the shared memory.
  void finalizeVisualizationSharedMemorySetup();

  void onReceive(Uint8List bytes) {
    if (_disposed) return;

    try {
      _messageDecoder.add(bytes);
    } on FormatException catch (_) {
      // Malformed framing or JSON means the IPC stream can no longer be
      // interpreted reliably. Shut down the connector and surface the error.
      dispose();
      rethrow;
    }
  }

  void _handleDecodedMessage(Object? json) {
    if (_disposed) return;
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'Expected an IPC message to be a JSON object, got '
        '${json.runtimeType}.',
      );
    }

    final message = IpcMessage.fromJson(json);

    try {
      _onMessage?.call(message);
    } catch (error, stackTrace) {
      _log.severe(
        'Unhandled exception while processing engine message '
        '${message.runtimeType}.',
        error,
        stackTrace,
      );
    }
  }

  /// Serializes [message] as JSON and sends it through this connection.
  ///
  /// Messages are ignored after disposal. If serialization or transmission
  /// fails, closes the connector and reports connection closure.
  ///
  /// This method does not schedule requests or wait for responses. Asynchronous
  /// request handlers must retain the connector that received their request so
  /// their response cannot reach a replacement engine connection.
  void sendMessage(IpcMessage message) {
    if (_disposed) return;
    try {
      sendBytes(JsonUtf8Encoder().convert(message.toJson()) as Uint8List);
    } catch (error, stackTrace) {
      _log.severe(
        'Failed to send IPC message ${message.runtimeType}.',
        error,
        stackTrace,
      );
      dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _visualizationContinuation?.cancel();
    _visualizationContinuation = null;
    visualizationRecordConsumer = null;
    // Stop the heartbeat check timer
    _heartbeatCheckTimer?.cancel();

    // Stop the timer that sends heartbeat messages to the engine
    _engineHeartbeatTimer?.cancel();

    _heartbeatReceived = false;
    _onConnectionClosed?.call();
  }
}
