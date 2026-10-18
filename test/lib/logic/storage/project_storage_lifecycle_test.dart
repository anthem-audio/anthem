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

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class _EngineWithDelayedDisposal extends Engine {
  final shutdown = Completer<void>();
  Future<void>? _disposal;

  _EngineWithDelayedDisposal(ProjectModel project) : super(0, project);

  @override
  Future<void> dispose() => _disposal ??= _disposeAfterShutdown();

  Future<void> _disposeAfterShutdown() async {
    await shutdown.future;
    await super.dispose();
  }
}

const cache = ProjectFileCategory('test cache', isCache: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory parent;
  late ProjectModel project;
  late ProjectStorage storage;
  late ServiceRegistry registry;
  final controller = MainWindowController();

  setUp(() async {
    parent = await Directory.systemTemp.createTemp(
      'anthem_storage_lifecycle_test_',
    );
    project = ProjectModel.create();
    storage = ProjectStorage.temporary(
      categories: [ProjectFileCategory.pluginStates, cache],
    );
    AnthemStore.instance.projects[project.id] = project;
    AnthemStore.instance.projectOrder.add(project.id);
    registry = ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectStorageService, (_, _) => storage),
      ]),
    );
  });

  tearDown(() async {
    final engine = project.engine;
    if (engine is _EngineWithDelayedDisposal && !engine.shutdown.isCompleted) {
      engine.shutdown.complete();
    }
    await controller.closeProjectWithoutSaving(project.id);
    if (storage.isTemporary) await storage.discard();
    await parent.delete(recursive: true);
  });

  test('project closing waits for engine disposal before removing files and services', () async {
    await project.engine.dispose();
    final engine = _EngineWithDelayedDisposal(project);
    project.engine = engine;
    final store = await registry.projectStorage.fileStore;
    final write = await store.beginWrite(ProjectFileCategory.pluginStates);
    final id = await write.commit();
    final read = store.acquireRead(id);
    read.release();
    final cached = await store.beginWrite(cache);
    final cacheId = await cached.commit();
    final cacheRead = store.acquireRead(cacheId);
    final cachePath = cacheRead.path;
    cacheRead.release();

    final closing = controller.closeProjectWithoutSaving(project.id);
    expect(controller.closeProjectWithoutSaving(project.id), same(closing));
    await Future<void>.delayed(Duration.zero);
    expect(await File(read.path).exists(), isTrue);
    expect(await File(cachePath).exists(), isTrue);
    expect(ServiceRegistry.maybeForProject(project.id), same(registry));
    expect(AnthemStore.instance.projects[project.id], same(project));

    engine.shutdown.complete();
    await closing;
    expect(await Directory(storage.rootDirectory).exists(), isFalse);
    expect(ServiceRegistry.maybeForProject(project.id), isNull);
    expect(AnthemStore.instance.projects.containsKey(project.id), isFalse);
  });

  test(
    'failed storage cleanup preserves the project and can be retried',
    () async {
      final store = await registry.projectStorage.fileStore;
      final write = await store.beginWrite(ProjectFileCategory.pluginStates);
      final id = await write.commit();
      final read = store.acquireRead(id);
      await expectLater(
        controller.closeProjectWithoutSaving(project.id),
        throwsStateError,
      );
      expect(await File(read.path).exists(), isTrue);
      expect(ServiceRegistry.maybeForProject(project.id), same(registry));
      expect(AnthemStore.instance.projects[project.id], same(project));
      read.release();
      await controller.closeProjectWithoutSaving(project.id);
      expect(await Directory(storage.rootDirectory).exists(), isFalse);
    },
  );

  test(
    'closing a project that never used storage creates no temporary data',
    () async {
      expect(registry.get<ProjectStorage>(), isNull);
      await controller.closeProjectWithoutSaving(project.id);
      expect(await Directory(storage.rootDirectory).exists(), isFalse);
    },
  );

  test(
    'closing a saved root preserves its document and project files',
    () async {
      storage = ProjectStorage(
        rootDirectory: path.join(parent.path, 'saved project'),
      );
      final store = await registry.projectStorage.fileStore;
      final write = await store.beginWrite(ProjectFileCategory.pluginStates);
      final id = await write.commit();
      final read = store.acquireRead(id);
      read.release();
      final document = await File(
        path.join(storage.rootDirectory, 'project.anthem'),
      ).writeAsString('document');
      await controller.closeProjectWithoutSaving(project.id);
      expect(await document.readAsString(), 'document');
      expect(await File(read.path).exists(), isTrue);
    },
  );
}
