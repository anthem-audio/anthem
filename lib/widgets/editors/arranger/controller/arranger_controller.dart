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

import 'package:anthem/logic/clipboard/clipboard_data.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/commands/timeline_commands.dart';
import 'package:anthem/logic/commands/arrangement_commands.dart';
import 'package:anthem/logic/commands/pattern_commands.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/model.dart';
import 'package:anthem/widgets/editors/arranger/automation_hold_segments.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';

import '../helpers.dart';

part 'shortcuts.dart';

const _parameterNodeBinding = 'parameterNode';

class ArrangerController extends _ArrangerController
    with _ArrangerShortcutsMixin
    implements DisposableService {
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
  bool _isDisposed = false;

  late final ReactionDisposer patternCursorAutorunDispose;
  late final ModelFilterSubscription parameterTouchSubscription;

  ProjectModel get _project =>
      AnthemStore.instance.projects[viewModel.projectId]!;

  _ArrangerController({required this.viewModel, required this.project}) {
    // Set up an autorun to update the current cursor pattern if the selected
    // pattern changes
    patternCursorAutorunDispose = autorun((_) {
      viewModel.cursorPattern = project.sequence.activePatternID;
      viewModel.cursorTimeRange = null;
    });

    parameterTouchSubscription = _subscribeToParameterTouches();
  }

  ModelFilterSubscription _subscribeToParameterTouches() {
    return project.processingGraph.onChange(
      (b) => b
          .nodes()
          .anyValue(bindTo: _parameterNodeBinding)
          .lastChangedControlPortId(),
      _handleParameterTouched,
    );
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    parameterTouchSubscription.cancel();
    patternCursorAutorunDispose();
    stateMachine.dispose();
  }

  void pointerDown(PointerDownEvent pointerEvent) {
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

  ProjectEntityIdAllocator get _idAllocator =>
      ServiceRegistry.forProject(project.id).idAllocator;

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

  void _handleParameterTouched(
    ModelChangeEvent _,
    ModelChangeBindings bindings,
  ) {
    final node = bindings.maybeGet<NodeModel>(_parameterNodeBinding);
    final portId = node?.lastChangedControlPortId;
    if (node == null || portId == null) {
      return;
    }

    final target = resolveAutomationTarget(nodeId: node.id, portId: portId);
    if (target == null) {
      return;
    }

    viewModel.lastTweakedAutomationTarget = target;
    viewModel.refreshTrackLayout(viewModel.editorHeight);
    onTrackLayoutChanged();
  }

  AutomationParameterTarget? resolveAutomationTarget({
    required Id nodeId,
    required int portId,
  }) {
    final node = project.processingGraph.nodes[nodeId];
    if (node == null) {
      return null;
    }

    NodePortModel port;
    try {
      port = node.getPortById(portId);
    } catch (_) {
      return null;
    }

    if (port.config.dataType != NodePortDataType.control ||
        port.config.parameterConfig == null) {
      return null;
    }

    final owner = node.owner;
    final trackId = owner?.trackId;
    if (trackId == null) {
      return null;
    }

    final track = project.tracks[trackId];
    final processing = track?.processing;
    if (track == null || processing == null) {
      return null;
    }

    final deviceId = owner?.deviceId;
    if (deviceId == null) {
      if (processing.utilityNodeId != nodeId) {
        return null;
      }

      return AutomationParameterTarget(
        ownerTrackId: track.id,
        nodeId: nodeId,
        portId: portId,
        ownerName: 'Track',
        parameterName: _trackUtilityAutomationParameterName(portId),
      );
    }

    final device = _findDeviceById(processing, deviceId);
    if (device == null || !device.nodeIds.contains(nodeId)) {
      return null;
    }

    return AutomationParameterTarget(
      ownerTrackId: track.id,
      nodeId: nodeId,
      portId: portId,
      ownerName: device.name,
      parameterName: _parameterNameForPort(node, port),
    );
  }

  DeviceModel? _findDeviceById(TrackProcessingModel processing, Id deviceId) {
    for (final device in processing.devices) {
      if (device.id == deviceId) {
        return device;
      }
    }

    return null;
  }

  String _trackUtilityAutomationParameterName(int portId) {
    if (portId == UtilityProcessorModel.gainPortId) {
      return 'Volume';
    }
    if (portId == UtilityProcessorModel.balancePortId) {
      return 'Balance';
    }

    return 'Parameter $portId';
  }

  String _parameterNameForPort(NodeModel node, NodePortModel port) {
    final processor = node.processor;
    if (processor is UtilityProcessorModel) {
      if (port.id == UtilityProcessorModel.gainPortId) {
        return 'Gain';
      }
      if (port.id == UtilityProcessorModel.balancePortId) {
        return 'Balance';
      }
    }

    return port.config.name ?? 'Parameter ${port.id}';
  }

  Id? createAutomationLaneForTarget(AutomationParameterTarget target) {
    final existingLaneId = viewModel.automationLaneIdForTarget(target);
    if (existingLaneId != null) {
      return existingLaneId;
    }

    if (!project.tracks.containsKey(target.ownerTrackId)) {
      return null;
    }

    final command = AutomationLaneAddRemoveCommand.add(
      project: project,
      parentTrackId: target.ownerTrackId,
      nodeId: target.nodeId,
      portId: target.portId,
      name: target.parameterName,
    );

    project.execute(command);

    viewModel.automationExpandedByTrackId[target.ownerTrackId] = true;
    viewModel.refreshTrackLayout(viewModel.editorHeight);
    onTrackLayoutChanged();

    return command.lane.id;
  }

  void createClipForAutomationTarget({
    required AutomationParameterTarget target,
    required double offset,
    double? width,
  }) {
    project.startUndoGroup();

    final trackId = createAutomationLaneForTarget(target);
    final track = trackId == null ? null : project.tracks[trackId];
    if (track == null) {
      project.commitUndoGroup();
      return;
    }

    final patternId = _createClipOnTrack(
      track: track,
      offset: offset,
      width: width,
      patternName: _newClipPatternNameForTarget(target),
    );

    project.commitUndoGroup();

    _openPatternForTrack(track: track, patternId: patternId);
  }

  Id _createClipOnTrack({
    required TrackModel track,
    required double offset,
    double? width,
    String? patternName,
  }) {
    final arrangementId = project.sequence.activeArrangementID!;
    final arrangement = project.sequence.arrangements[arrangementId]!;
    final clipOffset = offset.round();
    final pattern = PatternModel(
      idAllocator: _idAllocator,
      name: patternName ?? _newClipPatternNameForTrack(track),
    )..color = track.color.clone();
    if (track.isAutomationLane) {
      pattern.clipAutoSizeMode = PatternClipAutoSizeMode.content;
    }
    _seedAutomationClipPoints(
      track: track,
      pattern: pattern,
      clipOffset: clipOffset,
      width: width,
      arrangement: arrangement,
    );

    final clip = ClipModel(
      idAllocator: _idAllocator,
      patternId: pattern.id,
      trackId: track.id,
      offset: clipOffset,
      timeView: width == null
          ? null
          : TimeViewModel(start: 0, end: width.round()),
    );

    project.execute(PatternAddRemoveCommand.add(pattern: pattern));
    project.execute(
      ClipAddRemoveCommand.add(arrangementID: arrangementId, clip: clip),
    );

    return pattern.id;
  }

  void _seedAutomationClipPoints({
    required TrackModel track,
    required PatternModel pattern,
    required int clipOffset,
    required double? width,
    required ArrangementModel arrangement,
  }) {
    if (!track.isAutomationLane) {
      return;
    }

    final target = track.automationTarget;
    if (target == null) {
      return;
    }

    final value = _automationClipSeedValue(
      track: track,
      arrangement: arrangement,
      clipOffset: clipOffset,
    );
    if (value == null) {
      return;
    }

    final endOffset = max(0, width?.round() ?? _defaultPatternWidth());

    pattern.automation.points.addAll([
      AutomationPointModel(idAllocator: _idAllocator, offset: 0, value: value),
      AutomationPointModel(
        idAllocator: _idAllocator,
        offset: endOffset,
        value: value,
      ),
    ]);
  }

  double? _automationClipSeedValue({
    required TrackModel track,
    required ArrangementModel arrangement,
    required int clipOffset,
  }) {
    final holdValue = automationHoldValueForTrackAtTick(
      project: project,
      arrangement: arrangement,
      trackId: track.id,
      tick: clipOffset.toDouble(),
    );
    if (holdValue != null) {
      return holdValue;
    }

    final processor =
        track
                .requireAutomationProcessing
                .sequenceAutomationProviderNode!
                .processor
            as SequenceAutomationProviderProcessorModel;

    return processor.emptyValue;
  }

  int _defaultPatternWidth() {
    final timeSignature = project.sequence.defaultTimeSignature;
    final ticksPerBarDouble =
        project.sequence.ticksPerQuarter /
        (timeSignature.denominator / 4) *
        timeSignature.numerator;
    final ticksPerBar = ticksPerBarDouble.round();

    assert(ticksPerBarDouble == ticksPerBar);

    return max(ticksPerBar, 1);
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
    viewModel.refreshTrackLayout(viewModel.editorHeight);

    onBaseTrackHeightChanged.add(null);
  }

  /// We need to snap the vertical scroll position animation when this happens.
  final onBaseTrackHeightChanged = StreamController<void>.broadcast();

  void deleteSelectedClips() {
    deleteClips(viewModel.selectedClips.nonObservableInner);
  }

  ArrangementModel? get _activeArrangementOrNull {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return null;
    }

    return project.sequence.arrangements[arrangementId];
  }

  bool openClipInEditor(Id clipId) {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return false;
    }

    final arrangement = project.sequence.arrangements[arrangementId];
    final clip = arrangement?.clips[clipId];
    if (clip == null) {
      return false;
    }

    final track = project.tracks[clip.trackId];
    if (track == null) {
      return false;
    }

    if (track.isAutomationLane) {
      ServiceRegistry.forProject(
        project.id,
      ).trackController.setActiveTrack(track.id);
      return false;
    }

    _openPatternForTrack(track: track, patternId: clip.patternId);
    return true;
  }

  void deleteClips(Iterable<Id> clipIds) {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return;
    }

    final trackController = ServiceRegistry.forProject(
      project.id,
    ).trackController;

    final deletionResult = trackController.deleteClips(
      arrangementId: arrangementId,
      clipIds: clipIds,
    );

    viewModel.selectedClips.removeAll(deletionResult.deletedClipIds);
  }

  List<ClipModel> _getSelectedClips(ArrangementModel arrangement) {
    final selectedClipIds = viewModel.selectedClips.nonObservableInner;

    return arrangement.clips.values
        .where((clip) => selectedClipIds.contains(clip.id))
        .toList(growable: false);
  }

  int _copyAnchorOffset(List<ClipModel> clips) {
    var anchorOffset = clips.first.offset;

    for (final clip in clips.skip(1)) {
      if (clip.offset < anchorOffset) {
        anchorOffset = clip.offset;
      }
    }

    return anchorOffset;
  }

  bool copySelectedClips() {
    final arrangement = _activeArrangementOrNull;
    if (arrangement == null || viewModel.selectedClips.isEmpty) {
      return false;
    }

    final selectedClips = _getSelectedClips(arrangement);
    if (selectedClips.isEmpty) {
      return false;
    }

    final patternsById = <Id, PatternModel>{};
    final copyableClips = <ClipModel>[];
    for (final clip in selectedClips) {
      final pattern = project.sequence.patterns[clip.patternId];
      if (pattern == null) {
        continue;
      }

      patternsById[pattern.id] = pattern;
      copyableClips.add(clip);
    }

    if (copyableClips.isEmpty) {
      return false;
    }

    ServiceRegistry.clipboard.set(
      ArrangerClipboardContent(
        anchorOffset: _copyAnchorOffset(copyableClips),
        clips: copyableClips,
        patterns: patternsById.values,
      ),
    );

    return true;
  }

  void cutSelectedClips() {
    if (!copySelectedClips()) {
      return;
    }

    deleteSelectedClips();
  }

  int? _playbackStartPasteAnchorOffset() {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null ||
        project.sequence.activeTransportSequenceID != arrangementId) {
      return null;
    }

    final playbackStartPosition = project.sequence.playbackStartPosition;
    if (playbackStartPosition < viewModel.timeRange.start ||
        playbackStartPosition >= viewModel.timeRange.end) {
      return null;
    }

    return playbackStartPosition < 0 ? 0 : playbackStartPosition;
  }

  List<DivisionChange> _pasteDivisionChanges() {
    final viewWidth = max(stateMachine.data.viewSize.width, 1).toDouble();

    return getDivisionChanges(
      viewWidthInPixels: viewWidth,
      snap: AutoSnap(),
      defaultTimeSignature: project.sequence.defaultTimeSignature,
      timeSignatureChanges: stateMachine.arrangementTimeSignatureChanges(),
      ticksPerQuarter: project.sequence.ticksPerQuarter,
      timeViewStart: viewModel.timeRange.start,
      timeViewEnd: viewModel.timeRange.end,
    );
  }

  int _visibleStartPasteAnchorOffset() {
    final visibleStart = viewModel.timeRange.start;
    final rawTime = visibleStart <= 0 ? 0 : visibleStart.ceil();

    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: _pasteDivisionChanges(),
      ceil: true,
    );
  }

  int _pasteAnchorOffset() {
    return _playbackStartPasteAnchorOffset() ??
        _visibleStartPasteAnchorOffset();
  }

  void pasteClips() {
    final arrangement = _activeArrangementOrNull;
    final content = ServiceRegistry.clipboard.get<ArrangerClipboardContent>();
    if (arrangement == null || content == null) {
      return;
    }

    final reconstructedContent = content.reconstruct(
      idAllocator: _idAllocator,
      newAnchorOffset: _pasteAnchorOffset(),
      availableTrackIds: project.tracks.keys.toSet(),
    );
    final patterns = reconstructedContent.patterns;
    final clips = reconstructedContent.clips;
    if (clips.isEmpty) {
      return;
    }

    viewModel.clipTimingOverrides.clear();

    project.startUndoGroup();
    for (final pattern in patterns) {
      project.execute(PatternAddRemoveCommand.add(pattern: pattern));
    }
    for (final clip in clips) {
      project.execute(
        ClipAddRemoveCommand.add(arrangementID: arrangement.id, clip: clip),
      );
    }
    project.commitUndoGroup();

    viewModel.selectedClips = ObservableSet.of(
      clips.map((clip) => clip.id).toSet(),
    );
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

  void _nudgeSelectedClipsInTime({
    required int direction,
    required List<DivisionChange> divisionChanges,
  }) {
    int resolveNudgeDelta({required int startOfFirstClip}) {
      assert(direction == -1 || direction == 1);
      if (direction != -1 && direction != 1) {
        return 0;
      }

      final step = getSnapSizeAtAbsoluteTime(
        absoluteTime: direction > 0 ? startOfFirstClip : startOfFirstClip - 1,
        divisionChanges: divisionChanges,
      );
      final requestedDelta = direction * step;

      if (startOfFirstClip + requestedDelta < 0) {
        return -startOfFirstClip;
      }

      return requestedDelta;
    }

    if (stateMachine.currentState is! ArrangerIdleState) {
      return;
    }

    final arrangementId = project.sequence.activeArrangementID;
    final arrangement = arrangementId == null
        ? null
        : project.sequence.arrangements[arrangementId];
    if (arrangement == null || viewModel.selectedClips.isEmpty) {
      return;
    }

    final selectedClipIds = viewModel.selectedClips.nonObservableInner;
    final selectedClips = arrangement.clips.nonObservableInner.values
        .where((clip) => selectedClipIds.contains(clip.id))
        .toList(growable: false);

    if (selectedClips.isEmpty) {
      return;
    }

    var startOfFirstClip = selectedClips.first.offset;
    for (final clip in selectedClips.skip(1)) {
      if (clip.offset < startOfFirstClip) {
        startOfFirstClip = clip.offset;
      }
    }

    final timeDelta = resolveNudgeDelta(startOfFirstClip: startOfFirstClip);

    if (timeDelta == 0) {
      return;
    }

    viewModel.clipTimingOverrides.clear();

    project.execute(
      MoveClipsCommand(
        arrangementID: arrangement.id,
        clipMoves: selectedClips
            .map((clip) {
              return (
                clipID: clip.id,
                oldOffset: clip.offset,
                newOffset: clip.offset + timeDelta,
              );
            })
            .toList(growable: false),
      ),
    );
  }

  void nudgeSelectedClipsByCurrentSnap(int direction) {
    _nudgeSelectedClipsInTime(
      direction: direction,
      divisionChanges: stateMachine.divisionChanges(),
    );
  }

  void nudgeSelectedClipsByBar(int direction) {
    _nudgeSelectedClipsInTime(
      direction: direction,
      divisionChanges: stateMachine.divisionChanges(
        snap: BarSnap(),
        minPixelsPerSection: 0,
      ),
    );
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
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    final trackController = serviceRegistry.trackController;

    if (project.sequence.activeArrangementID == null) {
      return;
    }

    final currentTrackList = trackController
        .getTracksIterable()
        .map((track) => track.$1)
        .toList(growable: false);

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
  ///
  /// If [width] is null, the clip is created with no explicit time view, so it
  /// auto-sizes from the target pattern.
  void createClip({
    required Id trackId,
    required double offset,
    double? width,
  }) {
    final track = project.tracks[trackId]!;

    project.startUndoGroup();
    final patternId = _createClipOnTrack(
      track: track,
      offset: offset,
      width: width,
    );
    project.commitUndoGroup();

    _openPatternForTrack(track: track, patternId: patternId);
  }

  String _newClipPatternNameForTrack(TrackModel track) {
    if (!track.isAutomationLane) {
      return track.name;
    }

    final automationTarget = track.automationTarget;
    if (automationTarget == null) {
      return track.name;
    }

    final resolvedTarget = resolveAutomationTarget(
      nodeId: automationTarget.nodeId,
      portId: automationTarget.portId,
    );
    if (resolvedTarget == null) {
      return track.name;
    }

    return '${resolvedTarget.ownerName} - ${resolvedTarget.parameterName}';
  }

  String _newClipPatternNameForTarget(AutomationParameterTarget target) {
    return '${target.ownerName} - ${target.parameterName}';
  }

  void _openPatternForTrack({
    required TrackModel track,
    required Id patternId,
  }) {
    final serviceRegistry = ServiceRegistry.forProject(project.id);
    serviceRegistry.trackController.setActiveTrack(track.id);

    if (track.isAutomationLane) {
      return;
    }

    serviceRegistry.projectController.openPatternInPianoRoll(patternId);
  }

  /// Adds a time signature change to the active arrangement.
  void addTimeSignatureChange({
    required TimeSignatureModel timeSignature,
    required Time offset,
    bool snap = true,
  }) {
    final arrangementId = project.sequence.activeArrangementID;
    if (arrangementId == null) {
      return;
    }

    var snappedOffset = offset;
    if (snap) {
      final arrangement = project.sequence.arrangements[arrangementId];
      if (arrangement == null) {
        return;
      }

      final divisionChanges = getDivisionChanges(
        viewWidthInPixels: max(stateMachine.data.viewSize.width, 1),
        snap: AutoSnap(),
        defaultTimeSignature: project.sequence.defaultTimeSignature,
        timeSignatureChanges: arrangement.timeSignatureChanges,
        ticksPerQuarter: project.sequence.ticksPerQuarter,
        timeViewStart: viewModel.timeRange.start,
        timeViewEnd: viewModel.timeRange.end,
      );

      snappedOffset = getSnappedTime(
        rawTime: offset.floor(),
        divisionChanges: divisionChanges,
        ceil: true,
      );
    }

    project.execute(
      AddTimeSignatureChangeCommand(
        timelineKind: TimelineKind.arrangement,
        arrangementID: arrangementId,
        change: TimeSignatureChangeModel(
          idAllocator: _idAllocator,
          offset: snappedOffset,
          timeSignature: timeSignature,
        ),
      ),
    );
  }
}
