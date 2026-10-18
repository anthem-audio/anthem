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
      final write = await store.beginWrite(
        pluginStates,
        baseName: 'Bass',
        extension: 'wav',
      );
      await File(write.path).writeAsString('plugin state');
      final id = await write.commit();
      final decoded = await store.beginWrite(
        cache,
        baseName: 'Bass',
        extension: 'wav',
      );
      final cacheId = await decoded.commit();
      final cacheRead = store.acquireRead(cacheId);
      cacheRead.release();
      expect(await storage.fileStore, same(store));
      expect(store.projectFileIds, [id]);
      final read = store.acquireRead(id);
      read.release();
      // Ending one engine's access leaves files available to its replacement.
      expect(await File(read.path).exists(), isTrue);
      expect(await File(cacheRead.path).exists(), isTrue);
      await storage.close();
      expect(await File(read.path).exists(), isTrue);
      expect(await File(cacheRead.path).exists(), isFalse);
      expect(() => storage.discard(), throwsStateError);
      final recovered = await ProjectFileStore.open(
        storage.rootDirectory,
        categories: storage.categories,
      );
      expect(recovered.objectIds, [id]);
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
        final write = await store.beginWrite(pluginStates);
        final id = await write.commit();
        await temporary.close();
        final recovered = await ProjectFileStore.open(
          temporary.rootDirectory,
          categories: temporary.categories,
        );
        expect(recovered.objectIds, [id]);
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
    final write = await store.beginWrite(pluginStates);
    final committing = write.commit();
    final closing = temporary.discard();
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
    expect(() => store.beginWrite(pluginStates), throwsStateError);
  });

  test(
    'temporary cleanup preserves data until live access is released',
    () async {
      final temporary = ProjectStorage.temporary();
      final store = await temporary.fileStore;
      final write = await store.beginWrite(pluginStates);
      final id = await write.commit();
      final read = store.acquireRead(id);
      await expectLater(temporary.discard(), throwsStateError);
      expect(await File(read.path).exists(), isTrue);
      read.release();
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
      expect(store.objectIds, isEmpty);
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

  test(
    'first save can copy project categories without changing file IDs',
    () async {
      final temporary = ProjectStorage.temporary(
        categories: [pluginStates, cache],
      );
      try {
        final source = await temporary.fileStore;
        for (final category in [pluginStates, cache]) {
          final write = await source.beginWrite(
            category,
            baseName: 'Bass',
            extension: 'bin',
          );
          await File(write.path).writeAsString(category.directoryName);
          await write.commit();
        }
        final ids = source.projectFileIds;
        for (final id in ids) {
          final read = source.acquireRead(id);
          try {
            final destination = File(path.join(storage.rootDirectory, id));
            await destination.parent.create(recursive: true);
            await File(read.path).copy(destination.path);
          } finally {
            read.release();
          }
        }
        final saved = await storage.fileStore;
        expect(saved.objectIds, unorderedEquals(ids));
        expect(
          saved.objectIds,
          isNot(contains(startsWith('${cache.directoryName}/'))),
        );
        await temporary.discard();
        for (final id in ids) {
          final read = saved.acquireRead(id);
          expect(await File(read.path).readAsString(), id.split('/').first);
          read.release();
        }
      } finally {
        await temporary.discard();
      }
    },
  );
}
