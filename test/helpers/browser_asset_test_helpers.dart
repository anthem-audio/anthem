/*
  Copyright (C) 2026 Joshua Wade

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

import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// Flutter's Chrome test server serves package files but does not build an
/// asset bundle. Route package-asset requests through its package-file handler
/// so tests load the same checked-in scripts as application builds.
void useBrowserPackageAssets() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(Uint8List.sublistView(message!));
    if (!key.startsWith('packages/')) return null;
    final response = await web.window.fetch('/$key'.toJS).toDart;
    if (!response.ok) return null;
    return ByteData.view((await response.arrayBuffer().toDart).toDart);
  });
  addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
}
