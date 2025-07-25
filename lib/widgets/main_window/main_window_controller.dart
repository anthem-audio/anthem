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

import 'dart:convert';
import 'dart:io';

import 'package:anthem/engine_api/engine.dart';
import 'package:file_picker/file_picker.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter/foundation.dart';

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

  void switchTab(Id newTabID) {
    AnthemStore.instance.activeProjectId = newTabID;
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
    Map<String, String> envVars = Platform.environment;
    if (Platform.isMacOS || Platform.isLinux) {
      home = envVars['HOME'];
    } else if (Platform.isWindows) {
      home = envVars['UserProfile'];
    }

    final path = (await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['anthem'],
      initialDirectory: home,
    ))?.files[0].path;
    if (path == null) return null;
    final file = await File(path).readAsString();

    final project = ProjectModel.fromJson(json.decode(file));
    _addProject(project);

    project.filePath = path;
    project.isSaved = true;

    return project.id;
  }

  Future<void> saveProject(Id projectId, bool alwaysUseFilePicker) async {
    try {
      final project = AnthemStore.instance.projects[projectId]!;

      String? path;
      if (alwaysUseFilePicker || !project.isSaved) {
        path = (await FilePicker.platform.saveFile(
          type: FileType.custom,
          allowedExtensions: ['anthem'],
        ));
      } else {
        path = project.filePath;
      }

      if (path == null) return;

      if (!path.endsWith('.anthem')) {
        path += '.anthem';
      }

      // Load the latest for all plugin states before saving
      await Future.wait(
        project.processingGraph.nodes.values.map((node) {
          return node.updateStateFromEngine();
        }),
      );

      await File(path).writeAsString(json.encode(project.toJson()));

      project.isSaved = true;
      project.filePath = path;
    } catch (e) {
      return;
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
