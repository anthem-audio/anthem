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

import 'dart:async';

/// Defines a unit of work that happens as a microtask; if multiple calls to
/// [execute] are made before the action is executed, the action will only
/// happen once.
class MicrotaskDebouncedAction {
  final void Function() action;
  Future<void>? _future;

  MicrotaskDebouncedAction(this.action);

  /// Executes the action after the specified delay.
  void execute() async {
    if (_future != null) {
      return;
    }

    _future = Future.microtask(_performAction);
  }

  void _performAction() {
    action();
    _future = null;
  }
}
