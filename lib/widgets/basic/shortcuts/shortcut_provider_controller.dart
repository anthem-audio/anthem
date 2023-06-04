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

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef RawKeyHandler = bool Function(KeyEvent keyEvent);
typedef ShortcutHandler = void Function(LogicalKeySet shortcut);

/// Controller for a [ShortcutProvider]. [ShortcutProvider] is rendered at the
/// root of every project, and a controller instance is provided to the tree via
/// [Provider]. [ShortcutConsumer] widgets can then access this provider to
/// subscribe to high-level shortcut events, as well as to raw key events.
class ShortcutProviderController {
  final rawHandlers = <String, RawKeyHandler>{};
  final globalShortcutHandlers = <String, ShortcutHandler>{};
  final shortcutHandlers = <String, ShortcutHandler>{};

  String? activeConsumer;

  final pressedKeys = <LogicalKeyboardKey>{};

  /// Registers a shortcut handler. This handler will receive shortcuts if it is
  /// marked as the active consumer via [activeConsumer].
  void registerShortcutHandler({
    required String id,
    required ShortcutHandler handler,
    bool global = false,
  }) {
    if (global) {
      globalShortcutHandlers[id] = handler;
    } else {
      shortcutHandlers[id] = handler;
    }
  }

  /// Unregisters the shortcut handler with the given ID.
  void unregisterShortcutHandler(String id) {
    shortcutHandlers.remove(id);
    globalShortcutHandlers.remove(id);
  }

  /// Registers a raw key handler.
  ///
  /// Raw key handlers receive raw key events. These handlers are processed
  /// before shortcut handlers. Raw key handlers must return a value indicating
  /// if the key event has been handled. If the event has been handled, then it
  /// will not be processed as part of a shortcut.
  void registerRawKeyHandler({
    required String id,
    required RawKeyHandler handler,
  }) {
    rawHandlers[id] = handler;
  }

  /// Unregisters a raw key handler.
  void unregisterRawKeyHandler(String id) {
    rawHandlers.remove(id);
  }

  /// The associated [ShortcutProvider] will call this function when it
  /// receives a key down event.
  void handleKeyDown(KeyEvent event) {
    var handled = false;

    for (final handler in rawHandlers.values) {
      handled = handled || handler(event);
    }

    if (handled) return;

    pressedKeys.add(event.logicalKey);

    final shortcut = LogicalKeySet.fromSet(pressedKeys);

    for (final handler in globalShortcutHandlers.values) {
      handler(shortcut);
    }

    if (activeConsumer == null) return;

    shortcutHandlers[activeConsumer]!(shortcut);
  }

  /// The associated [ShortcutProvider] will call this function when it receives
  /// a key up event.
  void handleKeyUp(KeyEvent event) {
    var handled = false;

    for (final handler in rawHandlers.values) {
      handled = handled || handler(event);
    }

    if (handled) return;

    pressedKeys.remove(event.logicalKey);
  }

  /// Marks the given consumer as active. This consumer will receive shortcut
  /// events.
  void setActiveConsumer(String id) {
    activeConsumer = id;
  }
}

/// This class allows behaviors to be attached to specific shortcuts. Incoming
/// shortcuts can be sent to this class, and a matching behavior will be called
/// if it exists.
class ShortcutBehaviors {
  final _behaviors = <String, void Function()>{};

  void register(LogicalKeySet shortcut, void Function() behavior) {
    _behaviors[_getShortcutID(shortcut)] = behavior;
  }

  void handleShortcut(LogicalKeySet shortcut) {
    _behaviors[_getShortcutID(shortcut)]?.call();
  }

  String _getShortcutID(LogicalKeySet shortcut) {
    return shortcut.keys
        .map((key) {
          if (key == LogicalKeyboardKey.control ||
              key == LogicalKeyboardKey.controlLeft ||
              key == LogicalKeyboardKey.controlRight) {
            return LogicalKeyboardKey.control.toString();
          } else if (key == LogicalKeyboardKey.alt ||
              key == LogicalKeyboardKey.altLeft ||
              key == LogicalKeyboardKey.altRight) {
            return LogicalKeyboardKey.alt.toString();
          } else if (key == LogicalKeyboardKey.shift ||
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight) {
            return LogicalKeyboardKey.shift.toString();
          } else {
            return key.toString();
          }
        })
        .sorted((a, b) => a.compareTo(b))
        .join('-');
  }
}

/// Extension method to check if two shortcuts match.
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
