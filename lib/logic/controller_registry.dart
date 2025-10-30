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

import 'package:anthem/logic/main_window_controller.dart';

/// A registry for storing and retrieving controllers by key.
///
/// Unless otherwise necessary, controllers are registered here by project ID.
/// For example, the arranger controller for each project is just registered
/// under that project's ID.
class ControllerRegistry {
  MainWindowController? mainWindowController;

  static final ControllerRegistry instance = ControllerRegistry._internal();

  ControllerRegistry._internal();

  final Map<(Type, String), dynamic> _controllers = {};

  void registerController<T>(String key, T controller) {
    if (T == dynamic) {
      throw Exception('Cannot register controller of type dynamic');
    }

    if (_controllers.containsKey((T, key))) {
      throw Exception(
        'Controller of type $T with key $key is already registered',
      );
    }

    _controllers[(T, key)] = controller;
  }

  T? getController<T>(String key) {
    if (T == dynamic) {
      throw Exception('Cannot get controller of type dynamic');
    }

    final controller = _controllers[(T, key)];
    if (controller is T) {
      return controller;
    }
    return null;
  }

  void unregisterController<T>(String key) {
    if (T == dynamic) {
      throw Exception('Cannot unregister controller of type dynamic');
    }

    _controllers.remove((T, key));
  }
}
