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

import 'package:flutter/services.dart';

typedef RawKeyEventListener = bool Function(KeyEvent event);

/// Singleton to listen for raw keyboard events globally.
///
/// We used to listen per ShortcutProvider, but this caused intermittent issues
/// during development after hot restarts.
class RawKeyEventSingleton {
  static final RawKeyEventSingleton instance = RawKeyEventSingleton._internal();

  RawKeyEventSingleton._internal() {
    ServicesBinding.instance.keyboard.addHandler(_dispatchEvent);
  }

  final Set<RawKeyEventListener> _listeners = {};

  void addListener(RawKeyEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(RawKeyEventListener listener) {
    _listeners.remove(listener);
  }

  bool _dispatchEvent(KeyEvent event) {
    var handled = false;
    for (final listener in _listeners) {
      if (listener(event)) {
        handled = true;
        break;
      }
    }
    return handled;
  }
}
