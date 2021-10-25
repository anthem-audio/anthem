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
import 'dart:collection';

import 'package:anthem/helpers/get_project.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin/generated/rid_api.dart';

part 'pattern_editor_state.dart';

class PatternEditorCubit extends Cubit<PatternEditorState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updatePatternListSub;
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updateGeneratorListSub;
  final Store _store = Store.instance;

  PatternEditorCubit({required int projectID})
      : super(PatternEditorState.init(projectID)) {
    _updatePatternListSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.PatternAdded ||
            event.type == Reply.PatternDeleted)
        .listen(_updatePatternList);
    _updateGeneratorListSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.InstrumentAdded ||
            event.type == Reply.ControllerAdded ||
            event.type == Reply.GeneratorRemoved)
        .listen(_updateGeneratorList);
  }

  _updatePatternList(PostedReply _reply) {
    emit(PatternEditorState(
      controllers: state.controllers,
      generatorIDList: state.generatorIDList,
      instruments: state.instruments,
      pattern: state.pattern,
      patternList: getProject(_store, state.projectID)
          .song
          .patterns
          .map(
            (pattern) => PatternListItem(id: pattern.id, name: pattern.name),
          )
          .toList(),
      projectID: state.projectID,
    ));
  }

  _updateGeneratorList(PostedReply _reply) {
    final project = getProject(_store, state.projectID);

    emit(PatternEditorState(
      controllers: project.controllers,
      generatorIDList: project.generatorList,
      instruments: project.instruments,
      pattern: state.pattern,
      patternList: state.patternList,
      projectID: state.projectID,
    ));
  }

  Future<void> addPattern(String name) =>
      _store.msgAddPattern(state.projectID, name);
  Future<void> deletePattern(int id) =>
      _store.msgDeletePattern(state.projectID, id);
  Future<void> addInstrument(String name) =>
      _store.msgAddInstrument(state.projectID, name);
  Future<void> addController(String name) =>
      _store.msgAddController(state.projectID, name);
  Future<void> removeGenerator(int id) =>
      _store.msgRemoveGenerator(state.projectID, id);
}
