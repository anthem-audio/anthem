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

/// Executes [action] immediately if it has never run before or if at least
/// [cooldown] has elapsed since the last run.
///
/// If `execute()` is called *again* during the cooldown window, the action
/// is guaranteed to run once more — as soon as the remaining cooldown time
/// has passed — but it will not be scheduled repeatedly for every call.
class TimerDebouncedAction {
  TimerDebouncedAction(this.action, this.cooldown);

  /// The work to perform.
  final void Function() action;

  /// Minimum time that must elapse between two executions.
  final Duration cooldown;

  DateTime? _lastRun; // When the action actually ran last.
  Timer? _pendingTimer; // One pending run, if needed.

  /// Request that the action execute, observing the debounce rules.
  void execute() {
    final now = DateTime.now();

    // First run ever, or outside the cooldown window → run immediately.
    if (_lastRun == null || now.difference(_lastRun!) >= cooldown) {
      _run(now);
      return;
    }

    // We’re inside the cooldown window. If nothing is already scheduled,
    // queue exactly one run for the earliest legal moment.
    if (_pendingTimer == null || !_pendingTimer!.isActive) {
      final remaining = cooldown - now.difference(_lastRun!);
      _pendingTimer = Timer(remaining, () => _run(DateTime.now()));
    }
  }

  /// Cancels any scheduled run and releases resources.
  void dispose() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  void _run(DateTime timestamp) {
    _pendingTimer?.cancel();
    _pendingTimer = null;

    _lastRun = timestamp;
    action();
  }
}
