/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

class _Command extends Command {
  FutureOr<void> Function()? onExecute;
  FutureOr<void> Function()? onRollback;
  int executions = 0;
  int rollbacks = 0;
  int disposals = 0;

  @override
  FutureOr<void> execute(ProjectModel project) {
    executions++;
    return onExecute?.call();
  }

  @override
  FutureOr<void> rollback(ProjectModel project) {
    rollbacks++;
    return onRollback?.call();
  }

  @override
  void dispose() {
    disposals++;
  }
}

class _EngineWithControlledDisposal extends Engine {
  final shutdown = Completer<void>();
  final disposalStarted = Completer<void>();
  int disposalAttempts = 0;
  bool failNextDisposal = false;

  _EngineWithControlledDisposal(ProjectModel project)
    : super(project.engineID, project);

  @override
  Future<void> dispose() async {
    disposalAttempts++;
    if (!disposalStarted.isCompleted) disposalStarted.complete();
    if (failNextDisposal) {
      failNextDisposal = false;
      throw StateError('Engine shutdown failed.');
    }
    await shutdown.future;
    await super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;

  setUp(() {
    project = ProjectModel.create();
  });
  tearDown(() async {
    await project.dispose();
  });

  test('synchronous commands apply immediately and survive undo and redo', () {
    final command = _Command();
    project.execute(command);
    expect(command.executions, 1);
    project.undo();
    expect(command.rollbacks, 1);
    project.redo();
    expect(command.executions, 2);
    expect(command.disposals, 0);
  });

  test('a new branch disposes only the discarded redo commands', () async {
    final kept = _Command();
    final discarded = _Command();
    project.execute(kept);
    project.execute(discarded);
    project.undo();
    project.execute(_Command());
    expect(kept.disposals, 0);
    expect(discarded.disposals, 1);
    await project.dispose();
    expect(kept.disposals, 1);
    expect(discarded.disposals, 1);
  });

  test(
    'group commit transfers ownership and discarded groups dispose children',
    () {
      final first = _Command();
      final second = _Command();
      project.startUndoGroup();
      project.execute(first);
      project.execute(second);
      project.commitUndoGroup();
      expect([first.disposals, second.disposals], [0, 0]);
      project.undo();
      project.execute(_Command());
      expect([first.disposals, second.disposals], [1, 1]);
    },
  );

  test('closing a project disposes an unfinished group', () async {
    final command = _Command();
    project.startUndoGroup();
    project.execute(command);
    await project.dispose();
    await project.dispose();
    expect(command.disposals, 1);
  });

  test(
    'non-history execution and failed execution dispose their commands',
    () async {
      final transient = _Command();
      await project.execute(transient, push: false);
      expect(transient.disposals, 1);
      final failed = _Command()
        ..onExecute = () => Future.error(StateError('failed'));
      await expectLater(project.execute(failed), throwsStateError);
      expect(failed.disposals, 1);
      project.undo();
      expect(transient.rollbacks, 0);
      expect(failed.rollbacks, 0);
    },
  );

  test(
    'failed async undo keeps its position and queued redo waits for retry',
    () async {
      final capture = Completer<void>();
      final command = _Command()..onRollback = () => capture.future;
      project.execute(command);
      final undo = project.undo();
      final failure = expectLater(undo, throwsStateError);
      capture.completeError(StateError('capture failed'));
      await failure;
      expect(command.disposals, 0);
      final retry = Completer<void>();
      command.onRollback = () => retry.future;
      final undoAgain = project.undo();
      final redo = project.redo();
      expect(command.executions, 1);
      retry.complete();
      await undoAgain;
      await redo;
      expect(command.rollbacks, 2);
      expect(command.executions, 2);
    },
  );

  test(
    'group actions wait for each child and preserve reverse undo order',
    () async {
      final events = <String>[];
      final capture = Completer<void>();
      final first = _Command()
        ..onRollback = () {
          events.add('first');
        };
      final second = _Command()
        ..onRollback = () async {
          events.add('second capture');
          await capture.future;
          events.add('second remove');
        };
      project.startUndoGroup();
      project.execute(first);
      project.execute(second);
      project.commitUndoGroup();
      final undo = project.undo();
      expect(events, ['second capture']);
      capture.complete();
      await undo;
      expect(events, ['second capture', 'second remove', 'first']);
    },
  );

  test(
    'project disposal waits for pending commands before disposing their claims',
    () async {
      final pending = Completer<void>();
      final command = _Command()..onExecute = () => pending.future;
      final execution = project.execute(command);
      final closing = project.dispose();
      expect(command.disposals, 0);
      expect(() => project.execute(_Command()), throwsStateError);
      pending.complete();
      await execution;
      await closing;
      expect(command.disposals, 1);
    },
  );

  test('project disposal finishes commands before stopping the engine and shares completion', () async {
    await project.engine.dispose();
    final engine = _EngineWithControlledDisposal(project);
    project.engine = engine;
    addTearDown(() {
      if (!engine.shutdown.isCompleted) engine.shutdown.complete();
    });
    final pending = Completer<void>();
    final command = _Command()..onExecute = () => pending.future;
    final execution = project.execute(command);
    final closing = project.dispose();
    expect(project.dispose(), same(closing));
    expect(engine.disposalAttempts, 0);
    expect(command.disposals, 0);
    expect(() => project.execute(_Command()), throwsStateError);
    var completed = false;
    unawaited(closing.then((_) => completed = true));
    pending.complete();
    await execution;
    await engine.disposalStarted.future;
    expect(command.disposals, 1);
    expect(completed, isFalse);
    engine.shutdown.complete();
    await closing;
    expect(completed, isTrue);
    expect(project.dispose(), same(closing));
    expect(engine.disposalAttempts, 1);
  });

  test('project disposal can retry failed engine shutdown without disposing commands twice', () async {
    await project.engine.dispose();
    final engine = _EngineWithControlledDisposal(project)
      ..failNextDisposal = true;
    project.engine = engine;
    addTearDown(() {
      if (!engine.shutdown.isCompleted) engine.shutdown.complete();
    });
    final command = _Command();
    await project.execute(command);
    final failed = project.dispose();
    await expectLater(failed, throwsStateError);
    expect(command.disposals, 1);
    expect(() => project.execute(_Command()), throwsStateError);
    engine.shutdown.complete();
    final retried = project.dispose();
    expect(retried, isNot(same(failed)));
    await retried;
    expect(command.disposals, 1);
    expect(engine.disposalAttempts, 2);
  });

  test('reopening a project starts with its own empty command history', () {
    final originalCommand = _Command();
    project.execute(originalCommand);
    final reopened = ProjectModel.fromJson(project.toJson());
    addTearDown(reopened.dispose);
    reopened.undo();
    expect(originalCommand.rollbacks, 0);
    final reopenedCommand = _Command();
    reopened.execute(reopenedCommand);
    reopened.undo();
    expect(reopenedCommand.rollbacks, 1);
    project.undo();
    expect(originalCommand.rollbacks, 1);
    expect(reopenedCommand.rollbacks, 1);
  });
  test(
    'closed history disposes commands rejected by execute and push',
    () async {
      await project.dispose();
      final execution = _Command();
      expect(() => project.execute(execution), throwsStateError);
      expect(execution.disposals, 1);
      final pushed = _Command();
      expect(() => project.push(pushed), throwsStateError);
      expect(pushed.disposals, 1);
    },
  );
}
