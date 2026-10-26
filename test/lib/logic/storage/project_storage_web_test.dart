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

import 'package:anthem/logic/storage/project_asset_store.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/logic/storage/project_asset_category.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectModel project;
  setUp(() => project = ProjectModel.create());
  tearDown(() => project.dispose());
  test('desktop storage has an explicit unsupported boundary on web', () async {
    await expectLater(
      ProjectAssetStore.open(
        'project',
        categories: ProjectAssetCategory.defaults,
      ),
      throwsUnsupportedError,
    );
    final storage = ProjectStorage(rootDirectory: 'project', project: project);
    await expectLater(storage.assetStore, throwsUnsupportedError);
    await storage.close();
  });

  test(
    'closing storage before first use does not access the filesystem',
    () async {
      await ProjectStorage(rootDirectory: 'project', project: project).close();
    },
  );

  test('temporary desktop roots are explicitly unsupported on web', () {
    expect(
      () => ProjectStorage.temporary(project: project),
      throwsUnsupportedError,
    );
  });
}
