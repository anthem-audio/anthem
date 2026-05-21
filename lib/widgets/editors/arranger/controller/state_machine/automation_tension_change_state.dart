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

part of 'arranger_state_machine.dart';

class _AutomationTensionChangeTarget {
  final Id patternId;
  final Id pointId;
  final int pointIndex;
  final double startTension;
  final ActivePointer startPointer;
  final bool invert;

  const _AutomationTensionChangeTarget({
    required this.patternId,
    required this.pointId,
    required this.pointIndex,
    required this.startTension,
    required this.startPointer,
    required this.invert,
  });
}

class ArrangerAutomationTensionChangeState extends _ArrangerLeafState {
  @override
  ArrangerDragState get parentState => super.parentState as ArrangerDragState;

  /// The idle ancestor owns primary click tracking. Once a tension drag starts,
  /// it should not also become a clip selection click when the pointer releases.
  ArrangerIdleState get _idleState => parentState.parentState;

  _AutomationTensionChangeTarget? _target;

  @override
  Iterable<EditorStateMachineStateTransition<ArrangerStateMachineData>>
  get transitions => [
    .new(
      name: 'Delegate drag to automation tension change',
      from: ArrangerDragState,
      to: ArrangerAutomationTensionChangeState,
      canTransition: ({required data, required event, required currentState}) =>
          (currentState as ArrangerDragState).interactionFamily ==
              ArrangerInteractionFamily.automationTensionChange &&
          _targetForDragState(currentState) != null,
    ),
    .new(
      name: 'Cancel automation tension change',
      from: ArrangerAutomationTensionChangeState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          isArrangerCancelSignal(event),
    ),
    .new(
      name: 'Automation tension change fallback to drag',
      from: ArrangerAutomationTensionChangeState,
      to: ArrangerDragState,
      canTransition: ({required data, required event, required currentState}) =>
          !(currentState as ArrangerAutomationTensionChangeState)
              .parentState
              .isDragPointerActive,
    ),
  ];

  ArrangerAutomationTensionChangeState(ArrangerDragState super.parentState);

  @override
  void onEntry({required event, required from}) {
    _idleState._clearPrimaryClickTracking();
    _initializeChangeSession();
    _syncTension();
  }

  @override
  void onActive({required event}) {
    _syncTension();
  }

  @override
  void onExit({required event, required to}) {
    if (_shouldCommit(event)) {
      _commitChangeSession();
    } else {
      _rollbackChangeSession();
    }

    _target = null;
  }

  void _initializeChangeSession() {
    _target = _targetForDragState(parentState);
  }

  _AutomationTensionChangeTarget? _targetForDragState(
    ArrangerDragState dragState,
  ) {
    final dragStartContext = dragState.dragStartContext;
    final clipId = dragStartContext?.automationClipContentClipId;
    final automationHandle = dragStartContext?.automationHandle;
    final startPointer = dragState.dragStartPosition;
    if (clipId == null ||
        automationHandle?.kind != AutomationHandleKind.tensionHandle ||
        startPointer == null) {
      return null;
    }

    final resolved = resolveAutomationPointForHandle(
      clipId: clipId,
      automationHandle: automationHandle!,
    );
    if (resolved == null || resolved.pointIndex <= 0) {
      return null;
    }

    final previousPoint =
        resolved.pattern.automation.points[resolved.pointIndex - 1];
    return _AutomationTensionChangeTarget(
      patternId: resolved.pattern.id,
      pointId: resolved.point.id,
      pointIndex: resolved.pointIndex,
      startTension: resolved.point.tension,
      startPointer: startPointer.clone(),
      invert: previousPoint.value < resolved.point.value,
    );
  }

  void _syncTension() {
    final target = _target;
    final currentPointer = parentState.dragCurrentPosition;
    if (target == null || currentPointer == null) {
      return;
    }

    final resolved = _resolveCurrentPoint(target);
    if (resolved == null) {
      return;
    }

    final deltaY = currentPointer.y - target.startPointer.y;
    final deltaTension = -deltaY / 250;
    final invertMultiplier = target.invert ? -1 : 1;
    resolved.point.tension =
        (target.startTension + invertMultiplier * deltaTension).clamp(
          -1.0,
          1.0,
        );
  }

  ({AutomationPointModel point, int pointIndex})? _resolveCurrentPoint(
    _AutomationTensionChangeTarget target,
  ) {
    final pattern = project.sequence.patterns[target.patternId];
    if (pattern == null) {
      return null;
    }

    final points = pattern.automation.points;
    var pointIndex = target.pointIndex;
    if (pointIndex < 0 ||
        pointIndex >= points.length ||
        points[pointIndex].id != target.pointId) {
      pointIndex = points.indexWhere((point) => point.id == target.pointId);
      if (pointIndex == -1) {
        return null;
      }
    }

    return (point: points[pointIndex], pointIndex: pointIndex);
  }

  bool _shouldCommit(EditorStateMachineEvent event) {
    if (isArrangerCancelSignal(event)) {
      return false;
    }

    if (event is! EditorStateMachineSignalEvent) {
      return false;
    }

    final signal = event.signal;
    return signal is _ArrangerPointerUpSignal &&
        signal.event is! PointerCancelEvent;
  }

  void _commitChangeSession() {
    final target = _target;
    if (target == null) {
      return;
    }

    final resolved = _resolveCurrentPoint(target);
    if (resolved == null) {
      return;
    }

    final newTension = resolved.point.tension;
    viewModel.lastInteractedAutomationTension = newTension;
    if (newTension == target.startTension) {
      return;
    }

    project.execute(
      SetAutomationPointTensionCommand(
        patternID: target.patternId,
        pointIndex: resolved.pointIndex,
        oldTension: target.startTension,
        newTension: newTension,
      ),
    );
  }

  void _rollbackChangeSession() {
    final target = _target;
    if (target == null) {
      return;
    }

    final resolved = _resolveCurrentPoint(target);
    if (resolved == null) {
      return;
    }

    resolved.point.tension = target.startTension;
  }
}
