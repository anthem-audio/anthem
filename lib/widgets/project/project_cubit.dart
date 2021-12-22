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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart' as rid;

part 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  // ignore: unused_field
  late final StreamSubscription<rid.PostedReply> _rid_updateActiveInstrumentSub;
  // ignore: unused_field
  late final StreamSubscription<rid.PostedReply> _rid_updateActiveControllerSub;
  // ignore: unused_field
  late final StreamSubscription<StateChange> _updateActiveGeneratorSub;

  final rid.Store _store = rid.Store.instance;
  late final ProjectModel project;

  ProjectCubit({required int id})
      : super(
          ProjectState(
            id: id,
            activeInstrumentID: null,
            activeControllerID: null,
          ),
        ) {
    _rid_updateActiveInstrumentSub = rid.rid.replyChannel.stream
        .where((event) => event.type == rid.Reply.ActiveInstrumentSet)
        .listen(_rid_updateActiveInstrument);
    _rid_updateActiveControllerSub = rid.rid.replyChannel.stream
        .where((event) => event.type == rid.Reply.ActiveControllerSet)
        .listen(_rid_updateActiveController);

    project = Store.instance.projects[id]!;

    _updateActiveGeneratorSub = project.stateChangeStream
        .where((change) => change is ActiveGeneratorSet)
        .map((change) => change as ActiveGeneratorSet)
        .listen(_updateActiveGenerator);
  }
  
  _updateActiveGenerator(ActiveGeneratorSet change) {
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: state.activeControllerID,
        activeInstrumentID: change.generatorID,
      ),
    );
  }

  // TODO: remove
  _rid_updateActiveInstrument(rid.PostedReply _reply) {
    final id = _store.projects[state.id]!.song.activeInstrumentId;
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: state.activeControllerID,
        activeInstrumentID: id,
      ),
    );
  }

  // TODO: remove
  _rid_updateActiveController(rid.PostedReply _reply) {
    final id = _store.projects[state.id]!.song.activeControllerId;
    emit(
      ProjectState(
        id: state.id,
        activeControllerID: id,
        activeInstrumentID: state.activeInstrumentID,
      ),
    );
  }

  Future<void> undo() {
    project.undo();
    return _store.msgUndo(state.id); // TODO: remove this
  }

  Future<void> redo() {
    project.redo();
    return _store.msgRedo(state.id); // TODO: remove this
  }

  Future<void> journalStartEntry() {
    project.startJournalPage();
    return _store.msgJournalStartEntry(state.id); // TODO: remove this
  }

  Future<void> journalCommitEntry() {
    project.commitJournalPage();
    return _store.msgJournalCommitEntry(state.id); // TODO: remove this
  }

  Future<void> setActiveInstrumentID(int? id) => _store.msgSetActiveInstrument(
      state.id, id ?? 0); // TODO: nullable once rid supports this
  Future<void> setActiveControllerID(int? id) => _store.msgSetActiveController(
      state.id, id ?? 0); // TODO: nullable once rid supports this
}
