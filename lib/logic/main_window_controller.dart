/*
  Copyright (C) 2021 - 2026 Joshua Wade

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

import 'dart:async';
import 'dart:io';

import 'package:anthem/helpers/logging/anthem_logging.dart';
import 'package:anthem/logic/project_file/codec.dart';
import 'package:anthem/logic/project_file/directory.dart';
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/migrations/migrate_project_json.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/storage/project_storage.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:file_selector/file_selector.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide TextBox;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as paths;

final _log = Logger('main_window_controller');
const _projectFileType = XTypeGroup(
  label: 'Anthem projects',
  extensions: ['anthem'],
);

@visibleForTesting
String projectFileLoadErrorMarkdown(Object error) {
  String version(ProjectFileVersion version) {
    return escapeDialogMarkdown(version.toString());
  }

  return switch (error) {
    ProjectDirectoryRequiresDesktopException() =>
      'Open this project folder in the desktop version of Anthem. '
          'The web version does not yet support importing project folders.',
    ProjectSavedInNewerVersionException error =>
      'This project was saved in a newer version of Anthem '
          '(${version(error.savedVersion)}). You are running Anthem '
          '${version(error.currentVersion)}.\n\n'
          'Update Anthem to that version or newer to open this project.',
    ProjectVersionTooOldException error =>
      'This project was saved in Anthem ${version(error.savedVersion)}, which '
          'is older than the oldest project version supported by this version '
          'of Anthem (${version(error.oldestSupportedVersion)}).',
    ProjectFileMigrationException(
      cause: MultipleArrangementsProjectFileException error,
    ) =>
      'This project contains ${error.arrangementCount} arrangements. This '
          'version of Anthem can only open projects containing one '
          'arrangement. The original project file was not changed.',
    ProjectFileMigrationException error =>
      'Anthem could not update this project from version '
          '${version(error.fromVersion)} to ${version(error.targetVersion)}. '
          'The original project file was not changed.\n\n'
          'Please report this problem and include your Anthem logs.',
    ProjectFileReadException() =>
      'Anthem could not read the selected project file. Check that the file '
          'still exists and that you have permission to open it.',
    InvalidProjectFileException() =>
      'Anthem could not read this project. The file may be damaged or may not '
          'be an Anthem project file. The original file was not changed.',
    _ =>
      'Anthem encountered an unexpected error while opening this project. '
          'The original project file was not changed.\n\n'
          'See the Anthem logs for more information.',
  };
}

class CursorOverrideHandle {
  final MainWindowController _controller;
  final int _id;

  bool _closed = false;

  CursorOverrideHandle._(this._controller, this._id);

  void close() {
    if (_closed) {
      return;
    }

    _closed = true;
    _controller._releaseCursorOverride(_id);
  }
}

class MainWindowController {
  final Map<ProjectId, Future<void>> _projectCloseFutures = {};
  final Map<int, MouseCursor> _cursorOverrides = {};
  int _nextCursorOverrideId = 0;

  /// Registers [project] and makes it active without starting its engine.
  ServiceRegistry registerProject(
    ProjectModel project, {
    ProjectStorage? storage,
  }) {
    final store = AnthemStore.instance;

    store.projects[project.id] = project;
    store.projectOrder.add(project.id);
    store.activeProjectId = project.id;
    final registry = ServiceRegistry.initializeProject(project);
    if (storage != null) registry.register(storage);
    return registry;
  }

  // Returns the ID of the new tab
  Future<ProjectId> newProject() async {
    return openProject(ProjectModel.create());
  }

  /// Registers [project] and starts its engine.
  Future<ProjectId> openProject(
    ProjectModel project, {
    bool startAudio = true,
    ProjectStorage? storage,
  }) async {
    final serviceRegistry = registerProject(project, storage: storage);
    await serviceRegistry.projectEngineController.start(startAudio: startAudio);

    return project.id;
  }

  void switchTab(ProjectId projectId) {
    AnthemStore.instance.activeProjectId = projectId;

    // Only enable visualizations for the selected project tab
    for (final project in AnthemStore.instance.projects.values) {
      project.visualizationProvider.setEnabled(projectId == project.id);
    }
  }

  /// Stops the engine before releasing project services and temporary files.
  Future<void> closeProjectWithoutSaving(ProjectId projectId) {
    return _projectCloseFutures.putIfAbsent(
      projectId,
      () => _closeProjectWithoutSaving(projectId).whenComplete(() {
        _projectCloseFutures.remove(projectId);
      }),
    );
  }

  Future<void> _closeProjectWithoutSaving(ProjectId projectId) async {
    final store = AnthemStore.instance;
    final project = store.projects[projectId];

    if (project == null) {
      return;
    }

    await project.engine.dispose();
    final storage = ServiceRegistry.maybeForProject(projectId)
        ?.get<ProjectStorage>();
    if (storage != null) {
      if (storage.isTemporary) {
        await storage.discard();
      } else {
        await storage.close();
      }
    }
    ServiceRegistry.removeProject(projectId);

    // Clean up project resources
    project.dispose();

    // Remove project from model
    store.projects.remove(projectId);
    store.projectOrder.remove(projectId);

    // If the active project was closed, set it to the first open project
    if (store.activeProjectId == projectId) {
      store.activeProjectId = store.projectOrder.firstOrNull ?? '';
    }
  }

  /// Returns the ID of the loaded project, or null if the project load failed
  /// or was cancelled. Engine selection and audio startup are runtime options;
  /// native selection, decoding, and migration use the normal file workflow.
  Future<ProjectId?> loadProject({
    required DialogController dialogController,
    String? engineExecutable,
    bool startAudio = true,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: [_projectFileType],
      initialDirectory:
          await ServiceRegistry.applicationSettings.projectsDirectory,
    );
    if (file == null) return null;

    final ProjectModel project;
    ProjectStorage? storage;
    final bool needsFolderSave;

    try {
      final projectJson = kIsWeb
          ? await decodeProjectFileBytes(await file.readAsBytes())
          : await readProjectFile(file.path);
      final savedVersion = readSavedProjectVersion(projectJson);
      // Projects used a single file before prealpha.2.
      needsFolderSave =
          savedVersion < ProjectFileVersion.parse('0.0.0-prealpha.2');
      migrateProjectJson(projectJson);
      if (!needsFolderSave) {
        if (kIsWeb) {
          throw const ProjectDirectoryRequiresDesktopException();
        }
        storage = ProjectStorage(rootDirectory: paths.dirname(file.path));
        await storage.fileStore;
      }

      project = ProjectModel.fromJson(
        projectJson,
        enginePathOverride: engineExecutable,
      );
    } catch (error, stackTrace) {
      await storage?.close();
      _log.warning('Could not load project file.', error, stackTrace);
      dialogController.showMarkdownDialog(
        title: 'Could not open project',
        markdown: projectFileLoadErrorMarkdown(error),
        buttons: [DialogButton.ok()],
      );
      return null;
    }

    project.filePath = needsFolderSave ? null : file.path;
    project.isDirty = needsFolderSave;

    final id = await openProject(
      project,
      startAudio: startAudio,
      storage: storage,
    );
    if (needsFolderSave && !kIsWeb) {
      dialogController.showMarkdownDialog(
        title: 'Save this project as a folder',
        markdown:
            'This project uses the older single-file format. '
            'It has been opened as an unsaved project and needs to be saved '
            'to a new project folder. The original file will be kept.',
        buttons: [DialogButton.ok()],
      );
    }
    return id;
  }

  Future<bool> saveProject(
    ProjectId projectId,
    bool alwaysUseFilePicker, {
    required DialogController dialogController,
  }) async {
    final project = AnthemStore.instance.projects[projectId]!;

    String? path;
    var createDirectory = false;

    if (!kIsWeb) {
      if (alwaysUseFilePicker || project.filePath == null) {
        final initialDirectory = await _projectSaveDirectory(project);
        final folder = (await getSaveLocation(
          initialDirectory: initialDirectory,
          suggestedName: project.name,
          confirmButtonText: 'Create project folder',
        ))?.path;
        if (folder != null) {
          final root = paths.normalize(paths.absolute(folder));
          path = paths.join(root, '${paths.basename(root)}.anthem');
          createDirectory =
              project.filePath == null ||
              !paths.equals(root, paths.dirname(project.filePath!));
          if (!createDirectory) path = project.filePath;
        }
      } else {
        path = project.filePath;
      }
    }

    if (!kIsWeb && path == null) return false;

    if (kIsWeb) {
      // Dialog to ask for filename

      final controller = TextEditingController();
      final completer = Completer<String?>();

      dialogController.showDialog(
        content: SizedBox(
          width: 300,
          height: 70,
          child: Column(
            spacing: 12,
            children: [
              Text(
                'Enter a file name for the project:',
                style: TextStyle(fontSize: 13, color: AnthemTheme.text.main),
              ),
              SizedBox(
                width: 161,
                child: Center(
                  child: TextBox(height: 26, controller: controller),
                ),
              ),
            ],
          ),
        ),
        title: 'Save',
        buttons: [
          DialogButton.cancel(),
          DialogButton(
            text: 'Download',
            onPress: () {
              completer.complete(controller.text);
            },
          ),
        ],
        onDismiss: () {
          completer.complete(null);
        },
      );

      final fileName = await completer.future;
      if (fileName == null) return false;

      try {
        final bytes = await encodeProjectFile(project);
        await XFile.fromData(
          bytes,
          name: '$fileName.anthem',
          mimeType: 'application/octet-stream',
        ).saveTo('$fileName.anthem');
      } catch (error, stackTrace) {
        _log.warning('Could not save project file.', error, stackTrace);

        dialogController.showMarkdownDialog(
          title: 'Save',
          markdown:
              'Could not save project:\n\n'
              '${escapeDialogMarkdown(error.toString())}',
          buttons: [DialogButton.ok()],
        );

        return false;
      }

      project.isDirty = false;
      return true;
    } else {
      // Load the latest for all plugin states before saving
      await Future.wait(
        project.processingGraph.nodes.values.map((node) {
          return node.updateStateFromEngine();
        }),
      );

      final storage = ServiceRegistry.forProject(projectId).projectStorage;
      var changedDuringSave = false;
      void onModelChange(ModelChangeEvent _) => changedDuringSave = true;
      project.addRawFieldChangedListener(onModelChange);
      try {
        await writeProjectDirectory(
          path!,
          project,
          await storage.fileStore,
          create: createDirectory,
        );
      } finally {
        project.removeRawFieldChangedListener(onModelChange);
      }

      project.isDirty = changedDuringSave;
      project.filePath = path;
      return true;
    }
  }

  Future<String?> _projectSaveDirectory(ProjectModel project) async {
    final existingPath = project.filePath;
    if (existingPath != null) return paths.dirname(paths.dirname(existingPath));

    try {
      final directory =
          await ServiceRegistry.applicationSettings.projectsDirectory;
      if (directory == null) return null;
      await Directory(directory).create(recursive: true);
      return directory;
    } catch (error, stackTrace) {
      // A missing drive or unavailable preference store must not prevent saving
      // elsewhere with the native file picker.
      _log.warning(
        'Could not prepare the default projects folder.',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<bool> exportLogs({required DialogController dialogController}) async {
    if (kIsWeb) {
      return false;
    }

    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    var path = (await getSaveLocation(
      suggestedName: 'anthem-logs-$timestamp.zip',
      confirmButtonText: 'Export',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'ZIP archives', extensions: ['zip']),
      ],
    ))?.path;

    if (path == null) {
      return false;
    }

    if (!path.toLowerCase().endsWith('.zip')) {
      path = '$path.zip';
    }

    try {
      final exportedPath = await AnthemLogManager.instance.exportLogs(
        outputPath: path,
      );

      dialogController.showMarkdownDialog(
        title: 'Export logs',
        markdown: 'Saved logs to:\n\n${escapeDialogMarkdown(exportedPath)}',
        buttons: [DialogButton.ok()],
      );

      return true;
    } catch (error, stackTrace) {
      _log.warning('Could not export logs.', error, stackTrace);

      dialogController.showMarkdownDialog(
        title: 'Export logs',
        markdown:
            'Could not export logs:\n\n${escapeDialogMarkdown(error.toString())}',
        buttons: [DialogButton.ok()],
      );

      return false;
    }
  }

  CursorOverrideHandle pushCursorOverride(MouseCursor cursor) {
    final id = _nextCursorOverrideId++;
    _cursorOverrides[id] = cursor;
    _syncCursorOverride();

    return CursorOverrideHandle._(this, id);
  }

  void _releaseCursorOverride(int id) {
    _cursorOverrides.remove(id);
    _syncCursorOverride();
  }

  void _syncCursorOverride() {
    ServiceRegistry.mainWindowViewModel.globalCursor =
        _cursorOverrides.values.lastOrNull ?? MouseCursor.defer;
  }

  void clearAllCursorOverrides() {
    _cursorOverrides.clear();
    _syncCursorOverride();
  }

  void dispose() {
    clearAllCursorOverrides();
  }
}

@immutable
class TabDef {
  final ProjectId id;
  final String title;

  const TabDef({required this.id, required this.title});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabDef && other.id == id && other.title == title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
