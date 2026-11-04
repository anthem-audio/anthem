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

import 'dart:convert';
import 'dart:io';

import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const pluginStates = ProjectAssetCategory.pluginStates;
const cache = ProjectAssetCategory('test cache', isCache: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late ProjectStorage storage;
  late ProjectModel project;

  setUp(() async {
    project = ProjectModel.create();
    parent = await Directory.systemTemp.createTemp(
      'anthem_project_storage_test_',
    );
    storage = ProjectStorage(
      rootDirectory: path.join(parent.path, 'project'),
      project: project,
    );
  });

  tearDown(() async {
    await project.dispose();
    await storage.close();
    await parent.delete(recursive: true);
  });

  test('an unused explicit root is never created', () async {
    await storage.close();
    expect(await parent.list().toList(), isEmpty);
    expect(() => storage.assetStore, throwsStateError);
  });

  test(
    'a prepared temporary directory is adopted and its files are discovered',
    () async {
      final directory = await Directory(path.join(parent.path, 'prepared'))
          .create();
      final file = File(path.join(directory.path, 'plugin states', '1.bin'));
      await file.parent.create();
      await file.writeAsBytes([1, 2, 3]);
      final node = NodeModel.create(idAllocator: project.idAllocator)
        ..processorStateRetentionId = 'restored-claim';
      project.fileRetentions = jsonEncode({
        'restored-claim': 'plugin states/1.bin',
      });
      project.processingGraph.addNode(node);
      final temporary = ProjectStorage.temporary(
        project: project,
        rootDirectory: directory.path,
      );
      try {
        final store = await temporary.assetStore;
        expect(store.projectAssetPaths, ['plugin states/1.bin']);
        final snapshot = (await temporary.references).snapshot();
        expect(
          await File(snapshot.reads.values.single.absolutePath).readAsBytes(),
          [1, 2, 3],
        );
        await snapshot.close();
      } finally {
        await temporary.discard();
      }
      expect(await directory.exists(), isFalse);
    },
  );

  test(
    'discard removes an adopted temporary directory before storage opens',
    () async {
      final directory = await Directory(path.join(parent.path, 'prepared'))
          .create();
      await File(path.join(directory.path, 'data')).writeAsString('prepared');
      await ProjectStorage.temporary(
        project: project,
        rootDirectory: directory.path,
      ).discard();
      expect(await directory.exists(), isFalse);
    },
  );

  test(
    'reference initialization can be retried using the already opened store',
    () async {
      final node = NodeModel.create(idAllocator: project.idAllocator)
        ..processorStateRetentionId = 'missing-claim';
      project.fileRetentions = jsonEncode({
        'missing-claim': 'plugin states/missing.bin',
      });
      project.processingGraph.addNode(node);
      await expectLater(storage.assetStore, throwsStateError);
      // Reopening the same directory would fail: the first attempt owns its store.
      // Removing the invalid model reference lets that store finish initialization.
      node.processorStateRetentionId = null;
      project.fileRetentions = '{}';
      final store = await storage.assetStore;
      expect(store.rootDirectory, storage.rootDirectory);
    },
  );

  test(
    'explicit roots preserve project data and clean up cache categories',
    () async {
      storage = ProjectStorage(
        project: project,
        rootDirectory: storage.rootDirectory,
        categories: [pluginStates, cache],
      );
      final store = await storage.assetStore;
      final scopeId = store.openScope();
      final write = await store.beginWrite(
        scopeId,
        pluginStates.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      await File(write.absolutePath).writeAsString('plugin state');
      final relativePath = await store.commitWrite(scopeId, write.token);
      final decoded = await store.beginWrite(
        scopeId,
        cache.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      final cacheRelativePath = await store.commitWrite(scopeId, decoded.token);
      expect(
        () => storage.retainAssetForProject(cacheRelativePath),
        throwsStateError,
      );
      final cacheRead = store.acquireRead(scopeId, cacheRelativePath);
      store.releaseRead(scopeId, cacheRead.token);
      expect(await storage.assetStore, same(store));
      expect(store.projectAssetPaths, [relativePath]);
      final read = store.acquireRead(scopeId, relativePath);
      store.releaseRead(scopeId, read.token);
      // Ending one engine's access leaves files available to its replacement.
      expect(await File(read.absolutePath).exists(), isTrue);
      expect(await File(cacheRead.absolutePath).exists(), isTrue);
      await store.closeScope(scopeId);
      await storage.close();
      expect(await File(read.absolutePath).exists(), isTrue);
      expect(await File(cacheRead.absolutePath).exists(), isFalse);
      expect(() => storage.discard(), throwsStateError);
      final recovered = await ProjectAssetStore.open(
        storage.rootDirectory,
        categories: storage.categories,
      );
      expect(recovered.relativePaths, [relativePath]);
      await recovered.close();
    },
  );

  test(
    'temporary roots are lazy and can be kept for recovery before discard',
    () async {
      final temporary = ProjectStorage.temporary(project: project);
      final unused = ProjectStorage.temporary(project: project);
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
      await unused.discard();
      expect(await Directory(unused.rootDirectory).exists(), isFalse);
      try {
        final store = await temporary.assetStore;
        final scopeId = store.openScope();
        final write = await store.beginWrite(
          scopeId,
          pluginStates.directoryName,
        );
        final relativePath = await store.commitWrite(scopeId, write.token);
        await store.closeScope(scopeId);
        await temporary.close();
        final recovered = await ProjectAssetStore.open(
          temporary.rootDirectory,
          categories: temporary.categories,
        );
        expect(recovered.relativePaths, [relativePath]);
        await recovered.close();
        final another = ProjectStorage.temporary(project: project);
        await another.assetStore;
        await another.discard();
        expect(await Directory(temporary.rootDirectory).exists(), isTrue);
      } finally {
        await temporary.discard();
      }
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    },
  );

  test('discard waits for initialization and an in-flight write', () async {
    final temporary = ProjectStorage.temporary(project: project);
    final opening = temporary.assetStore;
    final store = await opening;
    final scopeId = store.openScope();
    final write = await store.beginWrite(scopeId, pluginStates.directoryName);
    final committing = store.commitWrite(scopeId, write.token);
    final ending = store.closeScope(scopeId);
    final closing = ending.then((_) => temporary.discard());
    await committing;
    await closing;
    expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    expect(() => temporary.assetStore, throwsStateError);
  });

  test('close waits for initialization already in progress', () async {
    final opening = storage.assetStore;
    final closing = storage.close();
    final store = await opening;
    await closing;
    expect(await Directory(store.rootDirectory).exists(), isTrue);
    expect(() => store.openScope(), throwsStateError);
  });

  test(
    'temporary cleanup preserves data until live access is released',
    () async {
      final temporary = ProjectStorage.temporary(project: project);
      final store = await temporary.assetStore;
      final scopeId = store.openScope();
      final write = await store.beginWrite(scopeId, pluginStates.directoryName);
      final relativePath = await store.commitWrite(scopeId, write.token);
      final read = store.acquireRead(scopeId, relativePath);
      await expectLater(temporary.discard(), throwsStateError);
      expect(await File(read.absolutePath).exists(), isTrue);
      await store.closeScope(scopeId);
      await temporary.discard();
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    },
  );

  test(
    'failed initialization can be retried after its cause is fixed',
    () async {
      final blocker = await File(storage.rootDirectory)
          .writeAsString('not a directory');
      await expectLater(
        storage.assetStore,
        throwsA(isA<FileSystemException>()),
      );
      await blocker.delete();
      final store = await storage.assetStore;
      final scopeId = store.openScope();
      expect(store.relativePaths, isEmpty);
      await store.closeScope(scopeId);
    },
  );

  test(
    'failed initialization leaves explicit roots and unrelated data intact',
    () async {
      final unrelated = await File(path.join(parent.path, 'other.anthem'))
          .writeAsString('keep');
      final blocker = await File(storage.rootDirectory)
          .writeAsString('keep too');
      await expectLater(
        storage.assetStore,
        throwsA(isA<FileSystemException>()),
      );
      await storage.close();
      expect(await unrelated.readAsString(), 'keep');
      expect(await blocker.readAsString(), 'keep too');
    },
  );

  test(
    'failed temporary initialization can discard its incomplete root',
    () async {
      final temporary = ProjectStorage.temporary(project: project);
      final blocker = File(
        path.join(temporary.rootDirectory, pluginStates.directoryName),
      );
      await blocker.parent.create();
      await blocker.writeAsString('conflict');
      await expectLater(temporary.assetStore, throwsFormatException);
      await temporary.discard();
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    },
  );
}
