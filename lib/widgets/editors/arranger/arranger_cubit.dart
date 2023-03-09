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

  late final StreamSubscription<List<StateChange>> _stateChangeStream;

  @override
  Future<void> close() async {
    await _stateChangeStream.cancel();

    return super.close();
  }

  ArrangerCubit({required ID projectID})
      : super((() {
          final project = AnthemStore.instance.projects[projectID]!;
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
    project = AnthemStore.instance.projects[projectID]!;
    _stateChangeStream = project.stateChangeStream.listen(_onModelChanged);
  }

  void _onModelChanged(List<StateChange> changes) {
    var didClipsChange = false;
    var didActiveArrangementChange = false;
    var didArrangementListChange = false;

    for (final change in changes) {
      change.whenOrNull(
        project: (change) {
          change.mapOrNull(
            activeArrangementChanged: (change) {
              didActiveArrangementChange = true;
              didClipsChange = true;
            },
          );
        },
        arrangement: (change) {
          if (change.arrangementID == state.activeArrangementID) {
            change.mapOrNull(
              clipAdded: (change) => didClipsChange = true,
              clipDeleted: (change) => didClipsChange = true,
            );
          }
          change.mapOrNull(
            arrangementAdded: (change) => didArrangementListChange = true,
            arrangementDeleted: (change) => didArrangementListChange = true,
            arrangementNameChanged: (change) => didArrangementListChange = true,
          );
        },
      );
    }

    ArrangerState? newState;

    if (didClipsChange) {
      final arrangement =
          project.song.arrangements[project.song.activeArrangementID];
      newState = (newState ?? state).copyWith(
        clipIDs: arrangement?.clips.keys.toList() ?? [],
        arrangementWidth:
            arrangement?.getWidth() ?? project.song.ticksPerQuarter * 4 * 8,
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

    if (didActiveArrangementChange) {
      newState = (newState ?? state)
          .copyWith(activeArrangementID: project.song.activeArrangementID);
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

    final command = AddArrangementCommand(project: project, arrangementName: arrangementName);

    project.execute(
      command
    );

    project.song.setActiveArrangement(command.arrangementID);
  }

  void setArrangementName(String name, [ID? arrangementID]) {
    arrangementID ??= state.activeArrangementID;
    if (arrangementID == null) return;

    project.execute(
      SetArrangementNameCommand(
        project: project,
        arrangementID: arrangementID,
        newName: name,
      ),
    );
  }

  void setBaseTrackHeight(double trackHeight) {
    final oldClampedTrackHeight =
        state.baseTrackHeight.clamp(minTrackHeight, maxTrackHeight);
    final oldVerticalScrollPosition = state.verticalScrollPosition;
    final clampedTrackHeight =
        trackHeight.clamp(minTrackHeight, maxTrackHeight);
    emit(
      state.copyWith(
        baseTrackHeight: trackHeight,
        verticalScrollPosition: oldVerticalScrollPosition *
            (clampedTrackHeight / oldClampedTrackHeight),
        scrollAreaHeight:
            getScrollAreaHeight(clampedTrackHeight, state.trackHeightModifiers),
      ),
    );
  }

  void setVerticalScrollPosition(double position) {
    emit(state.copyWith(verticalScrollPosition: position));
  }

  void setHeightModifier(ID trackID, double newModifier) {
    final newHeightModifiers = {
      ...state.trackHeightModifiers,
      trackID: newModifier,
    };

    emit(
      state.copyWith(
        trackHeightModifiers: newHeightModifiers,
        scrollAreaHeight:
            getScrollAreaHeight(state.baseTrackHeight, newHeightModifiers),
      ),
    );
  }

  void setTool(EditorTool tool) {
    emit(
      state.copyWith(tool: tool),
    );
  }

  void setActiveArrangement(ID? arrangementID) {
    project.song.setActiveArrangement(arrangementID);
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
