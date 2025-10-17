/*
  Copyright (C) 2021 - 2025 Joshua Wade

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
import 'dart:convert';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/dialog/dialog_controller.dart';
import 'package:anthem/widgets/basic/text_box.dart';
import 'package:file_picker/file_picker.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide TextBox;

class MainWindowController {
  void _addProject(ProjectModel project) {
    final store = AnthemStore.instance;

    store.projects[project.id] = project;
    store.projectOrder.add(project.id);
    store.activeProjectId = project.id;
  }

  // Returns the ID of the new tab
  Future<Id> newProject() async {
    ProjectModel project = ProjectModel.create();

    await project.engine.engineStateStream.firstWhere(
      (element) => element == EngineState.running,
    );

    _addProject(project);

    return project.id;
  }

  void switchTab(Id projectId) {
    AnthemStore.instance.activeProjectId = projectId;

    // Only enable visualizations for the selected project tab
    for (final project in AnthemStore.instance.projects.values) {
      project.visualizationProvider.setEnabled(projectId == project.id);
    }
  }

  void closeProject(Id projectId) {
    final store = AnthemStore.instance;

    // Stop engine
    store.projects[projectId]!.dispose();

    // Remove project from model
    store.projects.remove(projectId);
    store.projectOrder.removeWhere((element) => element == projectId);

    // If the active project was closed, set it to the first open project
    if (store.activeProjectId == projectId && store.projectOrder.isNotEmpty) {
      store.activeProjectId = store.projectOrder[0];
    }
  }

  /// Returns the ID of the loaded project, or null if the project load failed
  /// or was cancelled.
  Future<Id?> loadProject() async {
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

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['anthem'],
      initialDirectory: home,
    );

    final String file;
    String? path;

    if (kIsWeb) {
      final bytes = result?.files.firstOrNull?.bytes;
      if (bytes == null) return null;
      file = utf8.decode(bytes);
    } else {
      path = result?.files.firstOrNull?.path;
      if (path == null) return null;
      file = await File(path).readAsString();
    }

    final project = ProjectModel.fromJson(json.decode(file));
    _addProject(project);

    project.filePath = path;
    project.isSaved = true;

    return project.id;
  }

  Future<void> saveProject(
    Id projectId,
    bool alwaysUseFilePicker, {
    required DialogController dialogController,
  }) async {
    final project = AnthemStore.instance.projects[projectId]!;

    String? path;

    if (!kIsWeb) {
      if (alwaysUseFilePicker || !project.isSaved) {
        path = (await FilePicker.platform.saveFile(
          type: FileType.custom,
          allowedExtensions: ['anthem'],
        ));
      } else {
        path = project.filePath;
      }
    }

    if (!kIsWeb && path == null) return;

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
                'Enter a filename for the project:',
                style: TextStyle(fontSize: 12, color: AnthemTheme.text.main),
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
      if (fileName == null) return;

      final bytes = utf8.encode(json.encode(project.toJson()));
      await FilePicker.platform.saveFile(
        fileName: '$fileName.anthem',
        bytes: bytes,
      );

      project.isSaved = true;
    } else {
      // Load the latest for all plugin states before saving
      await Future.wait(
        project.processingGraph.nodes.values.map((node) {
          return node.updateStateFromEngine();
        }),
      );

      await File(path!).writeAsString(json.encode(project.toJson()));

      project.isSaved = true;
      project.filePath = path;
    }
  }
}

@immutable
class TabDef {
  final Id id;
  final String title;

  const TabDef({required this.id, required this.title});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabDef && other.id == id && other.title == title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
