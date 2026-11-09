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

import 'package:anthem/logic/project_file/project_save.dart';
import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late ProjectStorage storage;
  late AssetScope writer;
  late SavedProjectFiles documents;
  late String originalDocument;
  late String otherDocument;

  setUp(() async {
    storage = ProjectStorage.temporary();
    writer = await storage.openScope();
    documents = SavedProjectFiles(storage);
    originalDocument = path.join(storage.rootDirectory, 'Original.anthem');
    otherDocument = path.join(storage.rootDirectory, 'Other.anthem');
  });

  tearDown(() async {
    documents.dispose();
    await writer.close();
    await storage.discard();
  });

  Future<String> asset() async {
    final write = await writer.beginWrite('plugin states');
    return writer.commitWrite(write.token);
  }

  test(
    'recording protects files independently of current project claims',
    () async {
      final file = await asset();
      final id = storage.projectFiles.retain(file);
      documents.record(originalDocument, [file]);
      storage.projectFiles.releaseRetention(id);
      expect(storage.projectFiles.references, isEmpty);
      expect(() => writer.delete(file), throwsStateError);

      documents.dispose();
      documents.dispose();
      await writer.delete(file);
    },
  );

  test(
    'replacing one document preserves files used by another document',
    () async {
      final original = await asset();
      final replacement = await asset();
      documents.record(originalDocument, [original]);
      documents.record(otherDocument, [original]);
      documents.record(originalDocument, [replacement]);
      expect(() => writer.delete(original), throwsStateError);
      expect(() => writer.delete(replacement), throwsStateError);

      documents.record(otherDocument, [replacement]);
      await writer.delete(original);
      expect(() => writer.delete(replacement), throwsStateError);
      documents.dispose();
      await writer.delete(replacement);
    },
  );

  test(
    'failed replacement preserves previous claims without leaking new ones',
    () async {
      final original = await asset();
      final replacement = await asset();
      documents.record(originalDocument, [original]);
      expect(
        () => documents.record(originalDocument, [
          replacement,
          'plugin states/missing.bin',
        ]),
        throwsStateError,
      );
      expect(() => writer.delete(original), throwsStateError);
      await writer.delete(replacement);

      documents.record(originalDocument, []);
      await writer.delete(original);
    },
  );

  test('equivalent document paths replace the same claims', () async {
    final original = await asset();
    final replacement = await asset();
    documents.record(originalDocument, [original]);
    documents.record(path.join(storage.rootDirectory, '.', 'Original.anthem'), [
      replacement,
    ]);
    await writer.delete(original);
    expect(() => writer.delete(replacement), throwsStateError);
  });
}
