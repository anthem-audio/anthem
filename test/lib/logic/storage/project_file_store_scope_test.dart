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

import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:test/test.dart';

void main() {
  late ProjectStorage storage;
  late ProjectFileStore store;
  late String first;
  late String second;

  setUp(() async {
    storage = ProjectStorage.temporary();
    store = await storage.fileStore;
    first = store.openScope();
    second = store.openScope();
  });

  tearDown(() async {
    await store.closeScope(first);
    await store.closeScope(second);
    await storage.discard();
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
