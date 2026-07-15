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
import 'package:anthem/logic/project_file/errors.dart';
import 'package:anthem/logic/project_file/version.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:file_picker/file_picker.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide TextBox;
import 'package:logging/logging.dart';

final _log = Logger('main_window_controller');

@visibleForTesting
String projectFileLoadErrorMarkdown(Object error) {
  String version(ProjectFileVersion version) {
    return escapeDialogMarkdown(version.toString());
  }

  return switch (error) {
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
  final Map<int, MouseCursor> _cursorOverrides = {};
  int _nextCursorOverrideId = 0;

  ServiceRegistry _addProject(ProjectModel project) {
    final store = AnthemStore.instance;

    store.projects[project.id] = project;
    store.projectOrder.add(project.id);
    store.activeProjectId = project.id;
    return ServiceRegistry.initializeProject(project);
  }

  // Returns the ID of the new tab
  Future<ProjectId> newProject() async {
    ProjectModel project = ProjectModel.create();

    final serviceRegistry = _addProject(project);
    await serviceRegistry.projectEngineController.start();

    return project.id;
  }

  void switchTab(ProjectId projectId) {
    AnthemStore.instance.activeProjectId = projectId;

    // Only enable visualizations for the selected project tab
    for (final project in AnthemStore.instance.projects.values) {
      project.visualizationProvider.setEnabled(projectId == project.id);
    }
  }

  void closeProjectWithoutSaving(ProjectId projectId) {
    final store = AnthemStore.instance;
    final project = store.projects[projectId];

    if (project == null) {
      return;
    }

    ServiceRegistry.removeProject(projectId);

    // Clean up project resources
    project.dispose();

    // Remove project from model
    store.projects.remove(projectId);
    store.projectOrder.remove(projectId);

    // If the active project was closed, set it to the first open project
    if (store.activeProjectId == projectId && store.projectOrder.isNotEmpty) {
      store.activeProjectId = store.projectOrder[0];
    }
  }

  /// Returns the ID of the loaded project, or null if the project load failed
  /// or was cancelled.
  Future<ProjectId?> loadProject({
    required DialogController dialogController,
  }) async {
    String? home;
    Map<String, String> envVars = kIsWeb ? {} : Platform.environment;

    // This throws on web due to dart:io usage
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        home = envVars['HOME'];
      } else if (Platform.isWindows) {
        home = envVars['UserProfile'];
      }
    } catch (e) {
      home = null;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['anthem'],
      initialDirectory: home,
    );

    final ProjectModel project;
    String? path;

    try {
      final Map<String, dynamic> projectJson;
      if (kIsWeb) {
        final bytes = result?.files.firstOrNull?.bytes;
        if (bytes == null) return null;
        projectJson = await decodeProjectFileBytes(bytes);
      } else {
        path = result?.files.firstOrNull?.path;
        if (path == null) return null;
        projectJson = await readProjectFile(path);
      }

      project = ProjectModel.fromJson(projectJson);
    } catch (error, stackTrace) {
      _log.warning('Could not load project file.', error, stackTrace);
      dialogController.showMarkdownDialog(
        title: 'Could not open project',
        markdown: projectFileLoadErrorMarkdown(error),
        buttons: [DialogButton.ok()],
      );
      return null;
    }

    final serviceRegistry = _addProject(project);

    project.filePath = path;
    project.isDirty = false;

    await serviceRegistry.projectEngineController.start();
    return project.id;
  }

  Future<bool> saveProject(
    ProjectId projectId,
    bool alwaysUseFilePicker, {
    required DialogController dialogController,
  }) async {
    final project = AnthemStore.instance.projects[projectId]!;

    String? path;

    if (!kIsWeb) {
      if (alwaysUseFilePicker || project.filePath == null) {
        path = (await FilePicker.saveFile(
          type: FileType.custom,
          allowedExtensions: ['anthem'],
        ));
      } else {
        path = project.filePath;
      }
    }

    if (!kIsWeb && path == null) return false;

    if (path != null && !path.endsWith('.anthem')) {
      path += '.anthem';
    }

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
        await FilePicker.saveFile(fileName: '$fileName.anthem', bytes: bytes);
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

      await writeProjectFile(path!, project);

      project.isDirty = false;
      project.filePath = path;
      return true;
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

    var path = await FilePicker.saveFile(
      dialogTitle: 'Export Anthem logs',
      fileName: 'anthem-logs-$timestamp.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

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
