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

part 'pattern_editor_state.dart';

class PatternEditorCubit extends Cubit<PatternEditorState> {
  // ignore: unused_field
  late final StreamSubscription<PostedReply> _updatePatternListSub;
  final Store _store = Store.instance;

  PatternEditorCubit({required int projectID})
      : super(PatternEditorState(
          projectID: projectID,
          pattern: null,
          patternList: [],
        )) {
    _updatePatternListSub = rid.replyChannel.stream
        .where((event) =>
            event.type == Reply.PatternAdded ||
            event.type == Reply.PatternDeleted)
        .listen(_updatePatternList);
  }

  _updatePatternList(PostedReply _reply) {
    emit(
      PatternEditorState(
        projectID: state.projectID,
        pattern: state.pattern,
        patternList: _store.projects
            .firstWhere((project) => project.id == state.projectID)
            .song
            .patterns
            .map(
              (pattern) => PatternListItem(id: pattern.id, name: pattern.name),
            )
            .toList(),
      ),
    );
  }

  Future<void> addPattern(String name) => _store.msgAddPattern(state.projectID, name);
  Future<void> deletePattern(int id) => _store.msgDeletePattern(state.projectID, id);
}
