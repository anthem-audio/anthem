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

import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late ProjectAssetStore store;
  late AssetScope first;
  late AssetScope second;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anthem_file_scope_');
    store = await ProjectAssetStore.open(
      directory.path,
      categories: ProjectAssetCategory.defaults,
    );
    first = store.openScope();
    second = store.openScope();
  });

  tearDown(() async {
    await first.close();
    await second.close();
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'restored scope references preserve IDs and exclude runtime access',
    () async {
      final write = await first.beginWrite('plugin states');
      await File(write.absolutePath).writeAsString('durable state');
      final file = await first.commitWrite(write.token);
      final projectScope = store.openScope();
      final id = projectScope.retain(file);
      final anotherId = projectScope.retain(file);
      final commandClaim = second.retain(file);
      final read = projectScope.acquireRead(file);
      final pending = await projectScope.beginWrite('plugin states');
      final captured = projectScope.references;
      expect(captured, {id: file, anotherId: file});
      expect(store.resolveRetention(id), file);
      expect(store.resolveRetention(commandClaim), file);
      await projectScope.close();
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(() => store.resolveRetention(id), throwsStateError);

      final restored = store.openScope(references: captured);
      try {
        expect(store.resolveRetention(id), file);
        expect(() => restored.releaseRead(read.token), throwsStateError);
        second.releaseRetention(commandClaim);
        expect(() => first.delete(file), throwsStateError);
        restored.releaseRetention(id);
        expect(() => first.delete(file), throwsStateError);
        restored.releaseRetention(anotherId);
        await first.delete(file);
      } finally {
        await restored.close();
      }
    },
  );

  test('reference IDs cannot be restored into two live scopes', () async {
    final write = await first.beginWrite('plugin states');
    final file = await first.commitWrite(write.token);
    final scope = store.openScope();
    final id = scope.retain(file);
    final captured = scope.references;
    try {
      expect(() => store.openScope(references: captured), throwsStateError);
    } finally {
      await scope.close();
    }
    final reopened = store.openScope(references: captured);
    expect(store.resolveRetention(id), file);
    await reopened.close();
  });

  test('failed scope restoration does not leave partial ownership', () async {
    final write = await first.beginWrite('plugin states');
    final file = await first.commitWrite(write.token);
    expect(
      () => store.openScope(
        references: {'valid': file, 'missing': 'plugin states/missing.bin'},
      ),
      throwsStateError,
    );
    expect(() => store.resolveRetention('valid'), throwsStateError);
    final captured = {'valid': file};
    final restored = store.openScope(references: captured);
    try {
      expect(() => store.openScope(references: captured), throwsStateError);
      restored.releaseRetention('valid');
      expect(restored.references, isEmpty);
      // Releasing the live claim does not alter the previously captured mapping.
      expect(captured, {'valid': file});
      await first.delete(file);
    } finally {
      await restored.close();
    }
  });

  test('scopes can independently constrain retention of cache files', () async {
    final root = await Directory.systemTemp.createTemp('anthem_cache_scope_');
    final caches = await ProjectAssetStore.open(
      root.path,
      categories: [const ProjectAssetCategory('cache', isCache: true)],
    );
    final scope = caches.openScope();
    final document = caches.openScope(allowCacheFiles: false);
    try {
      final write = await scope.beginWrite('cache');
      final file = await scope.commitWrite(write.token);
      final id = scope.retain(file);
      expect(() => document.retain(file), throwsStateError);
      expect(
        () => caches.openScope(
          references: {'restored': file},
          allowCacheFiles: false,
        ),
        throwsStateError,
      );
      final snapshot = scope.snapshot();
      expect(snapshot.references, {id: file});
      await snapshot.close();
      scope.releaseRetention(id);
      await scope.delete(file);
    } finally {
      await document.close();
      await scope.close();
      await caches.close();
      await root.delete(recursive: true);
    }
  });

  test('tokens can only be used by the scope that acquired them', () async {
    final write = await first.beginWrite('plugin states');
    expect(() => second.commitWrite(write.token), throwsStateError);
    expect(() => second.abortWrite(write.token), throwsStateError);
    final relativePath = await first.commitWrite(write.token);
    final read = first.acquireRead(relativePath);
    final retained = first.retain(relativePath);
    expect(() => second.releaseRead(read.token), throwsStateError);
    expect(() => second.releaseRetention(retained), throwsStateError);
    expect(() => first.releaseRead(retained), throwsStateError);
    expect(() => first.releaseRetention(read.token), throwsStateError);
    expect(() => second.delete(relativePath), throwsStateError);
    first.releaseRead(read.token);
    first.releaseRetention(retained);
    await second.delete(relativePath);
  });

  test(
    'closing one scope preserves files and access owned by another',
    () async {
      final write = await first.beginWrite('plugin states');
      await File(write.absolutePath).writeAsString('saved state', flush: true);
      final relativePath = await first.commitWrite(write.token);
      first.acquireRead(relativePath);
      first.retain(relativePath);
      final pending = await first.beginWrite('plugin states');
      final otherRead = second.acquireRead(relativePath);
      final otherReference = second.retain(relativePath);

      await first.close();
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(await File(otherRead.absolutePath).readAsString(), 'saved state');
      expect(() => first.acquireRead(relativePath), throwsStateError);
      expect(() => second.delete(relativePath), throwsStateError);
      second.releaseRead(otherRead.token);
      expect(() => second.delete(relativePath), throwsStateError);
      second.releaseRetention(otherReference);
      await second.delete(relativePath);
      await first.close();
    },
  );

  test('replacement scopes use fresh tokens for existing files', () async {
    final write = await first.beginWrite('plugin states');
    final relativePath = await first.commitWrite(write.token);
    final read = first.acquireRead(relativePath);
    await first.close();
    first = store.openScope();
    expect(() => first.releaseRead(read.token), throwsStateError);
    final replacement = first.acquireRead(relativePath);
    expect(replacement.token, isNot(read.token));
    expect(replacement.absolutePath, read.absolutePath);
  });

  test(
    'closing waits for a write grant even if its result is unused',
    () async {
      final opening = first.beginWrite('plugin states');
      final closing = first.close();
      expect(first.close(), same(closing));
      expect(() => first.beginWrite('plugin states'), throwsStateError);
      final write = await opening;
      await closing;
      expect(await File(write.absolutePath).exists(), isFalse);
      expect(store.relativePaths, isEmpty);
    },
  );

  test(
    'failed write cleanup releases other access and can be retried',
    () async {
      final committed = await first.beginWrite('plugin states');
      final relativePath = await first.commitWrite(committed.token);
      final read = first.acquireRead(relativePath);
      first.retain(relativePath);
      final pending = await first.beginWrite('plugin states');
      final another = await first.beginWrite('plugin states');
      await File(pending.absolutePath).delete();
      await Directory(pending.absolutePath).create();
      await expectLater(first.close(), throwsA(isA<FileSystemException>()));
      expect(await File(another.absolutePath).exists(), isFalse);
      // One failed abort must not retain unrelated read or retention tokens.
      await second.delete(relativePath);
      expect(await File(read.absolutePath).exists(), isFalse);
      expect(() => first.beginWrite('plugin states'), throwsStateError);
      await Directory(pending.absolutePath).delete();
      await File(pending.absolutePath).writeAsString('retry');
      await first.close();
      expect(await File(pending.absolutePath).exists(), isFalse);
    },
  );

  test('closing waits for failed operations and still cleans up', () async {
    final write = await first.beginWrite('plugin states');
    await File(write.absolutePath).delete();
    final failedCommit = expectLater(
      first.commitWrite(write.token),
      throwsA(isA<FileSystemException>()),
    );
    await first.close();
    await failedCommit;
    expect(store.relativePaths, isEmpty);
    // The failed write's reserved name was released during scope cleanup.
    final replacement = await second.beginWrite('plugin states');
    await second.commitWrite(replacement.token);
  });
  test(
    'a snapshot pins the selected scope after its references change or close',
    () async {
      final write = await first.beginWrite('plugin states');
      final file = await first.commitWrite(write.token);
      final owner = store.openScope();
      final id = owner.retain(file);
      final snapshot = owner.snapshot();
      owner.releaseRetention(id);
      await owner.close();
      expect(snapshot.references, {id: file});
      expect(() => store.resolveRetention(id), throwsStateError);
      expect(() => second.delete(file), throwsStateError);
      // The frozen IDs can restore a new document scope without reusing read tokens.
      final restored = store.openScope(references: snapshot.references);
      expect(restored.resolveRetention(id), file);
      await restored.close();
      await snapshot.close();
      await second.delete(file);
    },
  );

  test('retention handles clone independently and invalidate with their owner scope', () async {
    final write = await first.beginWrite('plugin states');
    final file = await first.commitWrite(write.token);
    final owner = store.openScope();
    final handle = owner.retainAll([file, file]);
    final clone = handle.retain();
    expect(clone.retentionIds, isNot(handle.retentionIds));
    expect(handle.retentionIds, hasLength(1));
    handle.dispose();
    handle.dispose();
    expect(clone.isDisposed, isFalse);
    expect(() => second.delete(file), throwsStateError);
    await owner.close();
    expect(clone.isDisposed, isTrue);
    expect(clone.retain, throwsStateError);
    clone.dispose();
    await second.delete(file);
  });

  test(
    'a failed retention group leaves the scope with no partial claims',
    () async {
      final write = await first.beginWrite('plugin states');
      final file = await first.commitWrite(write.token);
      expect(
        () => second.retainAll([file, 'plugin states/missing.bin']),
        throwsStateError,
      );
      expect(second.references, isEmpty);
      await first.delete(file);
    },
  );
}
