/*
  Copyright (C) 2023 Joshua Wade

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

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef Handler = void Function(LogicalKeySet shortcut);

class ShortcutProviderController {
  final handlers = <String, Handler>{};
  final globalHandlers = <Handler>[];

  String? activeConsumer;

  final pressedKeys = <LogicalKeyboardKey>{};

  void register({
    required String id,
    required Handler handler,
    bool receiveGlobalShortcuts = false,
  }) {
    handlers[id] = handler;
  }

  void unregister(String id) {
    handlers.remove(id);
  }

  void handleKeyDown(LogicalKeyboardKey key) {
    pressedKeys.add(key);

    final shortcut = LogicalKeySet.fromSet(pressedKeys);

    for (final handler in globalHandlers) {
      handler(shortcut);
    }

    if (activeConsumer == null) return;

    handlers[activeConsumer]!(shortcut);
  }

  void handleKeyUp(LogicalKeyboardKey key) {
    pressedKeys.remove(key);
  }

  void focus(String id) {
    activeConsumer = id;
  }
}
