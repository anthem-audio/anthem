/*
  Copyright (C) 2021 Joshua Wade

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

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';
import 'package:file_picker/file_picker.dart';

part 'main_window_state.dart';

class MainWindowCubit extends Cubit<MainWindowState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _flushSub;
  final Store _store = Store.instance;

  MainWindowCubit()
      : super(MainWindowState(
            tabs: _getTabs(Store.instance),
            selectedTabID: Store.instance.activeProjectId)) {
    _updateSub = rid.replyChannel.stream
        .where((event) => event.type == Reply.ActiveProjectChanged)
        .listen(_updateActiveTab);
    _flushSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.NewProjectCreated ||
            event.type == Reply.ProjectClosed ||
            event.type == Reply.ProjectLoaded)
        .listen(_updateTabList);
  }

  static List<TabDef> _getTabs(Store store) {
    return store.projectOrder
        .map((id) => TabDef(
            id: store.projects[id]!.id,
            title: store.projects[id]!.id.toString()))
        .toList();
  }

  _updateActiveTab(PostedReply _reply) {
    emit(MainWindowState(
        tabs: state.tabs, selectedTabID: _store.activeProjectId));
  }

  _updateTabList(PostedReply _reply) {
    print("update tab list");
    emit(MainWindowState(
        tabs: _getTabs(_store), selectedTabID: _store.activeProjectId));
  }

  Future<void> switchTab(int newTabID) => _store.msgSetActiveProject(newTabID);

  // Returns the ID of the new tab
  Future<int> newProject() async {
    final reply = await _store.msgNewProject();
    return int.parse(reply.data!);
  }

  Future<void> closeProject(int projectID) => _store.msgCloseProject(projectID);

  // Returns the ID of the loaded project, or null if the project load failed
  // or was cancelled
  Future<int?> loadProject() async {
    try {
      final path = (await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["anthem"],
      ))
          ?.files[0]
          .path;
      if (path == null) return null;
      final id = (await _store.msgLoadProject(path)).data!;
      return int.parse(id);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProject(int projectID, bool alwaysUseFilePicker) async {
    try {
      final project = _store.projects[projectID]!;

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

      await _store.msgSaveProject(projectID, path);
    } catch (e) {
      // TODO: the backend isn't telling us if the save failed, so we can't act on that
      return;
    }
  }
}
