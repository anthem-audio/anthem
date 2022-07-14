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

import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bloc/bloc.dart';

import 'clip_notes.dart';

part 'clip_state.dart';
part 'clip_cubit.freezed.dart';

class ClipCubit extends Cubit<ClipState> {
  late final ProjectModel project;
  late final PatternModel pattern;
  late final ClipModel? clip;

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  ClipCubit({
    required ID projectID,
    required ID arrangementID,
    required ID clipID,
  }) : super((() {
          final project = Store.instance.projects[projectID]!;
          final clip = project.song.arrangements[arrangementID]!.clips[clipID]!;
          final pattern = project.song.patterns[clip.patternID]!;
          return ClipState(
            notes: _getClipNotes(pattern),
            patternName: pattern.name,
            color: pattern.color,
            contentWidth: clip.getWidth(),
          );
        })()) {
    project = Store.instance.projects[projectID]!;
    clip = project.song.arrangements[arrangementID]!.clips[clipID];
    pattern = clip!.pattern;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  ClipCubit.fromPatternID({required ID projectID, required ID patternID})
      : super((() {
          final project = Store.instance.projects[projectID]!;
          final pattern = project.song.patterns[patternID]!;
          return ClipState(
            notes: _getClipNotes(pattern),
            patternName: pattern.name,
            color: pattern.color,
            contentWidth: pattern.getWidth(),
          );
        })()) {
    project = Store.instance.projects[projectID]!;
    pattern = project.song.patterns[patternID]!;
    clip = null;
    project.stateChangeStream.listen(_onModelChanged);
  }

  _onModelChanged(List<StateChange> changes) {
    var updateNotes = false;

    for (final change in changes) {
      change.whenOrNull(
        note: (noteChange) => updateNotes = true,
      );
    }

    if (updateNotes) {
      emit(state.copyWith(
        notes: _getClipNotes(pattern),
        contentWidth: clip?.getWidth() ?? pattern.getWidth(),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }
}

List<ClipNoteModel> _getClipNotes(PatternModel pattern) {
  return pattern.notes.entries
      .expand((entry) => entry.value)
      .map((noteModel) => ClipNoteModel.fromNoteModel(noteModel))
      .toList();
}
