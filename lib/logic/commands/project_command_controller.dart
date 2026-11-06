/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'package:anthem/model/project.dart';
import 'package:mobx/mobx.dart';

import 'command.dart';
import 'journal_commands.dart';

/// Executes project commands and manages their undo/redo lifetime.
///
/// Commands run in submission order. When no operation is pending, synchronous
/// commands run immediately. Discarding a command releases its resources.
/// Execute and push take ownership of submitted commands, including rejection.
class ProjectCommandController {
  final ProjectModel _project;
  final List<Command> _commands = [];
  int _commandPointer = 0;
  List<Command> _undoGroupAccumulator = [];
  bool _undoGroupActive = false;
  Future<void>? _pendingCommands;
  bool _closed = false;
  bool _disposed = false;

  ProjectCommandController(this._project);

  /// Waits for queued command work, including failed operations, to finish.
  Future<void> waitForPendingCommands() => _pendingCommands ?? Future.value();

  Future<void> _runCommand(
    FutureOr<void> Function() operation, {
    Command? command,
  }) {
    if (_closed) {
      command?.dispose();
      throw StateError('Command history is closed.');
    }
    FutureOr<void> run() {
      if (_disposed) {
        command?.dispose();
        throw StateError('The command controller has been disposed.');
      }
      return runInAction(operation);
    }

    final pending = _pendingCommands;
    final result = pending == null ? run() : pending.then((_) => run());
    if (result is! Future<void>) return Future.value();

    // The shared queue tracks completion. Errors belong to the operation's
    // caller and must not propagate into subsequent operations.
    final completion = Completer<void>();
    _pendingCommands = completion.future;
    return result.whenComplete(() {
      if (identical(_pendingCommands, completion.future)) {
        _pendingCommands = null;
      }
      completion.complete();
    });
  }

  /// Executes a command and optionally keeps it for undo and redo.
  ///
  /// A command executed with [push] set to false is disposed after execution.
  Future<void> execute(Command command, {bool push = true}) => _runCommand(() {
    void finish() {
      if (push) {
        _pushCommand(command);
      } else {
        command.dispose();
      }
      _project.isDirty = true;
    }

    try {
      final result = command.execute(_project);
      if (result is Future<void>) {
        return result.then(
          (_) => runInAction(finish),
          onError: (Object error, StackTrace stack) {
            command.dispose();
            Error.throwWithStackTrace(error, stack);
          },
        );
      }
      finish();
    } catch (_) {
      command.dispose();
      rethrow;
    }
  }, command: command);

  /// Adds an already applied command to history, or executes it first.
  Future<void> push(Command command, {bool execute = false}) {
    if (execute) return this.execute(command);
    return _runCommand(() {
      _pushCommand(command);
      _project.isDirty = true;
    }, command: command);
  }

  void _pushCommand(Command command) {
    if (_undoGroupActive) {
      _undoGroupAccumulator.add(command);
    } else {
      _appendToHistory(command);
    }
  }

  void _appendToHistory(Command command) {
    for (final discarded in _commands.skip(_commandPointer)) {
      discarded.dispose();
    }
    _commands.removeRange(_commandPointer, _commands.length);
    _commands.add(command);
    _commandPointer++;
  }

  void _assertUndoGroupInactive() {
    if (_undoGroupActive) {
      throw AssertionError("Journal page was active but shouldn't have been.");
    }
  }

  /// Undoes the last command, waiting for any required state capture.
  Future<void> undo() => _runCommand(() {
    if (_commandPointer == 0) return null;
    _assertUndoGroupInactive();
    final result = _commands[_commandPointer - 1].rollback(_project);
    void finish() {
      _commandPointer--;
      _project.isDirty = true;
    }

    if (result is Future<void>) {
      return result.then((_) => runInAction(finish));
    }
    finish();
  });

  /// Redoes the next command, waiting for any required state capture.
  Future<void> redo() => _runCommand(() {
    if (_commandPointer == _commands.length) return null;
    _assertUndoGroupInactive();
    final result = _commands[_commandPointer].execute(_project);
    void finish() {
      _commandPointer++;
      _project.isDirty = true;
    }

    if (result is Future<void>) {
      return result.then((_) => runInAction(finish));
    }
    finish();
  });

  /// Starts grouping commands into one undo/redo action.
  Future<void> startUndoGroup() => _runCommand(() {
    _undoGroupActive = true;
  });

  /// Transfers the commands in the open group to the undo/redo history.
  Future<void> commitUndoGroup() => _runCommand(() {
    if (!_undoGroupActive) return;
    final accumulator = _undoGroupAccumulator;
    _undoGroupAccumulator = [];
    _undoGroupActive = false;
    if (accumulator.isEmpty) return;

    _appendToHistory(
      accumulator.length == 1
          ? accumulator.first
          : JournalPageCommand(accumulator),
    );
  });

  /// Stops accepting commands, waits for pending work, and disposes history.
  ///
  /// Call before closing project storage so commands can release their files.
  Future<void> close() async {
    _closed = true;
    await waitForPendingCommands();
    dispose();
  }

  /// Disposes all commands, including those in an unfinished group.
  ///
  /// Pending work must finish first; [close] waits for it before disposal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    for (final command in _commands.followedBy(_undoGroupAccumulator)) {
      command.dispose();
    }
    _commands.clear();
    _undoGroupAccumulator.clear();
    _commandPointer = 0;
  }
}
