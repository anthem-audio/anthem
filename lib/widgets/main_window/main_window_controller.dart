/*
  Copyright (C) 2021 - 2023 Joshua Wade

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

import 'package:file_picker/file_picker.dart';

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter/foundation.dart';

class MainWindowController {
  // Returns the ID of the new tab
  ID newProject() {
    ProjectModel project = ProjectModel.create();
    AnthemStore.instance.addProject(project);
    return project.id;
  }

  void switchTab(ID newTabID) =>
      AnthemStore.instance.setActiveProject(newTabID);

  void closeProject(ID projectID) =>
      AnthemStore.instance.closeProject(projectID);

  /// Returns the ID of the loaded project, or null if the project load failed
  /// or was cancelled
  /// TODO: Granular error handling
  Future<ID?> loadProject() async {
    try {
      final path = (await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["anthem"],
      ))
          ?.files[0]
          .path;
      if (path == null) return null;
      final file = await File(path).readAsString();

      final project = ProjectModel.fromJson(json.decode(file))..hydrate();
      AnthemStore.instance.addProject(project);

      return project.id;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProject(ID projectID, bool alwaysUseFilePicker) async {
    try {
      final project = AnthemStore.instance.projects[projectID]!;

      String? path;
      if (alwaysUseFilePicker || !project.isSaved) {
        path = (await FilePicker.platform.saveFile(
          type: FileType.custom,
          allowedExtensions: ["anthem"],
        ));
      } else {
        path = project.filePath;
      }

      if (path == null) return;

      if (!path.endsWith(".anthem")) {
        path += ".anthem";
      }

      await File(path).writeAsString(project.toString());

      project.isSaved = true;
    } catch (e) {
      // TODO: the backend isn't telling us if the save failed, so we can't act on that
      return;
    }
  }
}

@immutable
class TabDef {
  final ID id;
  final String title;

  const TabDef({required this.id, required this.title});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabDef && other.id == id && other.title == title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}

class KeyboardModifiers with ChangeNotifier, DiagnosticableTreeMixin {
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;

  KeyboardModifiers();

  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;

  void setCtrl(bool value) {
    _ctrl = value;
    notifyListeners();
  }

  void setAlt(bool value) {
    _alt = value;
    notifyListeners();
  }

  void setShift(bool value) {
    _shift = value;
    notifyListeners();
  }
}