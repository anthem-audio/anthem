/*
  Copyright (C) 2022 Joshua Wade

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

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

import '../../../commands/state_changes.dart';
import '../../../model/note.dart';
import '../../../model/pattern.dart';
import '../../../model/project.dart';
import '../../../model/shared/anthem_color.dart';
import '../../../model/store.dart';
import 'clip_notes.dart';

part 'clip_state.dart';
part 'clip_cubit.freezed.dart';

class ClipCubit extends Cubit<ClipState> {
  // TODO: Allow this to optionally take a ClipModel
  late final ProjectModel project;
  late final PatternModel pattern;

  // ignore: unused_field
  late final StreamSubscription<PatternStateChange> _updatePatternSub;

  ClipCubit({required int projectID, required int patternID})
      : super((() {
          final pattern =
              Store.instance.projects[projectID]!.song.patterns[patternID]!;
          return ClipState(
            notes: _getClipNotes(pattern),
            patternName: pattern.name,
            color: pattern.color,
          );
        })()) {
    project = Store.instance.projects[projectID]!;
    pattern = project.song.patterns[patternID]!;
    _updatePatternSub = project.stateChangeStream
        .where((change) =>
            change is NoteStateChange && change.patternID == patternID)
        .map((change) => change as PatternStateChange)
        .listen(_updatePattern);
  }

  _updatePattern(PatternStateChange change) {
    emit(state.copyWith(notes: _getClipNotes(pattern)));
  }
}

List<ClipNoteModel> _getClipNotes(PatternModel pattern) {
  return pattern.notes.entries
      .expand((entry) => entry.value)
      .map((noteModel) => ClipNoteModel.fromNoteModel(noteModel))
      .toList();
}
