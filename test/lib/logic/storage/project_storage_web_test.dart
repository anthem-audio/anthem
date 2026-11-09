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

@TestOn('browser')
library;

import 'package:anthem/logic/storage/asset_file_io.dart' as files;
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:anthem/logic/storage/file_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/browser_engine_test_helpers.dart';

const _cache = ProjectAssetCategory('cache', isCache: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => loadBrowserModule('AnthemFileSystem'));

  test(
    'closing unused temporary storage does not create its directory',
    () async {
      final storage = ProjectStorage.temporary();
      expect(await files.entryExists(storage.rootDirectory), isFalse);
      await storage.discard();
      expect(await files.entryExists(storage.rootDirectory), isFalse);
    },
  );

  test(
    'browser scopes share committed files, fingerprints, and cache rules',
    () async {
      final storage = ProjectStorage.temporary(
        categories: [ProjectAssetCategory.pluginStates, _cache],
      );
      final writer = await storage.openScope();
      try {
        final write = await writer.beginWrite(
          'plugin states',
          baseName: 'State',
          extension: 'bin',
        );
        await files.writeFile(write.absolutePath, [1, 2, 3, 255]);
        final file = await writer.commitWrite(write.token);
        final id = storage.projectFiles.retain(file);
        expect(file, 'plugin states/State 01.bin');
        final read = storage.projectFiles.acquireRead(file);
        final expected = FileFingerprint.fromBytes([1, 2, 3, 255]);
        final fingerprint = await storage.projectFiles.getFingerprint(
          read.token,
        );
        expect(fingerprint.toJson(), expected.toJson());
        expect(await files.readFile(read.absolutePath), [1, 2, 3, 255]);
        storage.projectFiles.releaseRead(read.token);
        storage.projectFiles.releaseRetention(id);
        await writer.delete(file);

        final pendingCache = await storage.projectFiles.beginWrite('cache');
        await files.writeFile(pendingCache.absolutePath, [9, 8, 7]);
        final cached = await storage.projectFiles.commitWrite(
          pendingCache.token,
        );
        expect(() => storage.projectFiles.retain(cached), throwsStateError);
        final cachedRead = storage.projectFiles.acquireRead(cached);
        expect(await files.readFile(cachedRead.absolutePath), [9, 8, 7]);
        storage.projectFiles.releaseRead(cachedRead.token);
        final cachePath = cachedRead.absolutePath;
        await writer.close();
        await storage.close();
        expect(await files.entryExists(cachePath), isFalse);
      } finally {
        await writer.close();
        await storage.discard();
      }
      expect(await files.entryExists(storage.rootDirectory), isFalse);
    },
  );

  test(
    'browser snapshots keep files readable after their original claims end',
    () async {
      final storage = ProjectStorage.temporary();
      final writer = await storage.openScope();
      AssetSnapshot? snapshot;
      try {
        final write = await writer.beginWrite('plugin states');
        await files.writeFile(write.absolutePath, [4, 2]);
        final file = await writer.commitWrite(write.token);
        final id = storage.projectFiles.retain(file);
        final runtimeOnlyWrite = await writer.beginWrite('plugin states');
        final runtimeOnly = await writer.commitWrite(runtimeOnlyWrite.token);
        final retained = storage.retainAssets([runtimeOnly]);
        snapshot = storage.projectFiles.snapshot();
        storage.projectFiles.releaseRetention(id);
        expect(snapshot.references, {id: file});
        expect(snapshot.reads.keys, [file]);
        expect(await files.readFile(snapshot.reads[file]!.absolutePath), [
          4,
          2,
        ]);
        expect(() => writer.delete(file), throwsStateError);
        await snapshot.close();
        await writer.delete(file);
        expect(() => writer.delete(runtimeOnly), throwsStateError);
        retained.dispose();
        await writer.delete(runtimeOnly);
      } finally {
        await snapshot?.close();
        await writer.close();
        await storage.discard();
      }
    },
  );
}
