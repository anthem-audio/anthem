/*
  Copyright (C) 2023 - 2026 Joshua Wade

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
import 'dart:math';

import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/commands/pattern_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

import '../helpers.dart';

part 'pointer_events.dart';
part 'shortcuts.dart';

class ArrangerController extends _ArrangerController
    with _ArrangerShortcutsMixin {
  ArrangerController({required super.viewModel, required super.project}) {
    // Register shortcuts for this editor
    registerShortcuts();
  }
}

abstract class _ArrangerController {
  ArrangerViewModel viewModel;
  ProjectModel project;

  late final ArrangerStateMachine stateMachine = ArrangerStateMachine.create(
    project: project,
    viewModel: viewModel,
    controller: this as ArrangerController,
  );

  late final ReactionDisposer patternCursorAutorunDispose;

  ProjectModel get _project =>
      AnthemStore.instance.projects[viewModel.projectId]!;

  _ArrangerController({required this.viewModel, required this.project}) {
    // Set up an autorun to update the current cursor pattern if the selected
    // pattern changes
    patternCursorAutorunDispose = autorun((_) {
      viewModel.cursorPattern = project.sequence.activePatternID;
      viewModel.cursorTimeRange = null;
    });
  }

  void dispose() {
    patternCursorAutorunDispose();
    stateMachine.dispose();
  }

  void pointerDown(PointerEvent pointerEvent) {
    stateMachine.onPointerDown(pointerEvent);
  }

  void pointerMove(PointerEvent pointerEvent) {
    stateMachine.onPointerMove(pointerEvent);
  }

  void pointerUp(PointerEvent pointerEvent) {
    stateMachine.onPointerUp(pointerEvent);
  }

  void onEnter(PointerEnterEvent e) {
    stateMachine.onEnter(e);
  }

  void onExit(PointerExitEvent e) {
    stateMachine.onExit(e);
  }

  void onHover(PointerHoverEvent e) {
    stateMachine.onHover(e);
  }

  void onViewSizeChanged(Size viewSize) {
    stateMachine.onViewSizeChanged(viewSize);
  }

  void onRenderedViewTransformChanged({
    required double timeViewStart,
    required double timeViewEnd,
    required double verticalScrollPosition,
  }) {
    stateMachine.onRenderedViewTransformChanged(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      verticalScrollPosition: verticalScrollPosition,
    );
  }

  void onTrackLayoutChanged() {
    stateMachine.onTrackLayoutChanged();
  }

  void setBaseTrackHeight(double pointerY, double trackHeight) {
    final oldClampedTrackHeight = viewModel.baseTrackHeight.clamp(
      minTrackHeight,
      maxTrackHeight,
    );
    final oldVerticalScrollPosition = viewModel.verticalScrollPosition;
    final clampedTrackHeight = trackHeight.clamp(
      minTrackHeight,
      maxTrackHeight,
    );

    final heightRatio = clampedTrackHeight / oldClampedTrackHeight;

    viewModel.baseTrackHeight = trackHeight;
    viewModel.verticalScrollPosition =
        ((oldVerticalScrollPosition + pointerY) * heightRatio - pointerY).clamp(
          0,
          double.infinity,
        );

    onBaseTrackHeightChanged.add(null);
  }

  /// We need to snap the vertical scroll position animation when this happens.
  final onBaseTrackHeightChanged = StreamController<void>.broadcast();

  void deleteSelectedClips() {
    if (viewModel.selectedClips.isEmpty ||
        project.sequence.activeArrangementID == null) {
      return;
    }

    project.startUndoGroup();

    for (final clipID in viewModel.selectedClips) {
      project.execute(
        ClipAddRemoveCommand.remove(
          arrangementID: project.sequence.activeArrangementID!,
          clipId: clipID,
          project: project,
        ),
      );
    }

    project.commitUndoGroup();
  }

  void selectAllClips() {
    if (project.sequence.activeArrangementID == null) return;

    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;

    viewModel.selectedClips.clear();

    for (final clipID in arrangement.clips.keys) {
      viewModel.selectedClips.add(clipID);
    }
  }

  void selectTrack(Id trackId) {
    viewModel.selectedTracks.clear();
    viewModel.selectedTracks.add(trackId);
    viewModel.lastToggledTrack = trackId;
    viewModel.lastShiftClickRange = null;
  }

  bool isTrackSelected(Id trackId) {
    return viewModel.selectedTracks.contains(trackId);
  }

  void toggleTrackSelection(Id trackId) {
    if (viewModel.selectedTracks.contains(trackId)) {
      viewModel.selectedTracks.remove(trackId);
    } else {
      viewModel.selectedTracks.add(trackId);
    }

    viewModel.lastToggledTrack = trackId;
    viewModel.lastShiftClickRange = null;
  }

  void shiftClickToTrack(Id trackId) {
    if (viewModel.lastToggledTrack == null) {
      toggleTrackSelection(trackId);
      return;
    }

    final project = _project;

    if (project.sequence.activeArrangementID == null) {
      return;
    }

    final currentTrackList = getTracksIterable(
      project,
    ).map((track) => track.$1).toList(growable: false);

    if (viewModel.lastShiftClickRange != null) {
      for (final id in viewModel.lastShiftClickRange!.selected) {
        viewModel.selectedTracks.add(id);
      }

      for (final id in viewModel.lastShiftClickRange!.notSelected) {
        viewModel.selectedTracks.remove(id);
      }
    }

    final start = viewModel.lastToggledTrack;
    final startIndex = start == null ? -1 : currentTrackList.indexOf(start);
    final end = trackId;
    final endIndex = currentTrackList.indexOf(end);

    if (startIndex == -1 || endIndex == -1) {
      selectTrack(trackId);
      return;
    }

    final first = min(startIndex, endIndex);
    final last = max(startIndex, endIndex);

    viewModel.lastShiftClickRange = (selected: [], notSelected: []);

    for (var i = first; i <= last; i++) {
      final id = currentTrackList[i];

      if (viewModel.selectedTracks.contains(id)) {
        viewModel.lastShiftClickRange!.selected.add(id);
      } else {
        viewModel.lastShiftClickRange!.notSelected.add(id);
      }

      viewModel.selectedTracks.add(id);
    }
  }

  /// Creates a new pattern, and a new clip pointing to that pattern at the
  /// given time bounds on the given track.
  void createClip({
    required Id trackId,
    required double offset,
    required double width,
  }) {
    project.startUndoGroup();

    final track = project.tracks[trackId]!;

    final pattern = PatternModel.create(name: track.name)
      ..color = track.color.clone();

    final clip = ClipModel.create(
      patternId: pattern.id,
      trackId: trackId,
      offset: offset.round(),
      timeView: TimeViewModel(start: 0, end: width.round()),
    );

    project.execute(PatternAddRemoveCommand.add(pattern: pattern));
    project.execute(
      ClipAddRemoveCommand.add(
        arrangementID: project.sequence.activeArrangementID!,
        clip: clip,
      ),
    );

    project.commitUndoGroup();
  }
}
