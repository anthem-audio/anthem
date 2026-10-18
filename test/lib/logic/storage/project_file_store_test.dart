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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'anthem_file_store_test_',
    );
    store = await openStore(path.join(directory.path, 'store'));
  });

  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<String> writeObject({
    String? name,
    String? extension,
    String value = 'state',
  }) async {
    final write = await store.beginWrite(
      testFiles,
      baseName: name,
      extension: extension,
    );
    await File(write.path).writeAsString(value, flush: true);
    return write.commit();
  }

  test(
    'uncommitted data is private; commit publishes a complete file',
    () async {
      final write = await store.beginWrite(
        testFiles,
        baseName: 'Bass',
        extension: 'wav',
      );
      await File(write.path).writeAsString('completed data', flush: true);
      expect(store.objectIds, isEmpty);
      expect(
        () => store.acquireRead('test files/Bass 01.wav'),
        throwsStateError,
      );
      final id = await write.commit();
      expect(id, 'test files/Bass 01.wav');
      expect(await File(write.path).exists(), isFalse);
      final read = store.acquireRead(id);
      expect(await File(read.path).readAsString(), 'completed data');
      read.release();
      expect(await write.commit(), id);
      expect(() => write.abort(), throwsStateError);
    },
  );

  test(
    'pending writes reserve names without case-sensitive collisions',
    () async {
      final writes = await Future.wait([
        store.beginWrite(testFiles, baseName: 'Bass', extension: 'wav'),
        store.beginWrite(testFiles, baseName: 'Bass', extension: '.WAV'),
        store.beginWrite(testFiles, baseName: 'bass', extension: 'wav'),
      ]);
      expect(await writes[2].commit(), 'test files/bass 03.wav');
      expect(await writes[0].commit(), 'test files/Bass 01.wav');
      expect(await writes[1].commit(), 'test files/Bass 02.wav');
      expect(store.objectIds, hasLength(3));
    },
  );

  test('UUID names remain the default and extensions are optional', () async {
    final id = await writeObject();
    expect(
      id,
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
      final id = await writeObject(
        name: List.filled(150, '🎵').join(),
        extension: 'wav',
      );
      expect(utf8.encode(id).length, lessThanOrEqualTo(240));
      expect(id, endsWith(' 01.wav'));
      expect(id, isNot(contains('�')));
    },
  );

  test('invalid extensions and path IDs cannot escape the store', () async {
    for (final extension in ['../wav', 'a/b', 'wav ', '.', 'x:y']) {
      expect(
        () => store.beginWrite(testFiles, extension: extension),
        throwsArgumentError,
      );
    }
    for (final id in [
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
      expect(() => store.acquireRead(id), throwsArgumentError);
      expect(() => store.retain(id), throwsArgumentError);
      expect(() => store.delete(id), throwsArgumentError);
    }
    expect(() => store.acquireRead('test files/unknown.wav'), throwsStateError);
  });

  test('abort removes temporary files and releases a reserved name', () async {
    final write = await store.beginWrite(
      testFiles,
      baseName: 'Bass',
      extension: 'wav',
    );
    await write.abort();
    await write.abort();
    expect(await File(write.path).exists(), isFalse);
    expect(() => write.commit(), throwsStateError);
    expect(store.objectIds, isEmpty);
    expect(
      await writeObject(name: 'Bass', extension: 'wav'),
      'test files/Bass 01.wav',
    );
  });

  test('failed temporary-file creation releases the reserved name', () async {
    final pending = Directory(path.join(store.rootDirectory, '.pending'));
    await pending.delete();
    await expectLater(
      store.beginWrite(testFiles, baseName: 'Bass', extension: 'wav'),
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
      final id = await writeObject();
      final firstRead = store.acquireRead(id);
      final secondRead = store.acquireRead(id);
      final projectReference = store.retain(id);
      final undoReference = store.retain(id);
      expect(() => store.delete(id), throwsStateError);
      firstRead.release();
      firstRead.release();
      expect(() => store.delete(id), throwsStateError);
      secondRead.release();
      expect(() => store.delete(id), throwsStateError);
      projectReference.release();
      expect(() => store.delete(id), throwsStateError);
      undoReference.release();
      undoReference.release();
      expect(await File(firstRead.path).exists(), isTrue);
      await store.delete(id);
      expect(await File(firstRead.path).exists(), isFalse);
      expect(store.objectIds, isEmpty);
    },
  );

  test(
    'deletion reserves the object before awaiting filesystem work',
    () async {
      final id = await writeObject();
      final deleting = store.delete(id);
      expect(() => store.acquireRead(id), throwsStateError);
      expect(() => store.retain(id), throwsStateError);
      expect(() => store.delete(id), throwsStateError);
      await deleting;
      expect(store.objectIds, isEmpty);
    },
  );

  test('failed commit preserves existing data and remains abortable', () async {
    final write = await store.beginWrite(
      testFiles,
      baseName: 'Bass',
      extension: 'wav',
    );
    final existing = File(
      path.join(store.rootDirectory, 'test files', 'Bass 01.wav'),
    );
    await existing.writeAsString('existing data');
    await File(write.path).writeAsString('new data');
    await expectLater(write.commit(), throwsStateError);
    expect(await existing.readAsString(), 'existing data');
    expect(await File(write.path).readAsString(), 'new data');
    await write.abort();
    expect(store.objectIds, isEmpty);
  });

  test('filesystem failures allow commit and deletion to be retried', () async {
    final write = await store.beginWrite(testFiles, baseName: 'Bass');
    await File(write.path).delete();
    await expectLater(write.commit(), throwsA(isA<FileSystemException>()));
    await File(write.path).writeAsString('retry');
    final id = await write.commit();
    final read = store.acquireRead(id);
    final objectPath = read.path;
    read.release();
    await File(objectPath).delete();
    await expectLater(store.delete(id), throwsA(isA<FileSystemException>()));
    final retained = store.retain(id);
    retained.release();
    await File(objectPath).writeAsString('retry');
    await store.delete(id);
  });

  test('commit and abort cannot both operate on the same write', () async {
    final write = await store.beginWrite(testFiles);
    final committing = write.commit();
    expect(() => write.abort(), throwsStateError);
    expect(() => write.commit(), throwsStateError);
    await committing;
    final abortedWrite = await store.beginWrite(testFiles);
    final aborting = abortedWrite.abort();
    expect(() => abortedWrite.commit(), throwsStateError);
    await aborting;
  });

  test(
    'reopening and moving a store preserve IDs and existing names',
    () async {
      final id = await writeObject(
        name: 'Bass',
        extension: 'wav',
        value: 'saved data',
      );
      await store.close();
      final movedPath = path.join(directory.path, 'moved');
      await Directory(store.rootDirectory).rename(movedPath);
      store = await openStore(movedPath);
      final read = store.acquireRead(id);
      expect(await File(read.path).readAsString(), 'saved data');
      expect(path.isWithin(movedPath, read.path), isTrue);
      read.release();
      expect(
        await writeObject(name: 'bass', extension: 'wav'),
        'test files/bass 02.wav',
      );
    },
  );

  test(
    'opening preserves unreferenced objects and abandoned temporary files',
    () async {
      final id = await writeObject();
      final abandoned = File(
        path.join(store.rootDirectory, '.pending', 'abandoned.tmp'),
      );
      await abandoned.writeAsString('incomplete');
      await store.close();
      store = await openStore(store.rootDirectory);
      expect(store.objectIds, contains(id));
      expect(await abandoned.readAsString(), 'incomplete');
      store.retain(id).release();
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
    await store.close();
    store = await openStore(root);
  });

  test('close refuses live handles and can be retried after release', () async {
    final id = await writeObject();
    final read = store.acquireRead(id);
    final reference = store.retain(id);
    final pending = await store.beginWrite(testFiles);
    await expectLater(store.close(), throwsStateError);
    expect(() => store.acquireRead(id), throwsStateError);
    expect(() => store.beginWrite(testFiles), throwsStateError);
    read.release();
    reference.release();
    await pending.abort();
    await store.close();
    expect(await File(read.path).exists(), isTrue);
  });

  test('close waits for an in-flight commit', () async {
    final write = await store.beginWrite(testFiles);
    final committing = write.commit();
    final closing = store.close();
    final id = await committing;
    await closing;
    expect(await File(path.join(store.rootDirectory, id)).exists(), isTrue);
  });

  test(
    'close during beginWrite leaves the returned transaction abortable',
    () async {
      final writing = store.beginWrite(testFiles);
      final closing = expectLater(store.close(), throwsStateError);
      final write = await writing;
      await closing;
      await write.abort();
      await store.close();
    },
  );
  test('names are reserved within a category, not across categories', () async {
    final first = await store.beginWrite(testFiles, baseName: 'Preset');
    final second = await store.beginWrite(pluginStates, baseName: 'Preset');
    expect(await first.commit(), 'test files/Preset 01');
    expect(await second.commit(), 'plugin states/Preset 01');
    expect(store.projectFileIds, unorderedEquals(store.objectIds));
  });

  test(
    'cache files are usable but excluded from saved project files',
    () async {
      final savedId = await writeObject(name: 'Bass', extension: 'wav');
      final write = await store.beginWrite(
        cache,
        baseName: 'Bass',
        extension: 'wav',
      );
      final cachedId = await write.commit();
      final read = store.acquireRead(cachedId);
      expect(store.objectIds, unorderedEquals([savedId, cachedId]));
      expect(store.projectFileIds, [savedId]);
      // Cleanup must wait for cache readers too.
      await expectLater(store.close(), throwsStateError);
      expect(await File(read.path).exists(), isTrue);
      read.release();
      await store.close();
      expect(await File(read.path).exists(), isFalse);
      store = await openStore(store.rootDirectory);
      expect(store.objectIds, [savedId]);
    },
  );

  test(
    'custom categories are recovered while unrelated files stay untouched',
    () async {
      await store.close();
      const custom = ProjectFileCategory('sample maps');
      final root = store.rootDirectory;
      final document = File(path.join(root, 'project.anthem'));
      await document.writeAsString('project document');
      final unknown = File(path.join(root, 'unknown', 'preserve.bin'));
      await unknown.parent.create();
      await unknown.writeAsString('unrecognized data');
      store = await ProjectFileStore.open(root, categories: [custom]);
      final write = await store.beginWrite(
        custom,
        baseName: 'Map',
        extension: 'json',
      );
      final id = await write.commit();
      await store.close();
      store = await ProjectFileStore.open(root, categories: [custom]);
      expect(store.objectIds, [id]);
      expect(id, 'sample maps/Map 01.json');
      expect(await document.readAsString(), 'project document');
      expect(await unknown.readAsString(), 'unrecognized data');
      expect(() => store.beginWrite(testFiles), throwsArgumentError);
      expect(
        () => store.beginWrite(
          const ProjectFileCategory('sample maps', isCache: true),
        ),
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
