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

typedef Handler = void Function();

class ShortcutProviderController {
  final handlers = <String, Handler>{};
  final shortcuts = <String, List<LogicalKeySet>>{};

  String? activeConsumer;

  final pressedKeys = LogicalKeySet.fromSet(const {});

  void register({
    required String key,
    required Handler handler,
    bool receiveGlobalShortcuts = false,
  }) {
    handlers[key] = handler;
    shortcuts[key] = [];
  }

  void unregister(String key) {
    handlers.remove(key);
    shortcuts.remove(key);
  }

  void addShortcut({required String key, required LogicalKeySet shortcut}) {
    shortcuts[key]!.add(shortcut);
  }

  void addGlobalShortcut(
      {required String key, required LogicalKeySet shortcut}) {
    // TODO: Implement
  }

  void removeShortcut({required String key, required LogicalKeySet shortcut}) {
    shortcuts[key]!.removeWhere(
      (element) =>
          element.keys.intersection(shortcut.keys).length ==
          element.keys.length,
    );
  }

  void removeGlobalShortcut(
      {required String key, required LogicalKeySet shortcut}) {
    // TODO: Implement
  }

  void handleKeyDown(LogicalKeyboardKey key) {
    pressedKeys.keys.add(key);
  }

  void handleKeyUp(LogicalKeyboardKey key) {
    pressedKeys.keys.remove(key);
  }
}
