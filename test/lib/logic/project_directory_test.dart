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

import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/directory.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const _cache = ProjectFileCategory('test cache', isCache: true);
const _states = ProjectFileCategory.pluginStates;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late ProjectStorage storage;
  late ProjectFileStore store;
  late ProjectModel project;
  late String session;

  Future<String> write(
    String content, {
    ProjectFileCategory category = _states,
  }) async {
    final pending = await store.beginWrite(
      session,
      category.directoryName,
      baseName: 'State',
      extension: 'bin',
    );
    await File(pending.absolutePath).writeAsString(content);
    return store.commitWrite(session, pending.token);
  }

  setUp(() async {
    parent = await Directory.systemTemp.createTemp('anthem_project_directory_');
    storage = ProjectStorage.temporary(categories: [_states, _cache]);
    store = await storage.fileStore;
    session = store.openSession();
    project = ProjectModel.create();
  });

  tearDown(() async {
    await store.closeSession(session);
    await storage.discard();
    project.dispose();
    await parent.delete(recursive: true);
  });

  test('first save copies completed data, excludes caches and pending writes, and survives moving', () async {
    final relativePath = await write('required state');
    await write('cache', category: _cache);
    final pending = await store.beginWrite(session, _states.directoryName);
    await File(pending.absolutePath).writeAsString('incomplete');
    final read = store.acquireRead(session, relativePath);
    final root = path.join(parent.path, 'Song');
    final document = path.join(root, 'Song.anthem');

    await writeProjectDirectory(document, project, store, create: true);
    expect(await File(read.absolutePath).readAsString(), 'required state');
    expect(
      (await readProjectFile(document))['savedInSoftwareVersion'],
      currentProjectFileSoftwareVersion,
    );
    expect(await readProjectFile(document), project.toJson());
    expect(
      await Directory(path.join(root, _cache.directoryName)).exists(),
      isFalse,
    );
    expect(
      await Directory(root)
          .list(recursive: true)
          .where((e) => e is File)
          .length,
      2,
    );
    expect(await Directory(parent.path).list().length, 1);

    // Relative paths remain valid independently of both the live store and
    // the name/location of the saved project directory.
    final moved = await Directory(root).rename(path.join(parent.path, 'Moved'));
    final reopened = await ProjectFileStore.open(
      moved.path,
      categories: ProjectFileCategory.defaults,
    );
    try {
      expect(reopened.projectFilePaths, [relativePath]);
      final client = reopened.openSession();
      final savedRead = reopened.acquireRead(client, relativePath);
      expect(
        await File(savedRead.absolutePath).readAsString(),
        'required state',
      );
      await reopened.closeSession(client);
    } finally {
      await reopened.close();
    }
  });

  test('Save As and subsequent saves preserve the original snapshot', () async {
    final first = await write('first');
    final original = path.join(parent.path, 'Original', 'Original.anthem');
    await writeProjectDirectory(original, project, store, create: true);
    final originalBytes = await File(original).readAsBytes();
    final second = await write('second');
    project.sequence.beatsPerMinuteRaw = 14000;
    final copy = path.join(parent.path, 'Copy', 'Copy.anthem');
    await writeProjectDirectory(copy, project, store, create: true);
    final third = await write('third');
    project.sequence.beatsPerMinuteRaw = 15000;
    await writeProjectDirectory(copy, project, store, create: false);

    expect(await File(original).readAsBytes(), originalBytes);
    expect(
      await File(path.join(path.dirname(original), second)).exists(),
      isFalse,
    );
    expect(
      await File(path.join(path.dirname(original), third)).exists(),
      isFalse,
    );
    for (final relativePath in [first, second, third]) {
      expect(
        await File(path.join(path.dirname(copy), relativePath)).exists(),
        isTrue,
      );
    }
    expect(
      (await readProjectFile(copy))['sequence']['beatsPerMinuteRaw'],
      15000,
    );
    expect(
      await Directory(path.dirname(copy))
          .list()
          .any((e) => path.basename(e.path).startsWith('.anthem-save-')),
      isFalse,
    );
  });

  test(
    'copy failure removes a new directory staging area and releases reads',
    () async {
      final relativePath = await write('lost source');
      final read = store.acquireRead(session, relativePath);
      await File(read.absolutePath).delete();
      store.releaseRead(session, read.token);
      final document = path.join(parent.path, 'Failed', 'Failed.anthem');
      await expectLater(
        writeProjectDirectory(document, project, store, create: true),
        throwsA(isA<FileSystemException>()),
      );
      expect(await parent.list().toList(), isEmpty);
      // An accidentally retained snapshot session would prevent this close.
      await store.closeSession(session);
      await storage.close();
    },
  );

  test(
    'a failed later save preserves the previous document and source storage',
    () async {
      await write('original');
      final document = path.join(parent.path, 'Song', 'Song.anthem');
      await writeProjectDirectory(document, project, store, create: true);
      final previous = await File(document).readAsBytes();
      final missing = await write('missing');
      final read = store.acquireRead(session, missing);
      await File(read.absolutePath).delete();
      store.releaseRead(session, read.token);
      project.sequence.beatsPerMinuteRaw = 15000;
      await expectLater(
        writeProjectDirectory(document, project, store, create: false),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(document).readAsBytes(), previous);
      expect(await Directory(storage.rootDirectory).exists(), isTrue);
      expect(
        await Directory(path.dirname(document))
            .list()
            .any((e) => path.basename(e.path).startsWith('.anthem-save-')),
        isFalse,
      );
    },
  );

  test(
    'existing folders and files are never replaced by a new project',
    () async {
      for (final isFile in [false, true]) {
        final root = path.join(parent.path, isFile ? 'File' : 'Folder');
        if (isFile) {
          await File(root).writeAsString('keep');
        } else {
          await Directory(root).create();
          await File(path.join(root, 'unrelated')).writeAsString('keep');
        }
        await expectLater(
          writeProjectDirectory(
            path.join(root, 'Song.anthem'),
            project,
            store,
            create: true,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          await File(isFile ? root : path.join(root, 'unrelated'))
              .readAsString(),
          'keep',
        );
      }
    },
  );
}
