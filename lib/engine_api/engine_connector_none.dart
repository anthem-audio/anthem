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

import 'package:anthem/engine_api/engine_connector_base.dart';
import 'package:anthem/engine_api/messages/messages.dart';

class EngineConnector extends EngineConnectorBase {
  EngineConnector(
    int id, {
    required super.kDebugMode,
    void Function(Response)? onReply,
    void Function()? onExit,
    super.noHeartbeat = false,
    String? enginePathOverride,
  }) {
    throw UnimplementedError(
      'EngineConnector is not implemented for this platform.',
    );
  }

  @override
  void send(Uint8List bytes) {
    throw UnimplementedError(
      'EngineConnector is not implemented for this platform.',
    );
  }

  @override
  void dispose() {
    throw UnimplementedError(
      'EngineConnector is not implemented for this platform.',
    );
  }
}
