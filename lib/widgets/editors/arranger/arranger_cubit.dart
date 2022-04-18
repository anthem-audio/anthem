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

import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../model/store.dart';
import 'helpers.dart';

part 'arranger_state.dart';
part 'arranger_cubit.freezed.dart';

class ArrangerCubit extends Cubit<ArrangerState> {
  ArrangerCubit({required int projectID})
      : super((() {
          final project = Store.instance.projects[projectID]!;
          final arrangement =
              project.song.arrangements[project.song.activeArrangementID]!;
          const defaultTrackHeight = 45.0;

          final Map<int, double> trackHeightModifiers = {};
          for (final trackID in project.song.trackOrder) {
            trackHeightModifiers[trackID] = 1;
          }

          final arrangementIDs = [...project.song.arrangementOrder];

          final Map<int, String> arrangementNames = {};

          for (final id in arrangementIDs) {
            arrangementNames[id] = project.song.arrangements[id]!.name;
          }

          return ArrangerState(
            projectID: projectID,
            activeArrangementID: arrangement.id,
            arrangementIDs: arrangementIDs,
            arrangementNames: arrangementNames,
            trackIDs: project.song.trackOrder,
            baseTrackHeight: defaultTrackHeight,
            scrollAreaHeight:
                getScrollAreaHeight(defaultTrackHeight, trackHeightModifiers),
            trackHeightModifiers: trackHeightModifiers,
            ticksPerQuarter: project.song.ticksPerQuarter,
          );
        })());

  void setBaseTrackHeight(double newTrackHeight) {
    final oldTrackHeight =
        state.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
    final oldVerticalScrollPosition = state.verticalScrollPosition;
    emit(
      state.copyWith(
        baseTrackHeight: newTrackHeight,
        verticalScrollPosition:
            oldVerticalScrollPosition * (newTrackHeight / oldTrackHeight),
        scrollAreaHeight:
            getScrollAreaHeight(newTrackHeight, state.trackHeightModifiers),
      ),
    );
  }

  void setVerticalScrollPosition(double position) {
    emit(state.copyWith(verticalScrollPosition: position));
  }

  void setHeightModifier(int trackID, double newModifier) {
    emit(
      state.copyWith(trackHeightModifiers: {
        ...state.trackHeightModifiers,
        trackID: newModifier
      }),
    );
  }

  void setTool(EditorTool tool) {
    emit(
      state.copyWith(tool: tool),
    );
  }

  void handleMouseDown(Offset offset, Size editorSize) {
    print(offset);
    print(editorSize);
  }
}
