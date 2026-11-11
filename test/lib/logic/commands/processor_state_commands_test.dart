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

import 'package:anthem/logic/commands/command.dart';
import 'package:anthem/logic/commands/processor_state_commands.dart';
import 'package:anthem/logic/processing_graph_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

class _SnapshotFile {
  final String name;
  int owners = 0;
  _SnapshotFile(this.name);
}

class _Snapshot extends Fake implements ProcessorSnapshot {
  final _SnapshotFile file;
  bool _disposed = false;
  _Snapshot(this.file) {
    file.owners++;
  }

  @override
  String get relativePath => file.name;
  @override
  bool get isDisposed => _disposed;
  @override
  ProcessorSnapshot retain() {
    if (_disposed) throw StateError('Disposed snapshot.');
    return _Snapshot(file);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    file.owners--;
  }
}

class _Graph extends Fake implements ProcessingGraphController {
  _SnapshotFile current;
  final calls = <String>[];
  bool failNextReplace = false;
  bool failNextLoad = false;
  _Graph(this.current);

  @override
  Future<ProcessorSnapshot> replaceSnapshot(
    int nodeId,
    ProcessorSnapshot snapshot,
  ) async {
    calls.add('replace:${snapshot.relativePath}');
    if (failNextReplace) {
      failNextReplace = false;
      throw StateError('State replacement failed.');
    }
    final previous = current;
    current = (snapshot as _Snapshot).file;
    return _Snapshot(previous);
  }

  @override
  Future<void> loadSnapshot(int nodeId, ProcessorSnapshot snapshot) async {
    calls.add('load:${snapshot.relativePath}');
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('State loading failed.');
    }
    if (snapshot.isDisposed) throw StateError('Disposed snapshot.');
    current = (snapshot as _Snapshot).file;
  }

  @override
  void dispose() {}
}

class _Action extends Command {
  final FutureOr<void> Function()? apply;
  final void Function()? undo;
  _Action({this.apply, this.undo});
  @override
  FutureOr<void> execute(ProjectModel project) => apply?.call();
  @override
  void rollback(ProjectModel project) => undo?.call();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;
  late _SnapshotFile before;
  late _SnapshotFile after;
  late _Graph graph;

  setUp(() {
    project = ProjectModel.create();
    before = _SnapshotFile('before');
    after = _SnapshotFile('after');
    graph = _Graph(before);
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(processingGraphControllerService, (_, _) => graph),
      ]),
    );
  });
  tearDown(() async {
    await project.dispose();
    ServiceRegistry.removeProject(project.id);
  });

  LoadProcessorSnapshotCommand command() {
    final snapshot = _Snapshot(after);
    final command = LoadProcessorSnapshotCommand(nodeId: 1, snapshot: snapshot);
    snapshot.dispose();
    return command;
  }

  test(
    'commands own their handles and reuse the original before state for redo',
    () async {
      final load = command();
      expect(after.owners, 1);
      await project.execute(load);
      expect(graph.current, same(after));
      for (var i = 0; i < 2; i++) {
        await project.undo();
        expect(graph.current, same(before));
        await project.redo();
        expect(graph.current, same(after));
      }
      expect(graph.calls, [
        'replace:after',
        'load:before',
        'load:after',
        'load:before',
        'load:after',
      ]);
      expect([before.owners, after.owners], [1, 1]);
      await project.dispose();
      expect([before.owners, after.owners], [0, 0]);
    },
  );

  test(
    'the before state is captured when the queued command actually executes',
    () async {
      final gate = Completer<void>();
      final intermediate = _SnapshotFile('intermediate');
      final earlier = project.execute(
        _Action(
          apply: () async {
            await gate.future;
            graph.current = intermediate;
          },
        ),
      );
      final loading = project.execute(command());
      expect(graph.calls, isEmpty);
      gate.complete();
      await earlier;
      await loading;
      await project.undo();
      expect(graph.current, same(intermediate));
      expect(before.owners, 0);
      expect(intermediate.owners, 1);
    },
  );

  test(
    'failed execution releases the target without adding a history entry',
    () async {
      var priorUndone = false;
      await project.execute(_Action(undo: () => priorUndone = true));
      graph.failNextReplace = true;
      await expectLater(project.execute(command()), throwsStateError);
      expect(graph.current, same(before));
      expect([before.owners, after.owners], [0, 0]);
      await project.undo();
      expect(priorUndone, isTrue);
    },
  );

  test(
    'failed undo and redo retain their history positions and handles for retry',
    () async {
      await project.execute(command());
      graph.failNextLoad = true;
      await expectLater(project.undo(), throwsStateError);
      expect(graph.current, same(after));
      await project.redo();
      expect(graph.calls, ['replace:after', 'load:before']);
      await project.undo();
      expect(graph.current, same(before));
      graph.failNextLoad = true;
      await expectLater(project.redo(), throwsStateError);
      expect(graph.current, same(before));
      await project.redo();
      expect(graph.current, same(after));
      expect([before.owners, after.owners], [1, 1]);
    },
  );

  test(
    'discarded redo and non-history commands release both snapshot handles',
    () async {
      await project.execute(command());
      await project.undo();
      await project.execute(_Action());
      expect([before.owners, after.owners], [0, 0]);
      await project.execute(command(), push: false);
      expect(graph.current, same(after));
      expect([before.owners, after.owners], [0, 0]);
    },
  );
  test(
    'a command rejected by closed history releases its target handle',
    () async {
      await project.dispose();
      final load = command();
      expect(after.owners, 1);
      expect(() => project.execute(load), throwsStateError);
      expect(after.owners, 0);
    },
  );
}
