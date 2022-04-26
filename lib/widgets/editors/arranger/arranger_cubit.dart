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

import 'package:anthem/commands/arrangement_commands.dart';
import 'package:anthem/commands/state_changes.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'helpers.dart';

part 'arranger_state.dart';
part 'arranger_cubit.freezed.dart';

class ArrangerCubit extends Cubit<ArrangerState> {
  late final ProjectModel project;

  ArrangerCubit({required ID projectID})
      : super((() {
          final project = Store.instance.projects[projectID]!;
          final arrangement =
              project.song.arrangements[project.song.activeArrangementID]!;
          const defaultTrackHeight = 45.0;

          final Map<ID, double> trackHeightModifiers = {};
          for (final trackID in project.song.trackOrder) {
            trackHeightModifiers[trackID] = 1;
          }

          final arrangementIDs = [...project.song.arrangementOrder];

          final Map<ID, String> arrangementNames = {};

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
            clipIDs: arrangement.clips.keys.toList(),
            arrangementWidth: arrangement.getWidth(),
          );
        })()) {
    project = Store.instance.projects[projectID]!;
    project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var didClipsChange = false;
    var didSelectedArrangementChange = false;
    var didArrangementListChange = false;

    for (final change in changes) {
      final relatesToSelectedArrangement =change is ArrangementStateChange &&
          change.arrangementID == state.activeArrangementID;

      if (relatesToSelectedArrangement && (change is ClipAdded || change is ClipDeleted)) {
        didClipsChange = true;
      }

      if (change is ArrangementAdded || change is ArrangementDeleted) {
        didArrangementListChange = true;
      }
    }

    ArrangerState? newState;

    if (didClipsChange) {
      final arrangement = project.song.arrangements[state.activeArrangementID]!;
      newState = (newState ?? state).copyWith(
        clipIDs: arrangement.clips.keys.toList(),
        arrangementWidth: arrangement.getWidth(),
      );
    }

    if (didArrangementListChange) {
      newState = (newState ?? state).copyWith(
        arrangementIDs: [...project.song.arrangementOrder],
        arrangementNames: project.song.arrangements.map(
          (id, arrangement) => MapEntry(id, arrangement.name),
        ),
      );
    }

    if (newState != null) {
      emit(newState);
    }
  }

  void addArrangement() {
    var arrangementNumber = state.arrangementIDs.length;
    String arrangementName;

    do {
      arrangementNumber++;
      arrangementName = "Arrangement $arrangementNumber";
    } while (state.arrangementNames.containsValue(arrangementName));

    project.execute(
      AddArrangementCommand(project: project, arrangementName: arrangementName),
    );
  }

  void setBaseTrackHeight(double trackHeight) {
    final oldTrackHeight =
        state.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
    final newTrackHeight = trackHeight.clamp(minTrackHeight, maxTrackHeight);
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

  void setHeightModifier(ID trackID, double newModifier) {
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

  void handleMouseDown(Offset offset, Size editorSize, TimeView timeView) {
    if (state.activeArrangementID == null) return;

    final trackIndex = posToTrackIndex(
      yOffset: offset.dy,
      baseTrackHeight: state.baseTrackHeight,
      trackHeightModifiers: state.trackHeightModifiers,
      trackOrder: state.trackIDs,
      scrollPosition: state.verticalScrollPosition,
    );
    if (trackIndex.isInfinite) return;

    final time = pixelsToTime(
      timeViewStart: timeView.start,
      timeViewEnd: timeView.end,
      viewPixelWidth: editorSize.width,
      pixelOffsetFromLeft: offset.dx,
    );

    project.execute(AddClipCommand(
      project: project,
      arrangementID: state.activeArrangementID!,
      trackID: state.trackIDs[trackIndex.floor()],
      patternID: project.song.patterns[project.song.patternOrder[0]]!.id,
      offset: time.floor(),
    ));
  }
}
