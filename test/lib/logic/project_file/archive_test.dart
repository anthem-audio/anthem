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

import 'package:anthem/logic/project_file/archive.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/directory.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:path/path.dart' as path;

const cache = ProjectAssetCategory('test cache', isCache: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProjectModel project;
  late ProjectStorage storage;
  late ProjectAssetStore store;
  late AssetScope scope;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anthem_archive_test_');
    project = ProjectModel.create();
    storage = ProjectStorage.temporary(
      categories: [ProjectAssetCategory.pluginStates, cache],
    );
    store = await storage.assetStore;
    scope = store.openScope();
  });

  tearDown(() async {
    await scope.close();
    await project.dispose();
    await storage.discard();
    await directory.delete(recursive: true);
  });

  Future<String> asset(
    List<int> bytes, {
    String category = 'plugin states',
  }) async {
    final write = await scope.beginWrite(category, extension: 'bin');
    await File(write.absolutePath).writeAsBytes(bytes);
    return scope.commitWrite(write.token);
  }

  Future<File> zip(Iterable<ArchiveFile> entries) async {
    final archive = Archive();
    for (final entry in entries) {
      archive.add(entry);
    }
    return File(path.join(directory.path, 'input.zip'))
        .writeAsBytes(ZipEncoder().encodeBytes(archive));
  }

  Future<Set<String>> importDirectories() async => {
    await for (final entry in Directory.systemTemp.list())
      if (path.basename(entry.path).startsWith('anthem_project_import_') &&
          await File(path.join(entry.path, '${project.id}.anthem')).exists())
        entry.path,
  };

  test(
    'round trip exports only current references and can be saved as a folder',
    () async {
      final current = await asset([1, 2, 3, 255]);
      final historyOnly = await asset([4, 5]);
      final history = storage.retainAssets([historyOnly]);
      addTearDown(history.dispose);
      await asset([6, 7]);
      await asset([8, 9], category: cache.directoryName);
      final id = storage.projectFiles.retain(current);
      project.processingGraph.nodes.values.first.processorStateRetentionId = id;
      project.filePath = path.join(directory.path, 'Original.anthem');
      project.isDirty = true;
      final before = project.toJson();
      final output = path.join(directory.path, 'portable.zip');
      final prepared = await PreparedProjectSave.prepare(project, storage);
      try {
        await writeProjectArchive(output, prepared);
      } finally {
        await prepared.close();
      }
      expect(project.toJson(), before);
      expect(project.isDirty, isTrue);
      expect(project.filePath, path.join(directory.path, 'Original.anthem'));
      final archive = ZipDecoder().decodeBytes(
        await File(output).readAsBytes(),
      );
      expect(archive.files.map((entry) => entry.name).toSet(), {
        'project.anthem',
        current,
      });
      final extracted = await extractProjectArchive(XFile(output));
      final imported = ProjectModel.fromJson(
        await readProjectFile(extracted.documentPath),
      );
      final importedStorage = ProjectStorage.temporary(
        rootDirectory: extracted.rootDirectory,
      );
      try {
        await importedStorage.restoreProjectFiles(
          Map<String, String>.from(jsonDecode(imported.fileRetentions) as Map),
        );
        final importedStore = await importedStorage.assetStore;
        expect(importedStore.projectAssetPaths, [current]);
        expect(jsonDecode(imported.fileRetentions), {id: current});
        expect(
          await File(path.join(extracted.rootDirectory, current)).readAsBytes(),
          [1, 2, 3, 255],
        );
        expect(imported.toJson(), {
          ...before,
          'fileRetentions': jsonEncode({id: current}),
        });
        final saved = path.join(directory.path, 'Saved', 'Saved.anthem');
        final folderSave = await PreparedProjectSave.prepare(
          imported,
          importedStorage,
        );
        try {
          final result = await writeProjectDirectory(
            saved,
            folderSave,
            create: true,
          );
          expect(result.usesWorkingStore, isFalse);
          expect(await readProjectFile(saved), folderSave.projectJson);
        } finally {
          await folderSave.close();
        }
        expect(
          await File(path.join(path.dirname(saved), current)).readAsBytes(),
          [1, 2, 3, 255],
        );
      } finally {
        await imported.dispose();
        await importedStorage.discard();
      }
      expect(await Directory(extracted.rootDirectory).exists(), isFalse);
      expect(await File(output).exists(), isTrue);
    },
  );

  test(
    'byte archives and streamed native archives use the same format',
    () async {
      final current = await asset([5, 4, 3, 2, 1]);
      storage.projectFiles.retain(current);
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      final downloaded = await encodeProjectArchive(prepared);
      final input = await File(path.join(directory.path, 'download.zip'))
          .writeAsBytes(downloaded);
      final streamed = path.join(directory.path, 'native.zip');
      await writeProjectArchive(streamed, prepared);
      final imports = [
        await extractProjectArchive(XFile(input.path)),
        await extractProjectArchiveBytes(await File(streamed).readAsBytes()),
      ];
      for (final imported in imports) {
        try {
          expect(
            await readProjectFile(imported.documentPath),
            prepared.projectJson,
          );
          expect(
            await File(path.join(imported.rootDirectory, current))
                .readAsBytes(),
            [5, 4, 3, 2, 1],
          );
        } finally {
          await Directory(imported.rootDirectory).delete(recursive: true);
        }
      }
    },
  );

  test('failed export preserves an existing ZIP and cleans staging', () async {
    final current = await asset([1, 2, 3]);
    final id = storage.projectFiles.retain(current);
    final prepared = await PreparedProjectSave.prepare(project, storage);
    addTearDown(prepared.close);
    await File(prepared.assets.reads[current]!.absolutePath).delete();
    final output = await File(path.join(directory.path, 'existing.zip'))
        .writeAsBytes([42, 43]);
    await expectLater(
      writeProjectArchive(output.path, prepared),
      throwsA(anything),
    );
    expect(await output.readAsBytes(), [42, 43]);
    storage.projectFiles.releaseRetention(id);
    await prepared.close();
    await scope.close();
    await storage.close();
    expect(
      (await directory.list().toList()).map(
        (entry) => path.basename(entry.path),
      ),
      ['existing.zip'],
    );
  });

  test(
    'ZIP output consumes the prepared document and files after later edits',
    () async {
      final original = await asset([1, 2, 3]);
      final id = storage.projectFiles.retain(original);
      final prepared = await PreparedProjectSave.prepare(project, storage);
      addTearDown(prepared.close);
      storage.projectFiles.releaseRetention(id);
      final replacement = await asset([4, 5, 6]);
      storage.projectFiles.retain(replacement);
      project.sequence.beatsPerMinuteRaw = 15000;

      final output = path.join(directory.path, 'frozen.zip');
      await writeProjectArchive(output, prepared);
      await prepared.close();
      await scope.delete(original);
      final archive = ZipDecoder().decodeBytes(
        await File(output).readAsBytes(),
      );
      expect(archive.files.map((entry) => entry.name).toSet(), {
        'project.anthem',
        original,
      });
      expect(archive.findFile(original)!.content, [1, 2, 3]);
      final extracted = await extractProjectArchive(XFile(output));
      try {
        expect(
          await readProjectFile(extracted.documentPath),
          prepared.projectJson,
        );
      } finally {
        await Directory(extracted.rootDirectory).delete(recursive: true);
      }
    },
  );

  test(
    'accepts a renamed root document and explicit asset directories',
    () async {
      final input = await zip([
        ArchiveFile.directory('plugin states/'),
        ArchiveFile.bytes('Song.anthem', await encodeProjectFile(project)),
        ArchiveFile.bytes('plugin states/state.bin', [1, 2, 3]),
      ]);
      final extracted = await extractProjectArchive(XFile(input.path));
      try {
        expect(path.basename(extracted.documentPath), 'Song.anthem');
        expect(await readProjectFile(extracted.documentPath), project.toJson());
      } finally {
        await Directory(extracted.rootDirectory).delete(recursive: true);
      }
    },
  );

  test('rejects missing and ambiguous root documents', () async {
    for (final names in [
      <String>[],
      ['folder/project.anthem'],
      ['a.anthem', 'b.anthem'],
    ]) {
      final input = await zip([
        for (final name in names) ArchiveFile.bytes(name, [1, 2, 3]),
      ]);
      await expectLater(
        extractProjectArchive(XFile(input.path)),
        throwsA(isA<InvalidProjectFileException>()),
      );
    }
  });

  test(
    'rejects escaping, nonportable and case-colliding archive paths',
    () async {
      for (final names in [
        ['../escaped.bin'],
        ['/escaped.bin'],
        [r'C:\escaped.bin'],
        ['plugin states/../escaped.bin'],
        ['plugin states/state.bin:stream'],
        ['plugin states/NUL.bin'],
        ['plugin states/trailing.'],
        ['plugin states/a.bin', 'plugin states/A.bin'],
        ['plugin states/a.bin', 'Plugin States/b.bin'],
      ]) {
        final input = await zip([
          ArchiveFile.bytes('project.anthem', await encodeProjectFile(project)),
          for (final name in names) ArchiveFile.bytes(name, [1, 2, 3]),
        ]);
        await expectLater(
          extractProjectArchive(XFile(input.path)),
          throwsA(isA<InvalidProjectFileException>()),
          reason: '$names',
        );
      }
    },
  );

  test('rejects symbolic links', () async {
    final link = ArchiveFile.string('plugin states/link.bin', '../../outside')
      ..mode = 0xa1ff;
    final input = await zip([
      ArchiveFile.bytes('project.anthem', await encodeProjectFile(project)),
      link,
    ]);
    await expectLater(
      extractProjectArchive(XFile(input.path)),
      throwsA(isA<InvalidProjectFileException>()),
    );
  });

  test(
    'rejects duplicate ZIP entries even when the decoder merges them',
    () async {
      final input = await zip([
        ArchiveFile.bytes('project.anthem', await encodeProjectFile(project)),
        ArchiveFile.bytes('plugin states/a.bin', [1]),
        ArchiveFile.bytes('plugin states/b.bin', [2]),
      ]);
      // Replace both local and central names without changing their lengths.
      final contents = latin1
          .decode(await input.readAsBytes())
          .replaceAll('plugin states/b.bin', 'plugin states/a.bin');
      await input.writeAsBytes(latin1.encode(contents));
      await expectLater(
        extractProjectArchive(XFile(input.path)),
        throwsA(isA<InvalidProjectFileException>()),
      );
    },
  );

  test('corrupt asset contents fail CRC verification and remove partial extraction', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          '${project.id}.anthem',
          await encodeProjectFile(project),
        ),
      )
      ..add(
        ArchiveFile.noCompress('plugin states/state.bin', 5, [
          231,
          132,
          91,
          64,
          202,
        ]),
      );
    final bytes = ZipEncoder().encodeBytes(archive);
    final position = latin1
        .decode(bytes)
        .indexOf(latin1.decode([231, 132, 91, 64, 202]));
    expect(bytes.sublist(position, position + 5), [231, 132, 91, 64, 202]);
    bytes[position] = 230;
    final input = await File(path.join(directory.path, 'corrupt.zip'))
        .writeAsBytes(bytes);
    final before = await importDirectories();
    await expectLater(
      extractProjectArchive(XFile(input.path)),
      throwsA(isA<InvalidProjectFileException>()),
    );
    expect(await importDirectories(), before);
  });

  test('reports an unreadable ZIP as a file read failure', () async {
    await expectLater(
      extractProjectArchive(XFile(path.join(directory.path, 'missing.zip'))),
      throwsA(isA<ProjectFileReadException>()),
    );
  });
}
