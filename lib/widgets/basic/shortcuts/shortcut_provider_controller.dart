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
  final globalHandlers = <String, Handler>{};

  String? activeConsumer;

  final pressedKeys = <LogicalKeyboardKey>{};

  /// Registers a handler. This handler will receive shortcuts if it is marked
  /// as the active consumer via [activeConsumer].
  void register({
    required String id,
    required Handler handler,
    bool global = false,
  }) {
    if (global) {
      globalHandlers[id] = handler;
    } else {
      handlers[id] = handler;
    }
  }

  /// Unregisters the handler with the given ID.
  void unregister(String id) {
    handlers.remove(id);
    globalHandlers.remove(id);
  }

  /// The associated [ShortcutProvider] should call this function when it
  /// receives a key down event.
  void handleKeyDown(LogicalKeyboardKey key) {
    pressedKeys.add(key);

    final shortcut = LogicalKeySet.fromSet(pressedKeys);

    for (final handler in globalHandlers.values) {
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

/// Mixin to check if two shortcuts match.
extension ShortcutMatchesMixin on LogicalKeySet {
  /// Checks if two shortcuts match.
  ///
  /// [LogicalKeySet] has an equality check, but two shortcuts will not be equal
  /// if they specify different keys that should be equivalent, such as
  /// controlLeft and controlRight.
  bool matches(LogicalKeySet other) {
    final normalizedThis = <LogicalKeyboardKey>{};
    final normalizedOther = <LogicalKeyboardKey>{};

    void add(LogicalKeySet source, Set<LogicalKeyboardKey> container) {
      for (final key in source.keys) {
        if (key == LogicalKeyboardKey.control ||
            key == LogicalKeyboardKey.controlLeft ||
            key == LogicalKeyboardKey.controlRight) {
          container.add(LogicalKeyboardKey.control);
          continue;
        }

        if (key == LogicalKeyboardKey.alt ||
            key == LogicalKeyboardKey.altLeft ||
            key == LogicalKeyboardKey.altRight) {
          container.add(LogicalKeyboardKey.alt);
          continue;
        }

        if (key == LogicalKeyboardKey.shift ||
            key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.shiftRight) {
          container.add(LogicalKeyboardKey.shift);
          continue;
        }

        if (key == LogicalKeyboardKey.meta ||
            key == LogicalKeyboardKey.metaLeft ||
            key == LogicalKeyboardKey.metaRight) {
          container.add(LogicalKeyboardKey.meta);
          continue;
        }

        container.add(key);
      }
    }

    add(this, normalizedThis);
    add(other, normalizedOther);

    return LogicalKeySet.fromSet(normalizedThis) ==
        LogicalKeySet.fromSet(normalizedOther);
  }
}
