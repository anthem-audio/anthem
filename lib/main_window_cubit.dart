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
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

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
            event.type == Reply.ProjectClosed)
        .listen(_updateTabList);
  }

  static List<TabDef> _getTabs(Store store) {
    return store.projects
        .map((item) => TabDef(id: item.id, title: "todo"))
        .toList();
  }

  _updateActiveTab(PostedReply _reply) {
    emit(MainWindowState(
        tabs: state.tabs, selectedTabID: _store.activeProjectId));
  }

  _updateTabList(PostedReply _reply) {
    emit(MainWindowState(
        tabs: _getTabs(_store), selectedTabID: _store.activeProjectId));
  }

  Future<void> switchTab(int newTabID) => _store.msgSetActiveProject(newTabID);
  
  // Returns the ID of the new tab
  Future<int> newProject() async {
    final reply = await _store.msgNewProject();
    return int.parse(reply.data!);
  }
}
