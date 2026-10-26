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

import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late ProjectAssetStore store;
  late String first;
  late String second;

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
    await store.closeScope(first);
    await store.closeScope(second);
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'serialized scopes restore retention IDs and exclude runtime access',
    () async {
      final write = await store.beginWrite(first, 'plugin states');
      await File(write.absolutePath).writeAsString('durable state');
      final file = await store.commitWrite(first, write.token);
      final projectScope = store.openScope();
      final id = store.retain(projectScope, file);
      final anotherId = store.retain(projectScope, file);
      final commandClaim = store.retain(second, file);
      final read = store.acquireRead(projectScope, file);
      final pending = await store.beginWrite(projectScope, 'plugin states');
      final serialized = store.serializeRetentions(projectScope);
      expect(jsonDecode(serialized), {id: file, anotherId: file});
      expect(store.resolveRetention(id), file);
      expect(store.resolveRetention(commandClaim), file);
      await store.closeScope(projectScope);
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(() => store.resolveRetention(id), throwsStateError);

      final restored = store.openScope(serializedRetentions: serialized);
      try {
        expect(store.resolveRetention(id), file);
        expect(() => store.releaseRead(restored, read.token), throwsStateError);
        store.releaseRetention(second, commandClaim);
        expect(() => store.delete(first, file), throwsStateError);
        store.releaseRetention(restored, id);
        expect(() => store.delete(first, file), throwsStateError);
        store.releaseRetention(restored, anotherId);
        await store.delete(first, file);
      } finally {
        await store.closeScope(restored);
      }
    },
  );

  test('serialized claims cannot be restored into two live scopes', () async {
    final write = await store.beginWrite(first, 'plugin states');
    final file = await store.commitWrite(first, write.token);
    final scope = store.openScope();
    final id = store.retain(scope, file);
    final serialized = store.serializeRetentions(scope);
    try {
      expect(
        () => store.openScope(serializedRetentions: serialized),
        throwsStateError,
      );
    } finally {
      await store.closeScope(scope);
    }
    final reopened = store.openScope(serializedRetentions: serialized);
    expect(store.resolveRetention(id), file);
    await store.closeScope(reopened);
  });

  test('failed scope restoration does not leave partial ownership', () async {
    final write = await store.beginWrite(first, 'plugin states');
    final file = await store.commitWrite(first, write.token);
    expect(
      () => store.openScope(
        serializedRetentions: jsonEncode({
          'valid': file,
          'missing': 'plugin states/missing.bin',
        }),
      ),
      throwsStateError,
    );
    expect(() => store.resolveRetention('valid'), throwsStateError);
    final serialized = jsonEncode({'valid': file});
    final restored = store.openScope(serializedRetentions: serialized);
    try {
      expect(
        () => store.openScope(serializedRetentions: serialized),
        throwsStateError,
      );
      store.releaseRetention(restored, 'valid');
      expect(jsonDecode(store.serializeRetentions(restored)), isEmpty);
      // Releasing the live claim does not alter the previously captured JSON.
      expect(jsonDecode(serialized), {'valid': file});
      await store.delete(first, file);
    } finally {
      await store.closeScope(restored);
    }
  });

  for (final invalid in ['{', '[]', 'null', '{"claim": 1}']) {
    test('invalid serialized retentions are rejected: $invalid', () {
      expect(
        () => store.openScope(serializedRetentions: invalid),
        throwsFormatException,
      );
    });
  }

  test('cache claims cannot be serialized or restored', () async {
    final root = await Directory.systemTemp.createTemp('anthem_cache_scope_');
    final caches = await ProjectAssetStore.open(
      root.path,
      categories: [const ProjectAssetCategory('cache', isCache: true)],
    );
    final scope = caches.openScope();
    try {
      final write = await caches.beginWrite(scope, 'cache');
      final file = await caches.commitWrite(scope, write.token);
      final id = caches.retain(scope, file);
      expect(() => caches.serializeRetentions(scope), throwsStateError);
      caches.releaseRetention(scope, id);
      expect(
        () => caches.openScope(serializedRetentions: jsonEncode({id: file})),
        throwsStateError,
      );
      await caches.delete(scope, file);
    } finally {
      await caches.closeScope(scope);
      await caches.close();
      await root.delete(recursive: true);
    }
  });

  test('tokens can only be used by the scope that acquired them', () async {
    final write = await store.beginWrite(first, 'plugin states');
    expect(() => store.commitWrite(second, write.token), throwsStateError);
    expect(() => store.abortWrite(second, write.token), throwsStateError);
    final relativePath = await store.commitWrite(first, write.token);
    final read = store.acquireRead(first, relativePath);
    final retained = store.retain(first, relativePath);
    expect(() => store.releaseRead(second, read.token), throwsStateError);
    expect(() => store.releaseRetention(second, retained), throwsStateError);
    expect(() => store.releaseRead(first, retained), throwsStateError);
    expect(() => store.releaseRetention(first, read.token), throwsStateError);
    expect(() => store.delete(second, relativePath), throwsStateError);
    store.releaseRead(first, read.token);
    store.releaseRetention(first, retained);
    await store.delete(second, relativePath);
  });

  test(
    'closing one scope preserves files and access owned by another',
    () async {
      final write = await store.beginWrite(first, 'plugin states');
      await File(write.absolutePath).writeAsString('saved state', flush: true);
      final relativePath = await store.commitWrite(first, write.token);
      store.acquireRead(first, relativePath);
      store.retain(first, relativePath);
      final pending = await store.beginWrite(first, 'plugin states');
      final otherRead = store.acquireRead(second, relativePath);
      final otherReference = store.retain(second, relativePath);

      await store.closeScope(first);
      expect(await File(pending.absolutePath).exists(), isFalse);
      expect(await File(otherRead.absolutePath).readAsString(), 'saved state');
      expect(() => store.acquireRead(first, relativePath), throwsStateError);
      expect(() => store.delete(second, relativePath), throwsStateError);
      store.releaseRead(second, otherRead.token);
      expect(() => store.delete(second, relativePath), throwsStateError);
      store.releaseRetention(second, otherReference);
      await store.delete(second, relativePath);
      await store.closeScope(first);
    },
  );

  test('replacement scopes use fresh tokens for existing files', () async {
    final write = await store.beginWrite(first, 'plugin states');
    final relativePath = await store.commitWrite(first, write.token);
    final read = store.acquireRead(first, relativePath);
    await store.closeScope(first);
    first = store.openScope();
    expect(() => store.releaseRead(first, read.token), throwsStateError);
    final replacement = store.acquireRead(first, relativePath);
    expect(replacement.token, isNot(read.token));
    expect(replacement.absolutePath, read.absolutePath);
  });

  test(
    'closing waits for a write grant even if its result is unused',
    () async {
      final opening = store.beginWrite(first, 'plugin states');
      final closing = store.closeScope(first);
      expect(store.closeScope(first), same(closing));
      expect(() => store.beginWrite(first, 'plugin states'), throwsStateError);
      final write = await opening;
      await closing;
      expect(await File(write.absolutePath).exists(), isFalse);
      expect(store.relativePaths, isEmpty);
    },
  );

  test(
    'failed write cleanup releases other access and can be retried',
    () async {
      final committed = await store.beginWrite(first, 'plugin states');
      final relativePath = await store.commitWrite(first, committed.token);
      final read = store.acquireRead(first, relativePath);
      store.retain(first, relativePath);
      final pending = await store.beginWrite(first, 'plugin states');
      final another = await store.beginWrite(first, 'plugin states');
      await File(pending.absolutePath).delete();
      await Directory(pending.absolutePath).create();
      await expectLater(
        store.closeScope(first),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(another.absolutePath).exists(), isFalse);
      // One failed abort must not retain unrelated read or retention tokens.
      await store.delete(second, relativePath);
      expect(await File(read.absolutePath).exists(), isFalse);
      expect(() => store.beginWrite(first, 'plugin states'), throwsStateError);
      await Directory(pending.absolutePath).delete();
      await File(pending.absolutePath).writeAsString('retry');
      await store.closeScope(first);
      expect(await File(pending.absolutePath).exists(), isFalse);
    },
  );

  test('closing waits for failed operations and still cleans up', () async {
    final write = await store.beginWrite(first, 'plugin states');
    await File(write.absolutePath).delete();
    final failedCommit = expectLater(
      store.commitWrite(first, write.token),
      throwsA(isA<FileSystemException>()),
    );
    await store.closeScope(first);
    await failedCommit;
    expect(store.relativePaths, isEmpty);
    // The failed write's reserved name was released during scope cleanup.
    final replacement = await store.beginWrite(second, 'plugin states');
    await store.commitWrite(second, replacement.token);
  });
}
