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

/// Controller for a [ShortcutProvider]. [ShortcutProvider] is rendered at the
/// root of every project, and a controller instance is provided to the tree
/// via [Provider]. This fact is used by [ShortcutConsumer] widgets to
class ShortcutProviderController {
  final handlers = <String, Handler>{};
  final globalHandlers = <Handler>[];

  String? activeConsumer;

  final pressedKeys = <LogicalKeyboardKey>{};

  /// Registers a handler. This handler will receive shortcuts if it is marked
  /// as the active consumer via [activeConsumer].
  void register({
    required String id,
    required Handler handler,
    bool receiveGlobalShortcuts = false,
  }) {
    handlers[id] = handler;
  }

  /// Unregisters the handler with the given ID.
  void unregister(String id) {
    handlers.remove(id);
  }

  /// The associated [ShortcutProvider] should call this function when it
  /// receives a key down event.
  void handleKeyDown(LogicalKeyboardKey key) {
    pressedKeys.add(key);

    final shortcut = LogicalKeySet.fromSet(pressedKeys);

    for (final handler in globalHandlers) {
      handler(shortcut);
    }

    if (activeConsumer == null) return;

    handlers[activeConsumer]!(shortcut);
  }

  /// The associated [ShortcutProvider] should call this function when it
  /// receives a key up event.
  void handleKeyUp(LogicalKeyboardKey key) {
    pressedKeys.remove(key);
  }

  /// Marks the given consumer as active. This consumer will receive shortcut
  /// events.
  void focus(String id) {
    activeConsumer = id;
  }
}
