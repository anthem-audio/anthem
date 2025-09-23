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

import 'dart:typed_data';

import 'package:anthem/engine_api/engine_emscripten_interface.dart';
import 'package:anthem/engine_api/engine_connector_base.dart';

class EngineConnector extends EngineConnectorBase {
  late EngineEmscriptenInterface engineInterface = EngineEmscriptenInterface(
    'AnthemEngine',
    onMessageReceived: (bytes) {
      onReceive(bytes);
    },
  );

  bool _isInitialized = false;

  final List<Uint8List> _pendingMessages = [];

  EngineConnector(
    int id, {
    required super.kDebugMode,
    super.onReply,
    void Function()? onExit,
    super.noHeartbeat = false,
    String? enginePathOverride,
  }) {
    onInit = engineInterface.init().then((_) {
      _init();
      return true;
    });
  }

  void _init() {
    for (var message in _pendingMessages) {
      send(message);
    }
    _pendingMessages.clear();

    startHeartbeatTimer();

    _isInitialized = true;

    for (var message in _pendingMessages) {
      send(message);
    }
  }

  @override
  void send(Uint8List bytes) {
    if (!_isInitialized) {
      _pendingMessages.add(bytes);
      return;
    }

    // Send the length of the request
    final bytesList = Uint64List(1);
    bytesList[0] = bytes.length;
    engineInterface.sendMessage(bytesList.buffer.asUint8List());

    engineInterface.sendMessage(bytes);
  }
}
