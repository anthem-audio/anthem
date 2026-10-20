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

import 'dart:io';

import 'package:anthem/logic/main_window_controller.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_file_store.dart';
import 'package:anthem/logic/storage/project_file_category.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/file_dialog_test_helpers.dart';

class _DocumentsProvider extends PathProviderPlatform {
  String? documents;
  _DocumentsProvider(this.documents);

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFileSelector selector;
  late Directory directory;
  late ProjectModel project;
  late DialogController dialogs;
  late RecordingDialog recordingDialog;
  late _DocumentsProvider documents;
  final controller = MainWindowController();

  setUp(() {
    final originalSelector = FileSelectorPlatform.instance;
    selector = FakeFileSelector();
    FileSelectorPlatform.instance = selector;
    addTearDown(() => FileSelectorPlatform.instance = originalSelector);

    directory = Directory.systemTemp.createTempSync('anthem_file_dialog_test_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final originalPreferences = SharedPreferencesAsyncPlatform.instance;
    final originalPaths = PathProviderPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    documents = _DocumentsProvider(path.join(directory.path, 'Documents'));
    PathProviderPlatform.instance = documents;
    ServiceRegistry.setSessionPreferences(SharedPreferencesAsync());
    addTearDown(() {
      ServiceRegistry.setSessionPreferences(null);
      SharedPreferencesAsyncPlatform.instance = originalPreferences;
      PathProviderPlatform.instance = originalPaths;
    });
    project = ProjectModel.create()..isDirty = true;
    AnthemStore.instance.projects[project.id] = project;
    ServiceRegistry.initializeProject(project);
    addTearDown(() => controller.closeProjectWithoutSaving(project.id));
    recordingDialog = RecordingDialog();
    dialogs = DialogController()..initialize(recordingDialog);
  });

  test(
    'cancelled Save As preserves the project path and dirty state',
    () async {
      project.filePath = path.join(
        directory.path,
        'previous',
        'previous.anthem',
      );

      expect(
        await controller.saveProject(
          project.id,
          true,
          dialogController: dialogs,
        ),
        isFalse,
      );

      expect(
        project.filePath,
        path.join(directory.path, 'previous', 'previous.anthem'),
      );
      expect(project.isDirty, isTrue);
      expect(directory.listSync(), isEmpty);
      expect(recordingDialog.shownCount, 0);
      expect(selector.saveInitialDirectory, directory.path);
    },
  );

  test(
    'first Save suggests and prepares the default projects folder',
    () async {
      expect(
        await controller.saveProject(
          project.id,
          false,
          dialogController: dialogs,
        ),
        isFalse,
      );
      final expected = path.join(documents.documents!, 'Anthem', 'Projects');
      expect(selector.saveInitialDirectory, expected);
      expect(Directory(expected).existsSync(), isTrue);
      expect(project.filePath, isNull);
      expect(project.isDirty, isTrue);
    },
  );

  test('a changed preference is used for the next new project save', () async {
    final custom = path.join(directory.path, 'Custom');
    await ServiceRegistry.applicationSettings.setProjectsDirectoryOverride(
      custom,
    );
    await controller.saveProject(project.id, true, dialogController: dialogs);
    expect(selector.saveInitialDirectory, custom);
    await ServiceRegistry.applicationSettings.setProjectsDirectoryOverride(
      null,
    );
    await controller.saveProject(project.id, true, dialogController: dialogs);
    expect(
      selector.saveInitialDirectory,
      path.join(documents.documents!, 'Anthem', 'Projects'),
    );
  });

  test(
    'an unavailable Documents directory allows the native save picker',
    () async {
      documents.documents = null;
      await controller.saveProject(project.id, true, dialogController: dialogs);
      expect(selector.saveInitialDirectory, isNull);
      expect(selector.saveCount, 1);
    },
  );

  test('an inaccessible default folder allows saving elsewhere', () async {
    final blocked = File(path.join(directory.path, 'Not a folder'))
      ..writeAsStringSync('existing');
    await ServiceRegistry.applicationSettings.setProjectsDirectoryOverride(
      path.join(blocked.path, 'Projects'),
    );
    selector.saveLocation = FileSaveLocation(path.join(directory.path, 'song'));
    expect(
      await controller.saveProject(project.id, true, dialogController: dialogs),
      isTrue,
    );
    expect(selector.saveInitialDirectory, isNull);
    expect(blocked.readAsStringSync(), 'existing');
  });

  test('deserialization keeps engine selection out of persistent content', () {
    final persistent = project.toJson();
    final jsonWithRuntimePath = {
      ...persistent,
      'enginePathOverride': 'path-from-project-file',
    };
    final restored = ProjectModel.fromJson(
      jsonWithRuntimePath,
      enginePathOverride: 'explicit-runtime-engine',
    );
    addTearDown(restored.dispose);
    expect(restored.engine.enginePathOverride, 'explicit-runtime-engine');
    expect(restored.toJson(), persistent);
    final defaultRestored = ProjectModel.fromJson(jsonWithRuntimePath);
    addTearDown(defaultRestored.dispose);
    expect(defaultRestored.engine.enginePathOverride, isNull);
    expect(defaultRestored.toJson(), persistent);
  });

  test(
    'Save As creates a folder and ordinary Save reuses its document',
    () async {
      selector.saveLocation = FileSaveLocation(
        path.join(directory.path, 'song'),
      );
      expect(
        await controller.saveProject(
          project.id,
          true,
          dialogController: dialogs,
        ),
        isTrue,
      );

      final savedPath = path.join(directory.path, 'song', 'song.anthem');
      expect(project.filePath, savedPath);
      expect(project.isDirty, isFalse);
      final contents = await readProjectFile(savedPath);
      expect(contents['tracks'], isNotEmpty);
      expect(
        contents['savedInSoftwareVersion'],
        currentProjectFileSoftwareVersion,
      );
      expect(
        selector.lastSaveOptions!.initialDirectory,
        path.join(documents.documents!, 'Anthem', 'Projects'),
      );
      expect(selector.lastSaveOptions!.suggestedName, 'New Project');
      expect(
        selector.lastSaveOptions!.confirmButtonText,
        'Create project folder',
      );

      final track = project.tracks[project.trackOrder.first]!;
      track.name = 'Updated track';
      project.isDirty = true;
      selector.saveLocation = null;
      expect(
        await controller.saveProject(
          project.id,
          false,
          dialogController: dialogs,
        ),
        isTrue,
      );

      final json = await readProjectFile(savedPath);
      expect(
        (json['tracks'] as Map)[track.id.toString()]['name'],
        'Updated track',
      );
      expect(selector.saveCount, 1);
      expect(project.isDirty, isFalse);
    },
  );

  test('project names preserve dots in the chosen folder name', () async {
    final folder = path.join(directory.path, 'Song.v2');
    selector.saveLocation = FileSaveLocation(folder);

    expect(
      await controller.saveProject(project.id, true, dialogController: dialogs),
      isTrue,
    );
    expect(project.filePath, path.join(folder, 'Song.v2.anthem'));
    expect(project.name, 'Song.v2');
  });

  test(
    'first Save creates the configured parent before showing selection',
    () async {
      final parent = path.join(directory.path, 'Projects');
      await ServiceRegistry.applicationSettings.setProjectsDirectoryOverride(
        parent,
      );
      expect(
        await controller.saveProject(
          project.id,
          false,
          dialogController: dialogs,
        ),
        isFalse,
      );
      expect(selector.lastSaveOptions!.initialDirectory, parent);
      expect(selector.lastSaveOptions!.suggestedName, 'New Project');
      expect(Directory(parent).existsSync(), isTrue);
      expect(Directory(parent).listSync(), isEmpty);
      expect(project.filePath, isNull);
      expect(project.isDirty, isTrue);
    },
  );

  test('Save As does not overwrite an existing folder', () async {
    final existing = Directory(path.join(directory.path, 'Existing'));
    await existing.create();
    final other = await File(path.join(existing.path, 'unrelated'))
        .writeAsString('keep');
    selector.saveLocation = FileSaveLocation(existing.path);
    await expectLater(
      controller.saveProject(project.id, true, dialogController: dialogs),
      throwsA(isA<FileSystemException>()),
    );
    expect(await other.readAsString(), 'keep');
    expect(existing.listSync().map((e) => e.path), [other.path]);
    expect(project.filePath, isNull);
    expect(project.isDirty, isTrue);
  });

  test(
    'an unavailable default directory still allows selection elsewhere',
    () async {
      final blocker = await File(path.join(directory.path, 'not-a-directory'))
          .writeAsString('keep');
      await ServiceRegistry.applicationSettings.setProjectsDirectoryOverride(
        blocker.path,
      );
      selector.saveLocation = FileSaveLocation(
        path.join(directory.path, 'Song'),
      );
      expect(
        await controller.saveProject(
          project.id,
          false,
          dialogController: dialogs,
        ),
        isTrue,
      );
      expect(selector.lastSaveOptions!.initialDirectory, isNull);
      expect(await blocker.readAsString(), 'keep');
    },
  );

  test(
    'failed folder loading preserves its files and releases the store root',
    () async {
      final root = Directory(path.join(directory.path, 'Invalid model'));
      await root.create();
      final unrelated = await File(path.join(root.path, 'keep'))
          .writeAsString('keep');
      final blocker = await File(
        path.join(root.path, ProjectFileCategory.pluginStates.directoryName),
      ).writeAsString('keep too');
      final document = File(path.join(root.path, 'Invalid.anthem'));
      await document.writeAsBytes(await encodeProjectFile(project));
      selector.selectedFile = XFile(document.path);
      expect(await controller.loadProject(dialogController: dialogs), isNull);
      expect(recordingDialog.shownCount, 1);
      expect(AnthemStore.instance.projects[project.id], same(project));
      expect(await unrelated.readAsString(), 'keep');
      expect(await blocker.readAsString(), 'keep too');
      await blocker.delete();
      final reopened = await ProjectFileStore.open(
        root.path,
        categories: ProjectFileCategory.defaults,
      );
      await reopened.close();
    },
  );

  test('a failed write preserves the previous path and dirty state', () async {
    final previousPath = path.join(directory.path, 'previous.anthem');
    project.filePath = previousPath;
    selector.saveLocation = FileSaveLocation(
      path.join(directory.path, 'missing-directory', 'song.anthem'),
    );

    await expectLater(
      controller.saveProject(project.id, true, dialogController: dialogs),
      throwsA(isA<FileSystemException>()),
    );
    expect(project.filePath, previousPath);
    expect(project.isDirty, isTrue);
  });

  test('cancelling log export does not write or show an error', () async {
    expect(await controller.exportLogs(dialogController: dialogs), isFalse);
    expect(directory.listSync(), isEmpty);
    expect(recordingDialog.shownCount, 0);
  });
}
