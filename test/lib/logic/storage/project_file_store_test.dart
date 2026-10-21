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

import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const testFiles = ProjectFileCategory('test files');
const pluginStates = ProjectFileCategory.pluginStates;
const cache = ProjectFileCategory('test cache', isCache: true);

Future<ProjectFileStore> openStore(String root) =>
    ProjectFileStore.open(root, categories: [testFiles, pluginStates, cache]);

void main() {
  late Directory directory;
  late ProjectFileStore store;
  late String scopeId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'anthem_file_store_test_',
    );
    store = await openStore(path.join(directory.path, 'store'));
    scopeId = store.openScope();
  });

  tearDown(() async {
    await store.closeScope(scopeId);
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<String> writeObject({
    String? name,
    String? extension,
    String value = 'state',
  }) async {
    final write = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
      baseName: name,
      extension: extension,
    );
    await File(write.absolutePath).writeAsString(value, flush: true);
    return store.commitWrite(scopeId, write.token);
  }

  test(
    'uncommitted data is private; commit publishes a complete file',
    () async {
      final write = await store.beginWrite(
        scopeId,
        testFiles.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      await File(write.absolutePath)
          .writeAsString('completed data', flush: true);
      expect(store.relativePaths, isEmpty);
      expect(
        () => store.acquireRead(scopeId, 'test files/Bass 01.wav'),
        throwsStateError,
      );
      final relativePath = await store.commitWrite(scopeId, write.token);
      expect(relativePath, 'test files/Bass 01.wav');
      expect(await File(write.absolutePath).exists(), isFalse);
      final read = store.acquireRead(scopeId, relativePath);
      expect(await File(read.absolutePath).readAsString(), 'completed data');
      store.releaseRead(scopeId, read.token);
      expect(() => store.commitWrite(scopeId, write.token), throwsStateError);
      expect(() => store.abortWrite(scopeId, write.token), throwsStateError);
    },
  );

  test(
    'pending writes reserve names without case-sensitive collisions',
    () async {
      final writes = await Future.wait([
        store.beginWrite(
          scopeId,
          testFiles.directoryName,
          baseName: 'Bass',
          extension: 'wav',
        ),
        store.beginWrite(
          scopeId,
          testFiles.directoryName,
          baseName: 'Bass',
          extension: '.WAV',
        ),
        store.beginWrite(
          scopeId,
          testFiles.directoryName,
          baseName: 'bass',
          extension: 'wav',
        ),
      ]);
      expect(
        await store.commitWrite(scopeId, writes[2].token),
        'test files/bass 03.wav',
      );
      expect(
        await store.commitWrite(scopeId, writes[0].token),
        'test files/Bass 01.wav',
      );
      expect(
        await store.commitWrite(scopeId, writes[1].token),
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
          () => store.beginWrite(
            scopeId,
            testFiles.directoryName,
            extension: extension,
          ),
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
        expect(
          () => store.acquireRead(scopeId, relativePath),
          throwsArgumentError,
        );
        expect(() => store.retain(scopeId, relativePath), throwsArgumentError);
        expect(() => store.delete(scopeId, relativePath), throwsArgumentError);
      }
      expect(
        () => store.acquireRead(scopeId, 'test files/unknown.wav'),
        throwsStateError,
      );
    },
  );

  test('abort removes temporary files and releases a reserved name', () async {
    final write = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
      baseName: 'Bass',
      extension: 'wav',
    );
    await store.abortWrite(scopeId, write.token);
    expect(() => store.abortWrite(scopeId, write.token), throwsStateError);
    expect(await File(write.absolutePath).exists(), isFalse);
    expect(() => store.commitWrite(scopeId, write.token), throwsStateError);
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
      store.beginWrite(
        scopeId,
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
      final firstRead = store.acquireRead(scopeId, relativePath);
      final secondRead = store.acquireRead(scopeId, relativePath);
      final projectReference = store.retain(scopeId, relativePath);
      final undoReference = store.retain(scopeId, relativePath);
      expect(() => store.delete(scopeId, relativePath), throwsStateError);
      store.releaseRead(scopeId, firstRead.token);
      expect(
        () => store.releaseRead(scopeId, firstRead.token),
        throwsStateError,
      );
      expect(() => store.delete(scopeId, relativePath), throwsStateError);
      store.releaseRead(scopeId, secondRead.token);
      expect(() => store.delete(scopeId, relativePath), throwsStateError);
      store.releaseRetention(scopeId, projectReference);
      expect(() => store.delete(scopeId, relativePath), throwsStateError);
      store.releaseRetention(scopeId, undoReference);
      expect(
        () => store.releaseRetention(scopeId, undoReference),
        throwsStateError,
      );
      expect(await File(firstRead.absolutePath).exists(), isTrue);
      await store.delete(scopeId, relativePath);
      expect(await File(firstRead.absolutePath).exists(), isFalse);
      expect(store.relativePaths, isEmpty);
    },
  );

  test(
    'deletion reserves the object before awaiting filesystem work',
    () async {
      final relativePath = await writeObject();
      final deleting = store.delete(scopeId, relativePath);
      expect(() => store.acquireRead(scopeId, relativePath), throwsStateError);
      expect(() => store.retain(scopeId, relativePath), throwsStateError);
      expect(() => store.delete(scopeId, relativePath), throwsStateError);
      await deleting;
      expect(store.relativePaths, isEmpty);
    },
  );

  test('failed commit preserves existing data and remains abortable', () async {
    final write = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
      baseName: 'Bass',
      extension: 'wav',
    );
    final existing = File(
      path.join(store.rootDirectory, 'test files', 'Bass 01.wav'),
    );
    await existing.writeAsString('existing data');
    await File(write.absolutePath).writeAsString('new data');
    await expectLater(
      store.commitWrite(scopeId, write.token),
      throwsStateError,
    );
    expect(await existing.readAsString(), 'existing data');
    expect(await File(write.absolutePath).readAsString(), 'new data');
    await store.abortWrite(scopeId, write.token);
    expect(store.relativePaths, isEmpty);
  });

  test('filesystem failures allow commit and deletion to be retried', () async {
    final write = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
      baseName: 'Bass',
    );
    await File(write.absolutePath).delete();
    await expectLater(
      store.commitWrite(scopeId, write.token),
      throwsA(isA<FileSystemException>()),
    );
    await File(write.absolutePath).writeAsString('retry');
    final relativePath = await store.commitWrite(scopeId, write.token);
    final read = store.acquireRead(scopeId, relativePath);
    final objectPath = read.absolutePath;
    store.releaseRead(scopeId, read.token);
    await File(objectPath).delete();
    await expectLater(
      store.delete(scopeId, relativePath),
      throwsA(isA<FileSystemException>()),
    );
    final retained = store.retain(scopeId, relativePath);
    store.releaseRetention(scopeId, retained);
    await File(objectPath).writeAsString('retry');
    await store.delete(scopeId, relativePath);
  });

  test('commit and abort cannot both operate on the same write', () async {
    final write = await store.beginWrite(scopeId, testFiles.directoryName);
    final committing = store.commitWrite(scopeId, write.token);
    expect(() => store.abortWrite(scopeId, write.token), throwsStateError);
    expect(() => store.commitWrite(scopeId, write.token), throwsStateError);
    await committing;
    final abortedWrite = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
    );
    final aborting = store.abortWrite(scopeId, abortedWrite.token);
    expect(
      () => store.commitWrite(scopeId, abortedWrite.token),
      throwsStateError,
    );
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
      await store.closeScope(scopeId);
      await store.close();
      final movedPath = path.join(directory.path, 'moved');
      await Directory(store.rootDirectory).rename(movedPath);
      store = await openStore(movedPath);
      scopeId = store.openScope();
      final read = store.acquireRead(scopeId, relativePath);
      expect(await File(read.absolutePath).readAsString(), 'saved data');
      expect(path.isWithin(movedPath, read.absolutePath), isTrue);
      store.releaseRead(scopeId, read.token);
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
      await store.closeScope(scopeId);
      await store.close();
      store = await openStore(store.rootDirectory);
      scopeId = store.openScope();
      expect(store.relativePaths, contains(relativePath));
      expect(await abandoned.readAsString(), 'incomplete');
      store.releaseRetention(scopeId, store.retain(scopeId, relativePath));
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
    await store.closeScope(scopeId);
    await store.close();
    store = await openStore(root);
    scopeId = store.openScope();
  });

  test('close refuses outstanding scopes and can be retried', () async {
    final relativePath = await writeObject();
    final read = store.acquireRead(scopeId, relativePath);
    store.retain(scopeId, relativePath);
    final pending = await store.beginWrite(scopeId, testFiles.directoryName);
    await expectLater(store.close(), throwsStateError);
    expect(() => store.acquireRead(scopeId, relativePath), throwsStateError);
    expect(() => store.openScope(), throwsStateError);
    await store.closeScope(scopeId);
    await store.close();
    expect(await File(read.absolutePath).exists(), isTrue);
    expect(await File(pending.absolutePath).exists(), isFalse);
  });

  test('scope close waits for an in-flight commit', () async {
    final write = await store.beginWrite(scopeId, testFiles.directoryName);
    final committing = store.commitWrite(scopeId, write.token);
    final closing = store.closeScope(scopeId);
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
      final writing = store.beginWrite(scopeId, testFiles.directoryName);
      final closing = store.closeScope(scopeId);
      final write = await writing;
      await closing;
      expect(await File(write.absolutePath).exists(), isFalse);
      expect(() => store.commitWrite(scopeId, write.token), throwsStateError);
    },
  );

  test('names are reserved within a category, not across categories', () async {
    final first = await store.beginWrite(
      scopeId,
      testFiles.directoryName,
      baseName: 'Preset',
    );
    final second = await store.beginWrite(
      scopeId,
      pluginStates.directoryName,
      baseName: 'Preset',
    );
    expect(
      await store.commitWrite(scopeId, first.token),
      'test files/Preset 01',
    );
    expect(
      await store.commitWrite(scopeId, second.token),
      'plugin states/Preset 01',
    );
    expect(store.projectFilePaths, unorderedEquals(store.relativePaths));
  });

  test(
    'cache files are usable but excluded from saved project files',
    () async {
      final savedPath = await writeObject(name: 'Bass', extension: 'wav');
      final write = await store.beginWrite(
        scopeId,
        cache.directoryName,
        baseName: 'Bass',
        extension: 'wav',
      );
      final cachedPath = await store.commitWrite(scopeId, write.token);
      final read = store.acquireRead(scopeId, cachedPath);
      expect(store.relativePaths, unorderedEquals([savedPath, cachedPath]));
      expect(store.projectFilePaths, [savedPath]);
      // Cleanup must wait for cache readers too.
      await expectLater(store.close(), throwsStateError);
      expect(await File(read.absolutePath).exists(), isTrue);
      await store.closeScope(scopeId);
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
      await store.closeScope(scopeId);
      await store.close();
      const custom = ProjectFileCategory('sample maps');
      final root = store.rootDirectory;
      final document = File(path.join(root, 'project.anthem'));
      await document.writeAsString('project document');
      final unknown = File(path.join(root, 'unknown', 'preserve.bin'));
      await unknown.parent.create();
      await unknown.writeAsString('unrecognized data');
      store = await ProjectFileStore.open(root, categories: [custom]);
      scopeId = store.openScope();
      final write = await store.beginWrite(
        scopeId,
        custom.directoryName,
        baseName: 'Map',
        extension: 'json',
      );
      final relativePath = await store.commitWrite(scopeId, write.token);
      await store.closeScope(scopeId);
      await store.close();
      store = await ProjectFileStore.open(root, categories: [custom]);
      scopeId = store.openScope();
      expect(store.relativePaths, [relativePath]);
      expect(relativePath, 'sample maps/Map 01.json');
      expect(await document.readAsString(), 'project document');
      expect(await unknown.readAsString(), 'unrecognized data');
      expect(
        () => store.beginWrite(scopeId, testFiles.directoryName),
        throwsArgumentError,
      );
    },
  );

  test(
    'invalid and ambiguous category definitions do not create a root',
    () async {
      final root = path.join(directory.path, 'invalid');
      for (final categories in [
        [const ProjectFileCategory('../test files')],
        [const ProjectFileCategory('test files/nested')],
        [const ProjectFileCategory(r'test files\nested')],
        [const ProjectFileCategory('.pending')],
        [const ProjectFileCategory('CON')],
        [const ProjectFileCategory('name.')],
        [testFiles, const ProjectFileCategory('Test files')],
        [testFiles, testFiles],
      ]) {
        await expectLater(
          ProjectFileStore.open(root, categories: categories),
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
}
