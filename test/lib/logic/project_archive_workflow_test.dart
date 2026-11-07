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
import 'dart:convert';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/archive.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/format.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:archive/archive_io.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/file_dialog_test_helpers.dart';
import '../../fixtures/prealpha_1_project.dart';

class _NoDocumentsProvider extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => null;
}

// Keep the real file workflow and registration without starting a native engine.
class _Controller extends MainWindowController {
  @override
  Future<ProjectId> openProject(
    ProjectModel project, {
    bool startAudio = true,
    ProjectStorage? storage,
  }) async {
    registerProject(project, storage: storage);
    return project.id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProjectModel source;
  late ProjectStorage sourceStorage;
  late FakeFileSelector selector;
  late _Controller controller;
  late RecordingDialog recordingDialog;
  late DialogController dialogs;

  setUp(() async {
    final originalPreferences = SharedPreferencesAsyncPlatform.instance;
    final originalPaths = PathProviderPlatform.instance;
    final originalSelector = FileSelectorPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    PathProviderPlatform.instance = _NoDocumentsProvider();
    ServiceRegistry.setSessionPreferences(SharedPreferencesAsync());
    selector = FakeFileSelector();
    FileSelectorPlatform.instance = selector;
    addTearDown(() {
      ServiceRegistry.setSessionPreferences(null);
      SharedPreferencesAsyncPlatform.instance = originalPreferences;
      PathProviderPlatform.instance = originalPaths;
      FileSelectorPlatform.instance = originalSelector;
    });
    directory = await Directory.systemTemp.createTemp(
      'anthem_archive_workflow_test_',
    );
    controller = _Controller();
    source = ProjectModel.create();
    sourceStorage = ProjectStorage.temporary(project: source);
    controller.registerProject(source, storage: sourceStorage);
    recordingDialog = RecordingDialog();
    dialogs = DialogController()..initialize(recordingDialog);
  });

  tearDown(() async {
    for (final project in AnthemStore.instance.projects.values.toList()) {
      await controller.closeProjectWithoutSaving(project.id);
    }
    await directory.delete(recursive: true);
  });

  Future<String> sourceState() async {
    final store = await sourceStorage.assetStore;
    final scope = store.openScope();
    try {
      final write = await store.beginWrite(
        scope,
        'plugin states',
        extension: 'bin',
      );
      await File(write.absolutePath).writeAsBytes([4, 2, 6]);
      final file = await store.commitWrite(scope, write.token);
      source.processingGraph.nodes.values.first.processorStateRetentionId =
          sourceStorage.retainAssetForProject(file);
      return file;
    } finally {
      await store.closeScope(scope);
    }
  }

  test('export cancellation leaves the project untouched', () async {
    final before = source.toJson();
    expect(
      await controller.exportProjectZip(source.id, dialogController: dialogs),
      isFalse,
    );
    expect(source.toJson(), before);
    expect(recordingDialog.shownCount, 0);
    expect(await directory.list().toList(), isEmpty);
  });

  test('export leaves save location and dirty status unchanged', () async {
    await sourceState();
    source.filePath = path.join(directory.path, 'Original.anthem');
    for (final dirty in [false, true]) {
      source.isDirty = dirty;
      selector.saveLocation = FileSaveLocation(
        path.join(directory.path, 'portable'),
      );
      expect(
        await controller.exportProjectZip(source.id, dialogController: dialogs),
        isTrue,
      );
      expect(source.filePath, path.join(directory.path, 'Original.anthem'));
      expect(source.isDirty, dirty);
      expect(selector.lastSaveOptions!.suggestedName, 'Original.zip');
      expect(
        await File(path.join(directory.path, 'portable.zip')).exists(),
        isTrue,
      );
    }
    expect(recordingDialog.shownCount, 0);
  });

  test(
    'load ZIP opens an independent temporary copy and Save creates a folder',
    () async {
      final asset = await sourceState();
      final zip = path.join(directory.path, 'portable.zip');
      await writeProjectArchive(zip, source, sourceStorage);
      final originalBytes = await File(zip).readAsBytes();
      selector.selectedFile = XFile(zip);
      final id = await controller.loadProject(dialogController: dialogs);
      expect(id, isNotNull);
      expect(id, isNot(source.id));
      final imported = AnthemStore.instance.projects[id]!;
      final storage = ServiceRegistry.forProject(id!).projectStorage;
      expect(imported.filePath, isNull);
      expect(imported.isDirty, isTrue);
      expect(storage.isTemporary, isTrue);
      expect(storage.rootDirectory, isNot(sourceStorage.rootDirectory));
      expect(AnthemStore.instance.projects[source.id], same(source));
      expect(AnthemStore.instance.projectOrder, [source.id, imported.id]);
      expect(recordingDialog.shownCount, 0);
      expect(
        await File(path.join(storage.rootDirectory, asset)).readAsBytes(),
        [4, 2, 6],
      );
      selector.saveLocation = FileSaveLocation(
        path.join(directory.path, 'Saved'),
      );
      expect(
        await controller.saveProject(
          imported.id,
          false,
          dialogController: dialogs,
        ),
        isTrue,
      );
      final saved = path.join(directory.path, 'Saved', 'Saved.anthem');
      expect(imported.filePath, saved);
      expect(imported.isDirty, isFalse);
      expect(await readProjectFile(saved), imported.toJson());
      expect(await File(path.join(path.dirname(saved), asset)).readAsBytes(), [
        4,
        2,
        6,
      ]);
      await controller.closeProjectWithoutSaving(imported.id);
      expect(await Directory(storage.rootDirectory).exists(), isFalse);
      expect(await File(saved).exists(), isTrue);
      expect(await File(zip).readAsBytes(), originalBytes);
    },
  );

  test(
    'invalid archive references fail without registering or replacing projects',
    () async {
      await sourceState();
      final zip = path.join(directory.path, 'portable.zip');
      await writeProjectArchive(zip, source, sourceStorage);
      final archive = ZipDecoder().decodeBytes(await File(zip).readAsBytes());
      final documentName = '${source.id}.anthem';
      final incomplete = Archive()
        ..add(ArchiveFile.bytes(documentName, archive.files.first.content));
      final broken = path.join(directory.path, 'missing-assets.zip');
      await File(broken).writeAsBytes(ZipEncoder().encodeBytes(incomplete));
      selector.selectedFile = XFile(broken);
      expect(await controller.loadProject(dialogController: dialogs), isNull);
      expect(recordingDialog.shownCount, 1);
      expect(AnthemStore.instance.projects.values, [source]);
      expect(AnthemStore.instance.projectOrder, [source.id]);
      expect([
        await for (final entry in Directory.systemTemp.list())
          if (path.basename(entry.path).startsWith('anthem_project_import_') &&
              await File(path.join(entry.path, documentName)).exists())
            entry.path,
      ], isEmpty);
    },
  );

  test(
    'a legacy document in a ZIP uses the normal asset-producing migration',
    () async {
      final archive = Archive()
        ..add(
          ArchiveFile.bytes('Legacy.anthem', [
            ...projectFileHeader,
            ...gzip.encode(utf8.encode(prealpha1ProjectJson)),
          ]),
        );
      final file = await File(path.join(directory.path, 'legacy.zip'))
          .writeAsBytes(ZipEncoder().encodeBytes(archive));
      final originalBytes = await file.readAsBytes();
      selector.selectedFile = XFile(file.path);
      final id = await controller.loadProject(dialogController: dialogs);
      expect(id, isNotNull);
      final imported = AnthemStore.instance.projects[id]!;
      final storage = ServiceRegistry.forProject(id!).projectStorage;
      expect(imported.filePath, isNull);
      expect(imported.isDirty, isTrue);
      expect(storage.isTemporary, isTrue);
      expect(jsonDecode(imported.fileRetentions), isNotEmpty);
      for (final relative
          in (jsonDecode(imported.fileRetentions) as Map).values) {
        expect(
          await File(path.join(storage.rootDirectory, relative as String))
              .exists(),
          isTrue,
        );
      }
      expect(recordingDialog.shownCount, 0);
      expect(await file.readAsBytes(), originalBytes);
    },
  );
}
