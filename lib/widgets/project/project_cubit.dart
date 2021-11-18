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

part 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateActiveInstrumentSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateActiveControllerSub;
  final Store _store = Store.instance;

  ProjectCubit({required int id})
      : super(
          ProjectState(
            id: id,
            activeInstrumentID: null,
            activeControllerID: null,
          ),
        ) {
    _updateActiveInstrumentSub = rid.replyChannel.stream
        .where((event) => event.type == Reply.ActiveInstrumentSet)
        .listen(_updateActiveInstrument);
    _updateActiveControllerSub = rid.replyChannel.stream
        .where((event) => event.type == Reply.ActiveControllerSet)
        .listen(_updateActiveController);
  }

  _updateActiveInstrument(PostedReply _reply) {
    final id = _store.projects[state.id]!.song.activeInstrumentId;
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: state.activeControllerID,
        activeInstrumentID: id,
      ),
    );
  }

  _updateActiveController(PostedReply _reply) {
    final id = _store.projects[state.id]!.song.activeControllerId;
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: id,
        activeInstrumentID: state.activeInstrumentID,
      ),
    );
  }

  Future<void> undo() => _store.msgUndo(state.id);
  Future<void> redo() => _store.msgRedo(state.id);
  Future<void> journalStartEntry() => _store.msgJournalStartEntry(state.id);
  Future<void> journalCommitEntry() => _store.msgJournalCommitEntry(state.id);

  Future<void> setActiveInstrumentID(int? id) => _store.msgSetActiveInstrument(
      state.id, id ?? 0); // TODO: nullable once rid supports this
  Future<void> setActiveControllerID(int? id) => _store.msgSetActiveController(
      state.id, id ?? 0); // TODO: nullable once rid supports this
}
