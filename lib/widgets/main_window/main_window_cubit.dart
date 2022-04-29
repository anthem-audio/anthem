/*
  Copyright (C) 2021 - 2022 Joshua Wade

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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

part 'main_window_state.dart';

class MainWindowCubit extends Cubit<MainWindowState> {
  late final StreamSubscription<ActiveProjectChanged> _activeProjectChangedSub;
  late final StreamSubscription<ProjectStateChange> _projectListChangedSub;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _activeProjectChangedSub.cancel();
    await _projectListChangedSub.cancel();

    return super.close();
  }

  MainWindowCubit()
      : super(MainWindowState(
            tabs: _getTabs(), selectedTabID: Store.instance.activeProjectID)) {
    _activeProjectChangedSub = Store.instance.stateChangeStream
        .where((change) => change is ActiveProjectChanged)
        .map((change) => change as ActiveProjectChanged)
        .listen(_updateActiveTab);

    _projectListChangedSub = Store.instance.stateChangeStream
        .where((change) => change is ProjectAdded || change is ProjectClosed)
        .map((change) => change as ProjectStateChange)
        .listen(_updateTabList);
  }

  static List<TabDef> _getTabs() {
    return Store.instance.projectOrder
        .map((id) => TabDef(
            id: Store.instance.projects[id]!.id,
            title: Store.instance.projects[id]!.id.toString()))
        .toList();
  }

  _updateActiveTab(ActiveProjectChanged change) {
    emit(MainWindowState(
      tabs: state.tabs,
      selectedTabID: Store.instance.activeProjectID,
    ));
  }

  _updateTabList(ProjectStateChange change) {
    emit(MainWindowState(
      tabs: _getTabs(),
      selectedTabID: Store.instance.activeProjectID,
    ));
  }

  void switchTab(ID newTabID) => Store.instance.setActiveProject(newTabID);

  // Returns the ID of the new tab
  ID newProject() {
    ProjectModel project = ProjectModel.create();
    Store.instance.addProject(project);
    return project.id;
  }

  void closeProject(ID projectID) => Store.instance.closeProject(projectID);

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
      Store.instance.addProject(project);

      return project.id;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProject(ID projectID, bool alwaysUseFilePicker) async {
    try {
      final project = Store.instance.projects[projectID]!;

      String? path;
      if (alwaysUseFilePicker || !project.isSaved) {
        path = (await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ["anthem"],
        ))
            ?.files[0]
            .path;
      } else {
        path = project.filePath;
      }

      if (path == null) return;

      await File(path).writeAsString(project.toString());
    } catch (e) {
      // TODO: the backend isn't telling us if the save failed, so we can't act on that
      return;
    }
  }
}
