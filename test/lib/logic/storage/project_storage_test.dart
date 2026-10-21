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

import 'dart:io';

import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const pluginStates = ProjectFileCategory.pluginStates;
const cache = ProjectFileCategory('test cache', isCache: true);

void main() {
  late Directory parent;
  late ProjectStorage storage;

  setUp(() async {
    parent = await Directory.systemTemp.createTemp(
      'anthem_project_storage_test_',
    );
    storage = ProjectStorage(rootDirectory: path.join(parent.path, 'project'));
  });

  tearDown(() async {
    await storage.close();
    await parent.delete(recursive: true);
  });

  test('an unused explicit root is never created', () async {
    await storage.close();
    expect(await parent.list().toList(), isEmpty);
    expect(() => storage.fileStore, throwsStateError);
  });

  test(
    'explicit roots preserve project data and clean up cache categories',
    () async {
      storage = ProjectStorage(
        rootDirectory: storage.rootDirectory,
        categories: [pluginStates, cache],
      );
      final store = await storage.fileStore;
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
      final cacheRead = store.acquireRead(scopeId, cacheRelativePath);
      store.releaseRead(scopeId, cacheRead.token);
      expect(await storage.fileStore, same(store));
      expect(store.projectFilePaths, [relativePath]);
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
      final recovered = await ProjectFileStore.open(
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
      final temporary = ProjectStorage.temporary();
      final unused = ProjectStorage.temporary();
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
      await unused.discard();
      expect(await Directory(unused.rootDirectory).exists(), isFalse);
      try {
        final store = await temporary.fileStore;
        final scopeId = store.openScope();
        final write = await store.beginWrite(
          scopeId,
          pluginStates.directoryName,
        );
        final relativePath = await store.commitWrite(scopeId, write.token);
        await store.closeScope(scopeId);
        await temporary.close();
        final recovered = await ProjectFileStore.open(
          temporary.rootDirectory,
          categories: temporary.categories,
        );
        expect(recovered.relativePaths, [relativePath]);
        await recovered.close();
        final another = ProjectStorage.temporary();
        await another.fileStore;
        await another.discard();
        expect(await Directory(temporary.rootDirectory).exists(), isTrue);
      } finally {
        await temporary.discard();
      }
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    },
  );

  test('discard waits for initialization and an in-flight write', () async {
    final temporary = ProjectStorage.temporary();
    final opening = temporary.fileStore;
    final store = await opening;
    final scopeId = store.openScope();
    final write = await store.beginWrite(scopeId, pluginStates.directoryName);
    final committing = store.commitWrite(scopeId, write.token);
    final ending = store.closeScope(scopeId);
    final closing = ending.then((_) => temporary.discard());
    await committing;
    await closing;
    expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    expect(() => temporary.fileStore, throwsStateError);
  });

  test('close waits for initialization already in progress', () async {
    final opening = storage.fileStore;
    final closing = storage.close();
    final store = await opening;
    await closing;
    expect(await Directory(store.rootDirectory).exists(), isTrue);
    expect(() => store.openScope(), throwsStateError);
  });

  test(
    'temporary cleanup preserves data until live access is released',
    () async {
      final temporary = ProjectStorage.temporary();
      final store = await temporary.fileStore;
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
      await expectLater(storage.fileStore, throwsA(isA<FileSystemException>()));
      await blocker.delete();
      final store = await storage.fileStore;
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
      await expectLater(storage.fileStore, throwsA(isA<FileSystemException>()));
      await storage.close();
      expect(await unrelated.readAsString(), 'keep');
      expect(await blocker.readAsString(), 'keep too');
    },
  );

  test(
    'failed temporary initialization can discard its incomplete root',
    () async {
      final temporary = ProjectStorage.temporary();
      final blocker = File(
        path.join(temporary.rootDirectory, pluginStates.directoryName),
      );
      await blocker.parent.create();
      await blocker.writeAsString('conflict');
      await expectLater(temporary.fileStore, throwsFormatException);
      await temporary.discard();
      expect(await Directory(temporary.rootDirectory).exists(), isFalse);
    },
  );

  test('first save can copy project categories without changing relative file paths', () async {
    final temporary = ProjectStorage.temporary(
      categories: [pluginStates, cache],
    );
    try {
      final source = await temporary.fileStore;
      final sourceScope = source.openScope();
      for (final category in [pluginStates, cache]) {
        final write = await source.beginWrite(
          sourceScope,
          category.directoryName,
          baseName: 'Bass',
          extension: 'bin',
        );
        await File(write.absolutePath).writeAsString(category.directoryName);
        await source.commitWrite(sourceScope, write.token);
      }
      final relativePaths = source.projectFilePaths;
      for (final relativePath in relativePaths) {
        final read = source.acquireRead(sourceScope, relativePath);
        try {
          final destination = File(
            path.join(storage.rootDirectory, relativePath),
          );
          await destination.parent.create(recursive: true);
          await File(read.absolutePath).copy(destination.path);
        } finally {
          source.releaseRead(sourceScope, read.token);
        }
      }
      final saved = await storage.fileStore;
      final savedScope = saved.openScope();
      expect(saved.relativePaths, unorderedEquals(relativePaths));
      expect(
        saved.relativePaths,
        isNot(contains(startsWith('${cache.directoryName}/'))),
      );
      await source.closeScope(sourceScope);
      await temporary.discard();
      for (final relativePath in relativePaths) {
        final read = saved.acquireRead(savedScope, relativePath);
        expect(
          await File(read.absolutePath).readAsString(),
          relativePath.split('/').first,
        );
        saved.releaseRead(savedScope, read.token);
      }
      await saved.closeScope(savedScope);
    } finally {
      await temporary.discard();
    }
  });
}
