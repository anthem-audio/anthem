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

import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/directory.dart';
import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const _cache = ProjectAssetCategory('test cache', isCache: true);
const _states = ProjectAssetCategory.pluginStates;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late ProjectStorage storage;
  late ProjectAssetStore store;
  late ProjectModel project;
  late AssetScope scope;
  final claims = <String, String>{};

  Future<String> write(
    String content, {
    ProjectAssetCategory category = _states,
  }) async {
    final pending = await scope.beginWrite(
      category.directoryName,
      baseName: 'State',
      extension: 'bin',
    );
    await File(pending.absolutePath).writeAsString(content);
    final relativePath = await scope.commitWrite(pending.token);
    if (!category.isCache) {
      claims[relativePath] = storage.projectFiles.retain(relativePath);
    }
    return relativePath;
  }

  void removeState(String relativePath) =>
      storage.projectFiles.releaseRetention(claims.remove(relativePath)!);

  setUp(() async {
    parent = await Directory.systemTemp.createTemp('anthem_project_directory_');
    claims.clear();
    project = ProjectModel.create();
    storage = ProjectStorage.temporary(categories: [_states, _cache]);
    store = await storage.assetStore;
    scope = store.openScope();
  });

  tearDown(() async {
    await scope.close();
    await project.dispose();
    await storage.discard();
    await parent.delete(recursive: true);
  });

  test('first save copies prepared files, excludes caches and pending writes, and survives moving', () async {
    final relativePath = await write('required state');
    await write('cache', category: _cache);
    final pending = await scope.beginWrite(_states.directoryName);
    await File(pending.absolutePath).writeAsString('incomplete');
    final prepared = await PreparedProjectSave.prepare(project, storage);
    addTearDown(prepared.close);
    final root = path.join(parent.path, 'Song');
    final document = path.join(root, 'Song.anthem');

    final result = await writeProjectDirectory(
      document,
      prepared,
      create: true,
    );
    expect(result.usesWorkingStore, isFalse);
    expect(await readProjectFile(document), prepared.projectJson);
    expect(
      (await readProjectFile(document))['savedInSoftwareVersion'],
      currentProjectFileSoftwareVersion,
    );
    expect(
      jsonDecode((await readProjectFile(document))['fileRetentions'] as String),
      {claims[relativePath]!: relativePath},
    );
    expect(
      await File(path.join(storage.rootDirectory, relativePath)).readAsString(),
      'required state',
    );
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
    expect(await parent.list().length, 1);
    await prepared.close();

    // The exported paths remain valid after the directory is moved.
    final moved = await Directory(root).rename(path.join(parent.path, 'Moved'));
    final reopened = await ProjectAssetStore.open(
      moved.path,
      categories: ProjectAssetCategory.defaults,
    );
    final client = reopened.openScope();
    try {
      expect(reopened.projectAssetPaths, [relativePath]);
      final savedRead = client.acquireRead(relativePath);
      expect(
        await File(savedRead.absolutePath).readAsString(),
        'required state',
      );
    } finally {
      await client.close();
      await reopened.close();
    }
  });

  test(
    'Save As and subsequent saves preserve the original document and files',
    () async {
      final first = await write('first');
      final original = path.join(parent.path, 'Original', 'Original.anthem');
      final initial = await PreparedProjectSave.prepare(project, storage);
      addTearDown(initial.close);
      await writeProjectDirectory(original, initial, create: true);
      await initial.close();
      final originalBytes = await File(original).readAsBytes();

      final second = await write('second');
      project.sequence.beatsPerMinuteRaw = 14000;
      final copy = path.join(parent.path, 'Copy', 'Copy.anthem');
      final saveAs = await PreparedProjectSave.prepare(project, storage);
      addTearDown(saveAs.close);
      await writeProjectDirectory(copy, saveAs, create: true);
      await saveAs.close();

      final third = await write('third');
      project.sequence.beatsPerMinuteRaw = 15000;
      final updated = await PreparedProjectSave.prepare(project, storage);
      addTearDown(updated.close);
      await writeProjectDirectory(copy, updated, create: false);
      await updated.close();

      expect(await File(original).readAsBytes(), originalBytes);
      for (final relativePath in [second, third]) {
        expect(
          await File(path.join(path.dirname(original), relativePath)).exists(),
          isFalse,
        );
      }
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
    },
  );

  test('reusing a deleted filename replaces an obsolete saved copy', () async {
    final old = await write('old contents');
    final document = path.join(parent.path, 'Song', 'Song.anthem');
    final initial = await PreparedProjectSave.prepare(project, storage);
    addTearDown(initial.close);
    await writeProjectDirectory(document, initial, create: true);
    await initial.close();
    removeState(old);
    final removed = await PreparedProjectSave.prepare(project, storage);
    addTearDown(removed.close);
    await writeProjectDirectory(document, removed, create: false);
    await removed.close();
    await scope.delete(old);
    expect(store.relativePaths, isEmpty);

    final replacement = await write('replacement contents');
    expect(replacement, old);
    final destination = File(path.join(path.dirname(document), old));
    expect(await destination.readAsString(), 'old contents');
    final updated = await PreparedProjectSave.prepare(project, storage);
    addTearDown(updated.close);
    await writeProjectDirectory(document, updated, create: false);
    await updated.close();
    expect(await destination.readAsString(), 'replacement contents');
  });

  test(
    'ordinary Save replaces destination copies and restores missing files',
    () async {
      final relativePath = await write('state');
      final document = path.join(parent.path, 'Song', 'Song.anthem');
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      await writeProjectDirectory(document, prepared, create: true);
      final saved = File(path.join(path.dirname(document), relativePath));
      await saved.writeAsString('outdated destination contents');
      final result = await writeProjectDirectory(
        document,
        prepared,
        create: false,
      );
      expect(result.usesWorkingStore, isFalse);
      expect(await saved.readAsString(), 'state');

      await saved.delete();
      await writeProjectDirectory(document, prepared, create: false);
      expect(await saved.readAsString(), 'state');
    },
  );

  test(
    'a reopened project reports whether the writer uses its working store',
    () async {
      final saved = await write('original');
      final document = path.join(parent.path, 'Original', 'Original.anthem');
      final initial = await PreparedProjectSave.prepare(project, storage);
      addTearDown(initial.close);
      await writeProjectDirectory(document, initial, create: true);
      await initial.close();
      final reopenedProject = ProjectModel.fromJson(
        await readProjectFile(document),
      );
      final reopenedStorage = ProjectStorage(
        rootDirectory: path.dirname(document),
      );
      try {
        await reopenedStorage.restoreProjectFiles(
          Map<String, String>.from(
            jsonDecode(reopenedProject.fileRetentions) as Map,
          ),
        );
        final prepared = await PreparedProjectSave.prepare(
          reopenedProject,
          reopenedStorage,
        );
        try {
          final copy = path.join(parent.path, 'Copy', 'Copy.anthem');
          final copied = await writeProjectDirectory(
            copy,
            prepared,
            create: true,
          );
          expect(copied.usesWorkingStore, isFalse);
          final inPlace = await writeProjectDirectory(
            document,
            prepared,
            create: false,
          );
          expect(inPlace.usesWorkingStore, isTrue);
          for (final root in [path.dirname(copy), path.dirname(document)]) {
            expect(
              await File(path.join(root, saved)).readAsString(),
              'original',
            );
          }
        } finally {
          await prepared.close();
        }
      } finally {
        await reopenedProject.dispose();
        await reopenedStorage.close();
      }
    },
  );

  test('an in-place save rejects a state file removed from disk', () async {
    final file = await write('saved state');
    final document = path.join(parent.path, 'Original', 'Original.anthem');
    final initial = await PreparedProjectSave.prepare(project, storage);
    addTearDown(initial.close);
    await writeProjectDirectory(document, initial, create: true);
    await initial.close();
    final before = await File(document).readAsBytes();
    final savedProject = ProjectModel.fromJson(await readProjectFile(document));
    final savedStorage = ProjectStorage(rootDirectory: path.dirname(document));
    try {
      await savedStorage.restoreProjectFiles(
        Map<String, String>.from(
          jsonDecode(savedProject.fileRetentions) as Map,
        ),
      );
      savedProject.sequence.beatsPerMinuteRaw = 15000;
      final prepared = await PreparedProjectSave.prepare(
        savedProject,
        savedStorage,
      );
      try {
        await File(path.join(path.dirname(document), file)).delete();
        await expectLater(
          writeProjectDirectory(document, prepared, create: false),
          throwsA(isA<FileSystemException>()),
        );
        expect(await File(document).readAsBytes(), before);
      } finally {
        await prepared.close();
      }
    } finally {
      await savedProject.dispose();
      await savedStorage.close();
    }
  });

  test(
    'document publication failure cleans staging and permits retry',
    () async {
      final original = await write('original');
      final document = path.join(parent.path, 'Song', 'Song.anthem');
      final initial = await PreparedProjectSave.prepare(project, storage);
      addTearDown(initial.close);
      await writeProjectDirectory(document, initial, create: true);
      await initial.close();
      final backup = await File(document).rename('$document.backup');
      final blocker = Directory(document);
      await blocker.create();
      await File(path.join(blocker.path, 'keep')).writeAsString('block rename');
      final replacement = await write('first attempt');
      final failed = await PreparedProjectSave.prepare(project, storage);
      addTearDown(failed.close);
      await expectLater(
        writeProjectDirectory(document, failed, create: false),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(path.join(store.rootDirectory, original)).readAsString(),
        'original',
      );
      removeState(replacement);
      // The caller owns the prepared data even when a writer fails.
      expect(() => scope.delete(replacement), throwsStateError);
      await failed.close();
      await scope.delete(replacement);
      final retry = await write('retry');
      expect(retry, replacement);
      await blocker.delete(recursive: true);
      await backup.rename(document);
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      await writeProjectDirectory(document, prepared, create: false);
      expect(
        await File(path.join(path.dirname(document), retry)).readAsString(),
        'retry',
      );
      expect(
        await Directory(path.dirname(document))
            .list()
            .any((e) => path.basename(e.path).startsWith('.anthem-save-')),
        isFalse,
      );
    },
  );

  test('copy failure removes a new directory staging area', () async {
    final relativePath = await write('lost source');
    final prepared = await PreparedProjectSave.prepare(project, storage);
    addTearDown(prepared.close);
    await File(path.join(storage.rootDirectory, relativePath)).delete();
    final document = path.join(parent.path, 'Failed', 'Failed.anthem');
    await expectLater(
      writeProjectDirectory(document, prepared, create: true),
      throwsA(isA<FileSystemException>()),
    );
    expect(await parent.list().toList(), isEmpty);
    await prepared.close();
    await scope.close();
    await storage.close();
  });

  test(
    'a failed later save preserves the previous document and source storage',
    () async {
      await write('original');
      final document = path.join(parent.path, 'Song', 'Song.anthem');
      final initial = await PreparedProjectSave.prepare(project, storage);
      addTearDown(initial.close);
      await writeProjectDirectory(document, initial, create: true);
      await initial.close();
      final previous = await File(document).readAsBytes();
      final missing = await write('missing');
      project.sequence.beatsPerMinuteRaw = 15000;
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      await File(path.join(storage.rootDirectory, missing)).delete();
      await expectLater(
        writeProjectDirectory(document, prepared, create: false),
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
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
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
            prepared,
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

  test(
    'a saved copy does not retain obsolete files in the working store',
    () async {
      final file = await write('copied state');
      final document = path.join(parent.path, 'Copy', 'Copy.anthem');
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      final result = await writeProjectDirectory(
        document,
        prepared,
        create: true,
      );
      expect(result.usesWorkingStore, isFalse);
      removeState(file);
      expect(() => scope.delete(file), throwsStateError);
      await prepared.close();
      await scope.delete(file);
      expect(
        await File(path.join(path.dirname(document), file)).readAsString(),
        'copied state',
      );
    },
  );
}
