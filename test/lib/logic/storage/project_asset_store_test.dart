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
import 'package:anthem/logic/storage/file_fingerprint.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const testFiles = ProjectAssetCategory('test files');
const pluginStates = ProjectAssetCategory.pluginStates;
const cache = ProjectAssetCategory('test cache', isCache: true);

Future<ProjectAssetStore> openStore(String root) =>
    ProjectAssetStore.open(root, categories: [testFiles, pluginStates, cache]);

void main() {
  late Directory directory;
  late ProjectAssetStore store;
  late AssetScope scopeId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'anthem_file_store_test_',
    );
    store = await openStore(path.join(directory.path, 'store'));
    scopeId = store.openScope();
  });

  tearDown(() async {
    await scopeId.close();
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<String> writeObject({
    String? name,
    String? extension,
    String value = 'state',
  }) async {
    final write = await scopeId.beginWrite(
      testFiles.directoryName,
      baseName: name,
      extension: extension,
    );
    await File(write.absolutePath).writeAsString(value, flush: true);
    return scopeId.commitWrite(write.token);
  }

  test(
    'uncommitted data is private; commit publishes a complete file',
    () async {
      final write = await scopeId.beginWrite(
        testFiles.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      await File(write.absolutePath)
          .writeAsString('completed data', flush: true);
      expect(store.relativePaths, isEmpty);
      expect(
        () => scopeId.acquireRead('test files/Bass 01.wav'),
        throwsStateError,
      );
      final relativePath = await scopeId.commitWrite(write.token);
      expect(relativePath, 'test files/Bass 01.wav');
      expect(await File(write.absolutePath).exists(), isFalse);
      final read = scopeId.acquireRead(relativePath);
      expect(await File(read.absolutePath).readAsString(), 'completed data');
      scopeId.releaseRead(read.token);
      expect(() => scopeId.commitWrite(write.token), throwsStateError);
      expect(() => scopeId.abortWrite(write.token), throwsStateError);
    },
  );

  test(
    'pending writes reserve names without case-sensitive collisions',
    () async {
      final writes = await Future.wait([
        scopeId.beginWrite(
          testFiles.directoryName,
          baseName: 'Bass',
          extension: 'wav',
        ),
        scopeId.beginWrite(
          testFiles.directoryName,
          baseName: 'Bass',
          extension: '.WAV',
        ),
        scopeId.beginWrite(
          testFiles.directoryName,
          baseName: 'bass',
          extension: 'wav',
        ),
      ]);
      expect(
        await scopeId.commitWrite(writes[2].token),
        'test files/bass 03.wav',
      );
      expect(
        await scopeId.commitWrite(writes[0].token),
        'test files/Bass 01.wav',
      );
      expect(
        await scopeId.commitWrite(writes[1].token),
        'test files/Bass 02.wav',
      );
      expect(store.relativePaths, hasLength(3));
    },
  );

  test('UUID names remain the default and extensions are optional', () async {
    final relativePath = await writeObject();
    expect(
      relativePath,
      matches(
        RegExp(
          r'^test files/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(await writeObject(name: 'Preset'), 'test files/Preset 01');
  });

  test(
    'names are sanitized for portable filenames without losing Unicode',
    () async {
      expect(
        await writeObject(name: '  Bass/Lead: *? . ', extension: 'WAV'),
        'test files/Bass_Lead_ __ 01.wav',
      );
      expect(
        await writeObject(name: 'CON.state', extension: 'bin'),
        'test files/_CON.state 01.bin',
      );
      expect(
        await writeObject(name: '... ', extension: 'wav'),
        'test files/Object 01.wav',
      );
      final relativePath = await writeObject(
        name: List.filled(150, '🎵').join(),
        extension: 'wav',
      );
      expect(utf8.encode(relativePath).length, lessThanOrEqualTo(240));
      expect(relativePath, endsWith(' 01.wav'));
      expect(relativePath, isNot(contains('�')));
    },
  );

  test(
    'invalid extensions and relative paths cannot escape the store',
    () async {
      for (final extension in ['../wav', 'a/b', 'wav ', '.', 'x:y']) {
        expect(
          () =>
              scopeId.beginWrite(testFiles.directoryName, extension: extension),
          throwsArgumentError,
        );
      }
      for (final relativePath in [
        '',
        '.',
        '..',
        '../other',
        r'..\other',
        '/absolute',
        'test files/CON.wav',
        'test files/name.',
        'test files/name ',
        'test files/../other',
        'test files//other',
        'test files/./other',
        'test files/a/b',
        r'test files\other',
      ]) {
        expect(() => scopeId.acquireRead(relativePath), throwsArgumentError);
        expect(() => scopeId.retain(relativePath), throwsArgumentError);
        expect(() => scopeId.delete(relativePath), throwsArgumentError);
      }
      expect(
        () => scopeId.acquireRead('test files/unknown.wav'),
        throwsStateError,
      );
    },
  );

  test('abort removes temporary files and releases a reserved name', () async {
    final write = await scopeId.beginWrite(
      testFiles.directoryName,
      baseName: 'Bass',
      extension: 'wav',
    );
    await scopeId.abortWrite(write.token);
    expect(() => scopeId.abortWrite(write.token), throwsStateError);
    expect(await File(write.absolutePath).exists(), isFalse);
    expect(() => scopeId.commitWrite(write.token), throwsStateError);
    expect(store.relativePaths, isEmpty);
    expect(
      await writeObject(name: 'Bass', extension: 'wav'),
      'test files/Bass 01.wav',
    );
  });

  test('failed temporary-file creation releases the reserved name', () async {
    final pending = Directory(path.join(store.rootDirectory, '.pending'));
    await pending.delete();
    await expectLater(
      scopeId.beginWrite(
        testFiles.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      ),
      throwsA(isA<FileSystemException>()),
    );
    await pending.create();
    expect(
      await writeObject(name: 'Bass', extension: 'wav'),
      'test files/Bass 01.wav',
    );
  });

  test(
    'reads and retained references independently prevent deletion',
    () async {
      final relativePath = await writeObject();
      final firstRead = scopeId.acquireRead(relativePath);
      final secondRead = scopeId.acquireRead(relativePath);
      final projectReference = scopeId.retain(relativePath);
      final undoReference = scopeId.retain(relativePath);
      expect(() => scopeId.delete(relativePath), throwsStateError);
      scopeId.releaseRead(firstRead.token);
      expect(() => scopeId.releaseRead(firstRead.token), throwsStateError);
      expect(() => scopeId.delete(relativePath), throwsStateError);
      scopeId.releaseRead(secondRead.token);
      expect(() => scopeId.delete(relativePath), throwsStateError);
      scopeId.releaseRetention(projectReference);
      expect(() => scopeId.delete(relativePath), throwsStateError);
      scopeId.releaseRetention(undoReference);
      expect(() => scopeId.releaseRetention(undoReference), throwsStateError);
      expect(await File(firstRead.absolutePath).exists(), isTrue);
      await scopeId.delete(relativePath);
      expect(await File(firstRead.absolutePath).exists(), isFalse);
      expect(store.relativePaths, isEmpty);
    },
  );

  test(
    'deletion reserves the object before awaiting filesystem work',
    () async {
      final relativePath = await writeObject();
      final deleting = scopeId.delete(relativePath);
      expect(() => scopeId.acquireRead(relativePath), throwsStateError);
      expect(() => scopeId.retain(relativePath), throwsStateError);
      expect(() => scopeId.delete(relativePath), throwsStateError);
      await deleting;
      expect(store.relativePaths, isEmpty);
    },
  );

  test('failed commit preserves existing data and remains abortable', () async {
    final write = await scopeId.beginWrite(
      testFiles.directoryName,
      baseName: 'Bass',
      extension: 'wav',
    );
    final existing = File(
      path.join(store.rootDirectory, 'test files', 'Bass 01.wav'),
    );
    await existing.writeAsString('existing data');
    await File(write.absolutePath).writeAsString('new data');
    await expectLater(scopeId.commitWrite(write.token), throwsStateError);
    expect(await existing.readAsString(), 'existing data');
    expect(await File(write.absolutePath).readAsString(), 'new data');
    await scopeId.abortWrite(write.token);
    expect(store.relativePaths, isEmpty);
  });

  test('filesystem failures allow commit and deletion to be retried', () async {
    final write = await scopeId.beginWrite(
      testFiles.directoryName,
      baseName: 'Bass',
    );
    await File(write.absolutePath).delete();
    await expectLater(
      scopeId.commitWrite(write.token),
      throwsA(isA<FileSystemException>()),
    );
    await File(write.absolutePath).writeAsString('retry');
    final relativePath = await scopeId.commitWrite(write.token);
    final read = scopeId.acquireRead(relativePath);
    final objectPath = read.absolutePath;
    scopeId.releaseRead(read.token);
    await File(objectPath).delete();
    await expectLater(
      scopeId.delete(relativePath),
      throwsA(isA<FileSystemException>()),
    );
    final retained = scopeId.retain(relativePath);
    scopeId.releaseRetention(retained);
    await File(objectPath).writeAsString('retry');
    await scopeId.delete(relativePath);
  });

  test('commit and abort cannot both operate on the same write', () async {
    final write = await scopeId.beginWrite(testFiles.directoryName);
    final committing = scopeId.commitWrite(write.token);
    expect(() => scopeId.abortWrite(write.token), throwsStateError);
    expect(() => scopeId.commitWrite(write.token), throwsStateError);
    await committing;
    final abortedWrite = await scopeId.beginWrite(testFiles.directoryName);
    final aborting = scopeId.abortWrite(abortedWrite.token);
    expect(() => scopeId.commitWrite(abortedWrite.token), throwsStateError);
    await aborting;
  });

  test(
    'reopening and moving a store preserve relative paths and existing names',
    () async {
      final relativePath = await writeObject(
        name: 'Bass',
        extension: 'wav',
        value: 'saved data',
      );
      await scopeId.close();
      await store.close();
      final movedPath = path.join(directory.path, 'moved');
      await Directory(store.rootDirectory).rename(movedPath);
      store = await openStore(movedPath);
      scopeId = store.openScope();
      final read = scopeId.acquireRead(relativePath);
      expect(await File(read.absolutePath).readAsString(), 'saved data');
      expect(path.isWithin(movedPath, read.absolutePath), isTrue);
      scopeId.releaseRead(read.token);
      expect(
        await writeObject(name: 'bass', extension: 'wav'),
        'test files/bass 02.wav',
      );
    },
  );

  test(
    'opening preserves unreferenced objects and abandoned temporary files',
    () async {
      final relativePath = await writeObject();
      final abandoned = File(
        path.join(store.rootDirectory, '.pending', 'abandoned.tmp'),
      );
      await abandoned.writeAsString('incomplete');
      await scopeId.close();
      await store.close();
      store = await openStore(store.rootDirectory);
      scopeId = store.openScope();
      expect(store.relativePaths, contains(relativePath));
      expect(await abandoned.readAsString(), 'incomplete');
      scopeId.releaseRetention(scopeId.retain(relativePath));
    },
  );

  test(
    'a symbolic link cannot open a second owner of the same store',
    () async {
      final alias = Link(path.join(directory.path, 'store_alias'));
      await alias.create(store.rootDirectory);
      await expectLater(openStore(alias.path), throwsStateError);
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links requires Windows privileges.'
        : false,
  );

  test('only one UI owner can open a root at a time', () async {
    await expectLater(
      openStore(path.join(store.rootDirectory, '.')),
      throwsStateError,
    );
    final root = store.rootDirectory;
    await scopeId.close();
    await store.close();
    store = await openStore(root);
    scopeId = store.openScope();
  });

  test('close refuses outstanding scopes and can be retried', () async {
    final relativePath = await writeObject();
    final read = scopeId.acquireRead(relativePath);
    scopeId.retain(relativePath);
    final pending = await scopeId.beginWrite(testFiles.directoryName);
    await expectLater(store.close(), throwsStateError);
    expect(() => scopeId.acquireRead(relativePath), throwsStateError);
    expect(() => store.openScope(), throwsStateError);
    await scopeId.close();
    await store.close();
    expect(await File(read.absolutePath).exists(), isTrue);
    expect(await File(pending.absolutePath).exists(), isFalse);
  });

  test('scope close waits for an in-flight commit', () async {
    final write = await scopeId.beginWrite(testFiles.directoryName);
    final committing = scopeId.commitWrite(write.token);
    final closing = scopeId.close();
    final relativePath = await committing;
    await closing;
    await store.close();
    expect(
      await File(path.join(store.rootDirectory, relativePath)).exists(),
      isTrue,
    );
  });

  test(
    'scope close waits for beginWrite and aborts the returned write',
    () async {
      final writing = scopeId.beginWrite(testFiles.directoryName);
      final closing = scopeId.close();
      final write = await writing;
      await closing;
      expect(await File(write.absolutePath).exists(), isFalse);
      expect(() => scopeId.commitWrite(write.token), throwsStateError);
    },
  );

  test('names are reserved within a category, not across categories', () async {
    final first = await scopeId.beginWrite(
      testFiles.directoryName,
      baseName: 'Preset',
    );
    final second = await scopeId.beginWrite(
      pluginStates.directoryName,
      baseName: 'Preset',
    );
    expect(await scopeId.commitWrite(first.token), 'test files/Preset 01');
    expect(await scopeId.commitWrite(second.token), 'plugin states/Preset 01');
    expect(store.projectAssetPaths, unorderedEquals(store.relativePaths));
  });

  test(
    'cache files are usable but excluded from saved project files',
    () async {
      final savedPath = await writeObject(name: 'Bass', extension: 'wav');
      final write = await scopeId.beginWrite(
        cache.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      final cachedPath = await scopeId.commitWrite(write.token);
      final read = scopeId.acquireRead(cachedPath);
      expect(store.relativePaths, unorderedEquals([savedPath, cachedPath]));
      expect(store.projectAssetPaths, [savedPath]);
      // Cleanup must wait for cache readers too.
      await expectLater(store.close(), throwsStateError);
      expect(await File(read.absolutePath).exists(), isTrue);
      await scopeId.close();
      await store.close();
      expect(await File(read.absolutePath).exists(), isFalse);
      store = await openStore(store.rootDirectory);
      scopeId = store.openScope();
      expect(store.relativePaths, [savedPath]);
    },
  );

  test(
    'custom categories are recovered while unrelated files stay untouched',
    () async {
      await scopeId.close();
      await store.close();
      const custom = ProjectAssetCategory('sample maps');
      final root = store.rootDirectory;
      final document = File(path.join(root, 'project.anthem'));
      await document.writeAsString('project document');
      final unknown = File(path.join(root, 'unknown', 'preserve.bin'));
      await unknown.parent.create();
      await unknown.writeAsString('unrecognized data');
      store = await ProjectAssetStore.open(root, categories: [custom]);
      scopeId = store.openScope();
      final write = await scopeId.beginWrite(
        custom.directoryName,
        baseName: 'Map',
        extension: 'json',
      );
      final relativePath = await scopeId.commitWrite(write.token);
      await scopeId.close();
      await store.close();
      store = await ProjectAssetStore.open(root, categories: [custom]);
      scopeId = store.openScope();
      expect(store.relativePaths, [relativePath]);
      expect(relativePath, 'sample maps/Map 01.json');
      expect(await document.readAsString(), 'project document');
      expect(await unknown.readAsString(), 'unrecognized data');
      expect(
        () => scopeId.beginWrite(testFiles.directoryName),
        throwsArgumentError,
      );
    },
  );

  test(
    'invalid and ambiguous category definitions do not create a root',
    () async {
      final root = path.join(directory.path, 'invalid');
      for (final categories in [
        [const ProjectAssetCategory('../test files')],
        [const ProjectAssetCategory('test files/nested')],
        [const ProjectAssetCategory(r'test files\nested')],
        [const ProjectAssetCategory('.pending')],
        [const ProjectAssetCategory('CON')],
        [const ProjectAssetCategory('name.')],
        [testFiles, const ProjectAssetCategory('Test files')],
        [testFiles, testFiles],
      ]) {
        await expectLater(
          ProjectAssetStore.open(root, categories: categories),
          throwsArgumentError,
        );
        expect(await Directory(root).exists(), isFalse);
      }
    },
  );

  test('existing category aliases and non-directories are rejected', () async {
    final root = path.join(directory.path, 'invalid');
    await Directory(path.join(root, 'Test files')).create(recursive: true);
    await expectLater(openStore(root), throwsFormatException);
    await Directory(root).delete(recursive: true);
    await Directory(root).create();
    await File(path.join(root, 'test files')).writeAsString('not a folder');
    await expectLater(openStore(root), throwsFormatException);
    // Failed opening releases ownership and preserves the conflicting entry.
    expect(
      await File(path.join(root, 'test files')).readAsString(),
      'not a folder',
    );
    await File(path.join(root, 'test files')).delete();
    final recovered = await openStore(root);
    await recovered.close();
  });

  test(
    'category links cannot redirect reads or cache cleanup outside the root',
    () async {
      final root = path.join(directory.path, 'invalid');
      final external = await Directory(path.join(directory.path, 'external'))
          .create();
      final preserved = await File(path.join(external.path, 'keep.wav'))
          .writeAsString('keep');
      await Directory(root).create();
      await Link(path.join(root, cache.directoryName)).create(external.path);
      await expectLater(openStore(root), throwsFormatException);
      expect(await preserved.readAsString(), 'keep');
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links requires Windows privileges.'
        : false,
  );

  test('fingerprints use SHA-256 and byte length, including empty and chunked files', () async {
    for (final bytes in [
      <int>[],
      utf8.encode('abc'),
      List<int>.generate(200000, (i) => i % 256),
    ]) {
      final write = await scopeId.beginWrite(testFiles.directoryName);
      await File(write.absolutePath).writeAsBytes(bytes, flush: true);
      final file = await scopeId.commitWrite(write.token);
      final read = scopeId.acquireRead(file);
      final fingerprint = await scopeId.getFingerprint(read.token);
      expect(fingerprint.byteLength, bytes.length);
      expect(fingerprint.sha256, FileFingerprint.fromBytes(bytes).sha256);
      if (bytes.length == 3) {
        expect(
          fingerprint.sha256,
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        );
      }
      expect(await scopeId.getFingerprint(read.token), same(fingerprint));
      scopeId.releaseRead(read.token);
      expect(() => scopeId.getFingerprint(read.token), throwsStateError);
    }
  });

  test('a writer-supplied fingerprint is cached at commit', () async {
    final bytes = utf8.encode('state supplied by a writer');
    final fingerprint = FileFingerprint.fromBytes(bytes);
    final write = await scopeId.beginWrite(testFiles.directoryName);
    await File(write.absolutePath).writeAsBytes(bytes, flush: true);
    final file = await scopeId.commitWrite(
      write.token,
      fingerprint: fingerprint,
    );
    final read = scopeId.acquireRead(file);
    expect(await scopeId.getFingerprint(read.token), same(fingerprint));
    await File(read.absolutePath).delete();
    await expectLater(
      scopeId.getFingerprint(read.token),
      throwsA(isA<FileSystemException>()),
    );
    scopeId.releaseRead(read.token);
  });

  test('deleting and reusing a path discards its old fingerprint', () async {
    final file = await writeObject(name: 'State', value: 'before');
    final read = scopeId.acquireRead(file);
    final original = await scopeId.getFingerprint(read.token);
    scopeId.releaseRead(read.token);
    await scopeId.delete(file);
    final replacement = await writeObject(name: 'State', value: 'after!');
    expect(replacement, file);
    final nextRead = scopeId.acquireRead(replacement);
    final next = await scopeId.getFingerprint(nextRead.token);
    expect(next.byteLength, original.byteLength);
    expect(next.sha256, isNot(original.sha256));
    expect(
      next.sha256,
      FileFingerprint.fromBytes(utf8.encode('after!')).sha256,
    );
    scopeId.releaseRead(nextRead.token);
  });

  test(
    'reopening recalculates fingerprints after files were edited while closed',
    () async {
      final file = await writeObject(value: 'before');
      final read = scopeId.acquireRead(file);
      final original = await scopeId.getFingerprint(read.token);
      final absolutePath = read.absolutePath;
      scopeId.releaseRead(read.token);
      await scopeId.close();
      await store.close();
      await File(absolutePath).writeAsString('after!', flush: true);
      store = await openStore(store.rootDirectory);
      scopeId = store.openScope();
      final reopenedRead = scopeId.acquireRead(file);
      final fingerprint = await scopeId.getFingerprint(reopenedRead.token);
      expect(fingerprint.byteLength, original.byteLength);
      expect(
        fingerprint.sha256,
        FileFingerprint.fromBytes(utf8.encode('after!')).sha256,
      );
      expect(fingerprint.sha256, isNot(original.sha256));
      scopeId.releaseRead(reopenedRead.token);
    },
  );

  test(
    'closing a scope waits for fingerprint reads before releasing its access',
    () async {
      final file = await writeObject(value: 'a' * (1024 * 1024));
      final read = scopeId.acquireRead(file);
      final pending = scopeId.getFingerprint(read.token);
      final closing = scopeId.close();
      expect((await pending).byteLength, 1024 * 1024);
      await closing;
      scopeId = store.openScope();
      await scopeId.delete(file);
    },
  );
}
