/*
  Copyright (C) 2026 Joshua Wade

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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/widgets.dart';

import 'state_machine/timeline_state_machine.dart';
import 'timeline_interaction_target.dart';

/// The timeline controller, which owns logic for the timeline widget.
///
/// The current migration step establishes controller ownership of the timeline
/// state machine, while leaving live gesture handling on the legacy
/// widget-owned path in `timeline.dart`.
class TimelineController {
  final ProjectModel project;
  final Id? arrangementID;
  final Id? patternID;
  final TimelineInteractionTarget? interactionTarget;

  late final TimelineStateMachine stateMachine;

  bool _isDisposed = false;
  double? _lastPlayheadPositionSet;

  TimelineController({
    required this.project,
    required this.arrangementID,
    required this.patternID,
  }) : interactionTarget = TimelineInteractionTarget.tryCreate(
         arrangementID: arrangementID,
         patternID: patternID,
       ),
       assert(
         arrangementID == null || patternID == null,
         'TimelineController can target at most one sequence at a time.',
       ) {
    stateMachine = TimelineStateMachine.create(
      project: project,
      controller: this,
    );
  }

  Id? get sequenceId => interactionTarget?.sequenceId;

  void pointerDown(PointerDownEvent event) {
    stateMachine.onPointerDown(event);
  }

  void pointerMove(PointerMoveEvent event) {
    stateMachine.onPointerMove(event);
  }

  void pointerUp(PointerEvent event) {
    stateMachine.onPointerUp(event);
  }

  void pointerCancel(PointerCancelEvent event) {
    stateMachine.onPointerCancel(event);
  }

  void syncModifierState({
    required bool ctrlPressed,
    required bool altPressed,
    required bool shiftPressed,
  }) {
    stateMachine.syncModifierState(
      ctrlPressed: ctrlPressed,
      altPressed: altPressed,
      shiftPressed: shiftPressed,
    );
  }

  void onViewSizeChanged(Size viewSize) {
    stateMachine.onViewSizeChanged(viewSize);
  }

  void onRenderedTimeViewChanged({
    required double timeViewStart,
    required double timeViewEnd,
  }) {
    stateMachine.onRenderedTimeViewChanged(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }

  void registerPendingLoopHandlePress({
    required int pointerId,
    required TimelineLoopHandle handle,
  }) {
    stateMachine.registerPendingLoopHandlePress(
      pointerId: pointerId,
      handle: handle,
    );
  }

  void activateTransportSequence() {
    final sequenceId = this.sequenceId;
    if (sequenceId == null) {
      return;
    }

    if (project.sequence.activeTransportSequenceID != sequenceId) {
      project.sequence.activeTransportSequenceID = sequenceId;
    }
  }

  List<TimeSignatureChangeModel> timeSignatureChanges() {
    return interactionTarget?.timeSignatureChanges(project) ?? [];
  }

  LoopPointsModel? loopPoints() {
    return interactionTarget?.loopPoints(project);
  }

  void clearLoopPoints() {
    interactionTarget?.clearLoopPoints(project);
  }

  void setLoopPoints({required int start, required int end}) {
    interactionTarget?.setLoopPoints(project, start: start, end: end);
  }

  void updateLoopPoints({int? start, int? end}) {
    interactionTarget?.updateLoopPoints(project, start: start, end: end);
  }

  double clampTimelineTime(double rawTime) {
    return rawTime < 0 ? 0 : rawTime;
  }

  List<DivisionChange> divisionChanges({
    required double viewWidthInPixels,
    required double timeViewStart,
    required double timeViewEnd,
  }) {
    return getDivisionChanges(
      viewWidthInPixels: viewWidthInPixels,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: timeSignatureChanges(),
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      minPixelsPerSection: minorMinPixels,
    );
  }

  int resolveTimelineTime({
    required double rawTime,
    required bool ignoreSnap,
    required double viewWidthInPixels,
    required double timeViewStart,
    required double timeViewEnd,
    bool ceil = false,
    bool round = false,
    int startTime = 0,
  }) {
    final clampedTime = clampTimelineTime(rawTime);
    if (ignoreSnap) {
      return clampedTime.round();
    }

    return getSnappedTime(
      rawTime: clampedTime.toInt(),
      divisionChanges: divisionChanges(
        viewWidthInPixels: viewWidthInPixels,
        timeViewStart: timeViewStart,
        timeViewEnd: timeViewEnd,
      ),
      ceil: ceil,
      round: round,
      startTime: startTime,
    );
  }

  void setPlaybackStartPosition({
    required double rawTime,
    required bool ignoreSnap,
    required double viewWidthInPixels,
    required double timeViewStart,
    required double timeViewEnd,
  }) {
    final targetTime = resolveTimelineTime(
      rawTime: rawTime,
      ignoreSnap: ignoreSnap,
      viewWidthInPixels: viewWidthInPixels,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      round: true,
    );

    if (project.sequence.playbackStartPosition != targetTime) {
      project.sequence.playbackStartPosition = targetTime;
    }

    if (_lastPlayheadPositionSet != targetTime) {
      final targetTimeAsDouble = targetTime.toDouble();
      if (project.engine.isRunning) {
        project.engine.sequencerApi.jumpPlayheadTo(targetTimeAsDouble);
      }

      _lastPlayheadPositionSet = targetTimeAsDouble;
    }
  }

  void clearPlayheadJumpDedupState() {
    _lastPlayheadPositionSet = null;
  }

  @visibleForTesting
  bool get isDisposed => _isDisposed;

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    stateMachine.dispose();
  }
}
