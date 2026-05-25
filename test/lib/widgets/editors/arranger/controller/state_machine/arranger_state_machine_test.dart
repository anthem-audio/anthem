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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackIds {
  static const a = 1;
  static const b = 2;
  static const master = 3;
  static const automationA = 4;
}

class _ClipIds {
  static const underCursor = 101;
  static const underResizeHandle = 102;
  static const selected = 103;
  static const notSelected = 104;
  static const someOtherSelected = 105;
  static const a = 106;
  static const b = 107;
  static const c = 108;
  static const d = 109;
}

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

Id? _trackIdForRowId(ArrangerViewModel viewModel, Id? rowId) {
  if (rowId == null) {
    return null;
  }

  return switch (viewModel.trackPositionCalculator.tryRowIdToRow(rowId)) {
    TrackArrangerRow(:final trackId) => trackId,
    PhantomAutomationArrangerRow() || null => null,
  };
}

Id? _phantomParentTrackIdForRowId(ArrangerViewModel viewModel, Id? rowId) {
  if (rowId == null) {
    return null;
  }

  return switch (viewModel.trackPositionCalculator.tryRowIdToRow(rowId)) {
    PhantomAutomationArrangerRow(:final phantomLane) =>
      phantomLane.parentTrackId,
    TrackArrangerRow() || null => null,
  };
}

void _expectAutomationHandle(
  AutomationHandleAnnotation? handle, {
  required Id clipId,
  required AutomationHandleKind kind,
  required Id pointId,
}) {
  expect(handle, isNotNull);
  expect(handle!.clipId, clipId);
  expect(handle.kind, kind);
  expect(handle.pointId, pointId);
}

TrackModel _makeTrack(Id id, String name, TrackType type) {
  return TrackModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    name: name,
    color: AnthemColor.randomHue(),
    type: type,
  );
}

class _ArrangerStateMachineTestFixture {
  static const viewSize = Size(960, 240);
  static const editorHeight = 240.0;

  final ProjectModel project;
  final ArrangerViewModel viewModel;
  final ProjectViewModel projectViewModel;
  final ProjectController projectController;
  final ArrangerController controller;

  _ArrangerStateMachineTestFixture._({
    required this.project,
    required this.viewModel,
    required this.projectViewModel,
    required this.projectController,
    required this.controller,
  });

  factory _ArrangerStateMachineTestFixture.create() {
    final project = ProjectModel();
    project.isHydrated = true;
    project.sequence = SequencerModel(idAllocator: _testIdAllocator());

    project.tracks = AnthemObservableMap.of({
      _TrackIds.a: _makeTrack(_TrackIds.a, 'A', TrackType.normal),
      _TrackIds.b: _makeTrack(_TrackIds.b, 'B', TrackType.normal),
      _TrackIds.master: _makeTrack(
        _TrackIds.master,
        'Master',
        TrackType.normal,
      ),
    });
    project.trackOrder = AnthemObservableList.of([_TrackIds.a, _TrackIds.b]);
    project.sendTrackOrder = AnthemObservableList.of([_TrackIds.master]);

    final viewModel = ArrangerViewModel(
      project: project,
      baseTrackHeight: 60,
      timeView: TimeRange(0, 960),
    );
    final projectViewModel = ProjectViewModel()
      ..activePanel = PanelKind.arranger;
    final projectController = ProjectController(project, projectViewModel);

    AnthemStore.instance.projects[project.id] = project;
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(projectViewModelService, (_, _) => projectViewModel),
        overrideService(projectControllerService, (_, _) => projectController),
        overrideService(arrangerViewModelService, (_, _) => viewModel),
      ]),
    );

    final controller = ArrangerController(
      viewModel: viewModel,
      project: project,
    );
    controller.onViewSizeChanged(viewSize);
    viewModel.trackPositionCalculator.invalidate(editorHeight);

    return _ArrangerStateMachineTestFixture._(
      project: project,
      viewModel: viewModel,
      projectViewModel: projectViewModel,
      projectController: projectController,
      controller: controller,
    );
  }

  ArrangerStateMachine get stateMachine => controller.stateMachine;

  ArrangerIdleState get idleState =>
      stateMachine.states[ArrangerIdleState]! as ArrangerIdleState;

  ArrangerDragState get dragState =>
      stateMachine.states[ArrangerDragState]! as ArrangerDragState;

  ArrangerAutomationPointMoveState get automationPointMoveState =>
      stateMachine.states[ArrangerAutomationPointMoveState]!
          as ArrangerAutomationPointMoveState;

  ArrangerAutomationTensionChangeState get automationTensionChangeState =>
      stateMachine.states[ArrangerAutomationTensionChangeState]!
          as ArrangerAutomationTensionChangeState;

  ArrangerCreateClipState get createClipState =>
      stateMachine.states[ArrangerCreateClipState]! as ArrangerCreateClipState;

  ArrangerClipMoveState get clipMoveState =>
      stateMachine.states[ArrangerClipMoveState]! as ArrangerClipMoveState;

  ArrangerClipResizeState get clipResizeState =>
      stateMachine.states[ArrangerClipResizeState]! as ArrangerClipResizeState;

  ArrangerSelectionBoxState get selectionBoxState =>
      stateMachine.states[ArrangerSelectionBoxState]!
          as ArrangerSelectionBoxState;

  void pointerDown(PointerDownEvent pointerEvent) {
    controller.pointerDown(pointerEvent);
  }

  void pointerMove(PointerMoveEvent pointerEvent) {
    controller.pointerMove(pointerEvent);
  }

  void pointerUp(PointerEvent pointerEvent) {
    controller.pointerUp(pointerEvent);
  }

  void hover(Offset pos) {
    controller.onHover(PointerHoverEvent(position: pos));
  }

  void enter(Offset pos) {
    controller.onEnter(PointerEnterEvent(position: pos));
  }

  void exit(Offset pos) {
    controller.onExit(PointerExitEvent(position: pos));
  }

  void pressEscape() {
    controller.onRawKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
      ),
    );
  }

  void showPhantomAutomationLaneForTrack(Id trackId) {
    viewModel.automationExpandedByTrackId[trackId] = true;
    viewModel.trackPositionCalculator.invalidate(editorHeight);
    controller.onTrackLayoutChanged();
  }

  AutomationParameterTarget showTargetedPhantomAutomationLaneForTrack(
    Id trackId,
  ) {
    final target = AutomationParameterTarget(
      ownerTrackId: trackId,
      nodeId: 9001,
      portId: 9002,
      ownerName: 'Track',
      parameterName: 'Volume',
    );
    viewModel.lastTweakedAutomationTarget = target;
    showPhantomAutomationLaneForTrack(trackId);

    return target;
  }

  void showRealAutomationLaneForTrack(Id trackId) {
    final parentTrack = project.tracks[trackId]!;
    final automationLane = _makeTrack(
      _TrackIds.automationA,
      'A Automation',
      TrackType.automationLane,
    )..automationLaneParentTrackId = parentTrack.id;

    project.tracks[automationLane.id] = automationLane;
    parentTrack.automationLanes.add(automationLane.id);
    viewModel.registerTrack(automationLane.id);
    viewModel.automationExpandedByTrackId[trackId] = true;
    viewModel.trackPositionCalculator.invalidate(editorHeight);
    controller.onTrackLayoutChanged();
  }

  void dispose() {
    controller.dispose();
    ServiceRegistry.mainWindowController.clearAllCursorOverrides();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ArrangerStateMachineTestFixture fixture;
  late void Function(Offset globalPosition, MenuDef menu)
  defaultOpenContextMenuFn;

  setUp(() {
    defaultOpenContextMenuFn = ArrangerIdleState.openContextMenuFn;
    fixture = _ArrangerStateMachineTestFixture.create();
  });

  tearDown(() {
    ArrangerIdleState.openContextMenuFn = defaultOpenContextMenuFn;
    fixture.dispose();
  });

  group('ArrangerIdleState', () {
    ({ClipModel clip, PatternModel pattern}) addVisibleAutomationClip({
      Id clipId = _ClipIds.underCursor,
      Rect rect = const Rect.fromLTWH(110, 15, 40, 45),
    }) {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Automation',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: _testIdAllocator(() => clipId),
        patternId: pattern.id,
        trackId: _TrackIds.automationA,
        offset: 100,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    test('hover over track updates cursor location', () {
      fixture.hover(const Offset(120, 20));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        _trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        _TrackIds.a,
      );
    });

    test('hover over phantom automation lane updates cursor location', () {
      fixture.showPhantomAutomationLaneForTrack(_TrackIds.a);

      fixture.hover(const Offset(120, 80));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        _phantomParentTrackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        _TrackIds.a,
      );
    });

    test('hover over real automation lane updates cursor location', () {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      fixture.hover(const Offset(120, 80));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        _trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        _TrackIds.automationA,
      );
    });

    test('hover outside track clears cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(fixture.viewModel.hoveredClip, isNull);

      fixture.hover(const Offset(120, -10));

      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test(
      'hover over clip sets hovered clip and keeps canvas cursor as defer',
      () {
        fixture.hover(const Offset(80, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
        expect(fixture.viewModel.hoveredClip, isNull);

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 40, 30),
          metadata: _ClipIds.underCursor,
        );

        fixture.hover(const Offset(120, 20));

        expect(fixture.viewModel.mouseCursor, MouseCursor.defer);
        expect(fixture.viewModel.hoverIndicatorPosition, isNull);
        expect(fixture.viewModel.hoveredClip, _ClipIds.underCursor);
      },
    );

    test('hover over clip-adjacent divider does not show cursor location', () {
      final trackPosition = fixture.viewModel.trackPositionCalculator
          .getTrackPosition(0);
      final trackHeight = fixture.viewModel.trackPositionCalculator
          .getTrackHeight(0);
      final dividerY = trackPosition + trackHeight - 1;

      fixture.viewModel.visibleClips.add(
        rect: Rect.fromLTRB(110, trackPosition, 150, dividerY),
        metadata: _ClipIds.underCursor,
      );

      expect(
        fixture.viewModel.trackPositionCalculator.rowAtPosition(dividerY),
        isNull,
      );
      final borderIncludedHit = fixture.viewModel.trackPositionCalculator
          .rowAtPosition(dividerY, includeBorder: true);
      expect(borderIncludedHit, isNotNull);
      expect(borderIncludedHit!.rowIndex, 0);

      fixture.hover(Offset(120, dividerY - 1));
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, _ClipIds.underCursor);

      fixture.hover(Offset(120, dividerY));
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test('hover on first pixel of next row uses next row', () {
      final nextTrackPosition = fixture.viewModel.trackPositionCalculator
          .getTrackPosition(1);

      final borderIncludedHit = fixture.viewModel.trackPositionCalculator
          .rowAtPosition(nextTrackPosition, includeBorder: true);
      expect(borderIncludedHit, isNotNull);
      expect(borderIncludedHit!.rowIndex, 1);

      fixture.hover(Offset(120, nextTrackPosition));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        _trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        _TrackIds.b,
      );
    });

    test('hover over automation clip content shows automation handles', () {
      final (:clip, :pattern) = addVisibleAutomationClip();

      fixture.hover(const Offset(120, 20));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);

      fixture.hover(const Offset(120, 38));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.hover(const Offset(120, 20));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('hovering automation point handle updates handle visual state', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final point = AutomationPointModel(
        idAllocator: _testIdAllocator(() => 900),
        offset: 0,
        value: 0.5,
      );
      pattern.automation.points.add(point);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointIndex: 0,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );

      fixture.hover(const Offset(120, 38));

      _expectAutomationHandle(
        fixture.viewModel.hoveredAutomationHandle,
        clipId: clip.id,
        kind: AutomationHandleKind.point,
        pointId: point.id,
      );
      expect(fixture.viewModel.pressedAutomationHandle, isNull);

      fixture.exit(const Offset(-1, -1));

      expect(fixture.viewModel.hoveredAutomationHandle, isNull);
      expect(fixture.viewModel.pressedAutomationHandle, isNull);
    });

    test('pressing automation tension handle updates handle visual state', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final previousPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final point = AutomationPointModel(
        idAllocator: _testIdAllocator(() => 900),
        offset: 96,
        value: 0.75,
      );
      pattern.automation.points.addAll([previousPoint, point]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );

      fixture.hover(const Offset(120, 38));
      _expectAutomationHandle(
        fixture.viewModel.hoveredAutomationHandle,
        clipId: clip.id,
        kind: AutomationHandleKind.tensionHandle,
        pointId: point.id,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );

      expect(fixture.viewModel.hoveredAutomationHandle, isNull);
      _expectAutomationHandle(
        fixture.viewModel.pressedAutomationHandle,
        clipId: clip.id,
        kind: AutomationHandleKind.tensionHandle,
        pointId: point.id,
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      _expectAutomationHandle(
        fixture.viewModel.hoveredAutomationHandle,
        clipId: clip.id,
        kind: AutomationHandleKind.tensionHandle,
        pointId: point.id,
      );
      expect(fixture.viewModel.pressedAutomationHandle, isNull);
    });

    test('clicking automation clip title selects the clip', () {
      final (:clip, :pattern) = addVisibleAutomationClip();

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 20)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('clicking automation clip content selects the clip', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('clicking automation point handle preserves clip selection', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final point = AutomationPointModel(
        idAllocator: _testIdAllocator(() => 900),
        offset: 0,
        value: 0.5,
      );
      pattern.automation.points.add(point);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointIndex: 0,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      fixture.hover(const Offset(120, 38));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({_ClipIds.someOtherSelected}),
      );
      expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('clicking automation tension handle selects the clip', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 0,
          pointId: 900,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('right-clicking automation tension handle resets tension', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final previousPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final point = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 96,
        value: 0.75,
        tension: 0.4,
      );
      pattern.automation.points.addAll([previousPoint, point]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(openCount, 0);
      expect(point.tension, 0);
      expect(fixture.viewModel.lastInteractedAutomationTension, 0);
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({_ClipIds.someOtherSelected}),
      );

      fixture.project.undo();

      expect(point.tension, 0.4);
    });

    test('double-clicking automation tension handle resets tension', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final previousPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final point = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 96,
        value: 0.75,
        tension: 0.4,
      );
      pattern.automation.points.addAll([previousPoint, point]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(point.tension, 0);
      expect(fixture.viewModel.lastInteractedAutomationTension, 0);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);

      fixture.project.undo();
      expect(point.tension, 0.4);
    });

    test('double-clicking automation point handle deletes the point', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final firstPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final deletedPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(() => 900),
        offset: 48,
        value: 0.5,
        tension: 0.2,
      );
      final lastPoint = AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: 96,
        value: 0.75,
      );
      pattern.automation.points.addAll([firstPoint, deletedPoint, lastPoint]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointIndex: 1,
          pointId: deletedPoint.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(pattern.automation.points, [firstPoint, lastPoint]);
      expect(fixture.viewModel.selectedClips, {_ClipIds.someOtherSelected});
      expect(fixture.viewModel.hoveredAutomationHandle, isNull);
      expect(fixture.viewModel.pressedAutomationHandle, isNull);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);

      fixture.project.undo();
      expect(pattern.automation.points, [firstPoint, deletedPoint, lastPoint]);

      fixture.project.redo();
      expect(pattern.automation.points, [firstPoint, lastPoint]);
    });

    test('hover over resize handle updates canvas cursor and hovered clip', () {
      fixture.hover(const Offset(80, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(fixture.viewModel.hoveredClip, isNull);

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 8, 30),
        metadata: (id: _ClipIds.underCursor, type: ResizeAreaType.start),
      );

      fixture.hover(const Offset(112, 20));

      expect(fixture.viewModel.mouseCursor, SystemMouseCursors.resizeLeftRight);
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, _ClipIds.underCursor);
    });

    test('hitTestContent prefers end handle when start and end overlap', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: _ClipIds.underCursor, type: ResizeAreaType.start),
      );
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 20, 30),
        metadata: (id: _ClipIds.underCursor, type: ResizeAreaType.end),
      );

      final content = fixture.viewModel.hitTestContent(const Offset(120, 20));

      expect(content.resizeHandle, isNotNull);
      expect(content.resizeHandle!.metadata.type, ResizeAreaType.end);
    });

    test(
      'hitTestContent keeps clip match priority over non-matching end handle',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 40, 30),
          metadata: _ClipIds.underCursor,
        );
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(110, 15, 20, 30),
          metadata: (id: _ClipIds.someOtherSelected, type: ResizeAreaType.end),
        );
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(110, 15, 20, 30),
          metadata: (id: _ClipIds.underCursor, type: ResizeAreaType.start),
        );

        final content = fixture.viewModel.hitTestContent(const Offset(120, 20));

        expect(content.clip, isNotNull);
        expect(content.clip!.annotation.metadata, _ClipIds.underCursor);
        expect(content.resizeHandle, isNotNull);
        expect(content.resizeHandle!.metadata.id, _ClipIds.underCursor);
        expect(content.resizeHandle!.metadata.type, ResizeAreaType.start);
      },
    );

    test(
      'hitTestContent prefers automation point handles over tension handles',
      () {
        const handleRect = Rect.fromLTWH(116, 16, 16, 16);
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 80, 45),
          metadata: _ClipIds.underCursor,
        );
        fixture.viewModel.visibleAutomationHandles.add(
          rect: handleRect,
          metadata: AutomationHandleAnnotation(
            clipId: _ClipIds.underCursor,
            kind: AutomationHandleKind.point,
            pointIndex: 0,
            pointId: 900,
            center: handleRect.center,
          ),
        );
        fixture.viewModel.visibleAutomationHandles.add(
          rect: handleRect,
          metadata: AutomationHandleAnnotation(
            clipId: _ClipIds.underCursor,
            kind: AutomationHandleKind.tensionHandle,
            pointIndex: 1,
            pointId: 901,
            center: handleRect.center,
          ),
        );

        final content = fixture.viewModel.hitTestContent(const Offset(120, 20));

        expect(content.automationHandle, isNotNull);
        expect(
          content.automationHandle!.metadata.kind,
          AutomationHandleKind.point,
        );
        expect(content.automationHandle!.metadata.pointId, 900);
      },
    );

    test('state machine identifies automation clip content', () {
      final (:clip, :pattern) = addVisibleAutomationClip();

      final titleContext = fixture.stateMachine.pointerContextAt(
        const Offset(120, 20),
      );
      expect(titleContext.hitTestResult.clip, isNotNull);
      expect(titleContext.hitTestResult.clip!.annotation.metadata, clip.id);
      expect(titleContext.target.clipId, clip.id);
      expect(titleContext.target.isAutomationClipContent, isFalse);

      final bodyContext = fixture.stateMachine.pointerContextAt(
        const Offset(120, 38),
      );
      expect(bodyContext.hitTestResult.clip, isNotNull);
      expect(bodyContext.hitTestResult.clip!.annotation.metadata, clip.id);
      expect(bodyContext.selectableClipId, clip.id);
      expect(bodyContext.movableClipId, clip.id);
      expect(bodyContext.target.isAutomationClipContent, isTrue);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('state machine keeps automation resize handles selectable', () {
      final (:clip, :pattern) = addVisibleAutomationClip(
        rect: const Rect.fromLTWH(110, 15, 80, 45),
      );
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(184, 31, 14, 29),
        metadata: (id: clip.id, type: ResizeAreaType.end),
      );

      final bodyResizeContext = fixture.stateMachine.pointerContextAt(
        const Offset(188, 38),
      );

      expect(bodyResizeContext.target.isAutomationClipContent, isTrue);
      expect(bodyResizeContext.selectableClipId, clip.id);
      expect(bodyResizeContext.automationClipContentClipId, clip.id);
      expect(bodyResizeContext.resizeHandleTarget?.metadata.id, clip.id);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test(
      'hover leaving clip restores timeline cursor location and clears hovered clip',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 40, 30),
          metadata: _ClipIds.underCursor,
        );

        fixture.hover(const Offset(120, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNull);
        expect(fixture.viewModel.hoveredClip, _ClipIds.underCursor);

        fixture.hover(const Offset(200, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
        expect(
          _trackIdForRowId(
            fixture.viewModel,
            fixture.viewModel.hoverIndicatorPosition!.rowId,
          ),
          _TrackIds.a,
        );
        expect(fixture.viewModel.hoveredClip, isNull);
      },
    );

    test('exit clears hover-derived cursor location and hovered clip', () {
      fixture.enter(const Offset(120, 20));
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.hover(const Offset(121, 20));
      expect(fixture.viewModel.hoveredClip, _ClipIds.underCursor);

      fixture.exit(const Offset(120, 20));

      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test('exit clears automation handles clip', () {
      final (:clip, :pattern) = addVisibleAutomationClip();

      fixture.hover(const Offset(120, 38));
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.exit(const Offset(120, 38));

      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
      expect(fixture.project.sequence.patterns[pattern.id], same(pattern));
    });

    test('exit clears canvas cursor', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: _ClipIds.underCursor,
      );

      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.mouseCursor, MouseCursor.defer);

      fixture.exit(const Offset(120, 20));

      expect(fixture.viewModel.mouseCursor, MouseCursor.defer);
    });

    test('alt modifier disables snapping for cursor offset', () {
      const initialPos = Offset(13.25, 20);
      const altTestPos = Offset(17.25, 20);
      const releasedPos = Offset(21.25, 20);
      final rawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: altTestPos.dx,
      );
      final releasedRawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: releasedPos.dx,
      );
      final expectedReleasedSnappedOffset = getSnappedTime(
        rawTime: releasedRawOffset.round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
        round: true,
      ).toDouble();

      fixture.hover(initialPos);
      final snappedOffset = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
      fixture.hover(altTestPos);
      final unsnappedOffset = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.stateMachine.modifierReleased(ArrangerModifierKey.alt);
      fixture.hover(releasedPos);
      final snappedOffsetAgain =
          fixture.viewModel.hoverIndicatorPosition!.offset;

      expect(unsnappedOffset, closeTo(rawOffset, 1e-9));
      expect(unsnappedOffset, isNot(equals(snappedOffset)));
      expect(snappedOffsetAgain, expectedReleasedSnappedOffset);
    });

    test('view transform changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      final before = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.controller.onRenderedViewTransformChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
        verticalScrollPosition: fixture.viewModel.verticalScrollPosition,
      );

      final after = fixture.viewModel.hoverIndicatorPosition!.offset;
      expect(after, isNot(equals(before)));
    });

    test('track layout changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(
        _trackIdForRowId(
          fixture.viewModel,
          fixture.viewModel.hoverIndicatorPosition!.rowId,
        ),
        _TrackIds.a,
      );

      fixture.project.trackOrder
        ..clear()
        ..addAll([_TrackIds.b, _TrackIds.a]);
      fixture.viewModel.trackPositionCalculator.invalidate(
        _ArrangerStateMachineTestFixture.editorHeight,
      );
      fixture.controller.onTrackLayoutChanged();

      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(
        _trackIdForRowId(
          fixture.viewModel,
          fixture.viewModel.hoverIndicatorPosition!.rowId,
        ),
        _TrackIds.b,
      );
    });

    test('primary pointer down transitions idle to drag', () {
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
    });

    test('primary pointer up transitions back to idle', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(80, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('non-primary pointer down does not enter drag state', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(
        fixture.stateMachine.data.activePointerButton,
        ArrangerPointerButton.secondary,
      );
      expect(
        fixture.stateMachine.data.activePointerDownContext?.position,
        const Offset(80, 20),
      );
    });

    test('right-click over clip opens context menu and selects clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      var openCount = 0;
      Offset? openedPosition;
      MenuDef? openedMenu;
      ArrangerIdleState.openContextMenuFn = (globalPosition, menu) {
        openCount++;
        openedPosition = globalPosition;
        openedMenu = menu;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(260, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(openCount, 1);
      expect(openedPosition, const Offset(260, 20));
      expect(fixture.viewModel.selectedClips, {_ClipIds.underCursor});

      final openedItems = openedMenu!.children.whereType<AnthemMenuItem>();
      expect(openedItems.first.text, 'Delete');
    });

    test('right-click over selected clip preserves existing selection', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.addAll({
        _ClipIds.underCursor,
        _ClipIds.someOtherSelected,
      });

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(260, 20),
        ),
      );

      expect(openCount, 1);
      expect(fixture.viewModel.selectedClips, {
        _ClipIds.underCursor,
        _ClipIds.someOtherSelected,
      });
    });

    test('right-click on empty space does not open clip context menu', () {
      fixture.viewModel.selectedClips.add(_ClipIds.selected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(420, 20),
        ),
      );

      expect(openCount, 0);
      expect(fixture.viewModel.selectedClips, {_ClipIds.selected});
    });

    test('right-click on resize handle opens context menu for clip', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(240, 10, 16, 30),
        metadata: (id: _ClipIds.underResizeHandle, type: ResizeAreaType.end),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(245, 20),
        ),
      );

      expect(openCount, 1);
      expect(fixture.viewModel.selectedClips, {_ClipIds.underResizeHandle});
    });

    test(
      'context menu delete removes all selected clips and their patterns',
      () {
        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;

        final firstPattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'First',
        );
        final secondPattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Second',
        );
        fixture.project.sequence.patterns[firstPattern.id] = firstPattern;
        fixture.project.sequence.patterns[secondPattern.id] = secondPattern;

        final firstClip = ClipModel(
          idAllocator: _testIdAllocator(),
          patternId: firstPattern.id,
          trackId: _TrackIds.a,
          offset: 100,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        final secondClip = ClipModel(
          idAllocator: _testIdAllocator(),
          patternId: secondPattern.id,
          trackId: _TrackIds.b,
          offset: 220,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        arrangement.clips[firstClip.id] = firstClip;
        arrangement.clips[secondClip.id] = secondClip;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(240, 10, 80, 30),
          metadata: firstClip.id,
        );
        fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

        MenuDef? openedMenu;
        ArrangerIdleState.openContextMenuFn = (_, menu) {
          openedMenu = menu;
        };

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kSecondaryMouseButton,
            position: Offset(260, 20),
          ),
        );

        final deleteItem = openedMenu!.children
            .whereType<AnthemMenuItem>()
            .firstWhere((item) => item.text == 'Delete');
        expect(deleteItem.onSelected, isNotNull);
        deleteItem.onSelected!.call();

        expect(arrangement.clips.containsKey(firstClip.id), isFalse);
        expect(arrangement.clips.containsKey(secondClip.id), isFalse);
        expect(
          fixture.project.sequence.patterns.containsKey(firstPattern.id),
          isFalse,
        );
        expect(
          fixture.project.sequence.patterns.containsKey(secondPattern.id),
          isFalse,
        );
        expect(fixture.viewModel.selectedClips, isEmpty);

        fixture.project.undo();

        expect(arrangement.clips.containsKey(firstClip.id), isTrue);
        expect(arrangement.clips.containsKey(secondClip.id), isTrue);
        expect(
          fixture.project.sequence.patterns.containsKey(firstPattern.id),
          isTrue,
        );
        expect(
          fixture.project.sequence.patterns.containsKey(secondPattern.id),
          isTrue,
        );
      },
    );

    test(
      'context menu delete keeps pattern when another clip still references it',
      () {
        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;

        final sharedPattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Shared',
        );
        fixture.project.sequence.patterns[sharedPattern.id] = sharedPattern;

        final firstClip = ClipModel(
          idAllocator: _testIdAllocator(),
          patternId: sharedPattern.id,
          trackId: _TrackIds.a,
          offset: 100,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        final secondClip = ClipModel(
          idAllocator: _testIdAllocator(),
          patternId: sharedPattern.id,
          trackId: _TrackIds.b,
          offset: 220,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        arrangement.clips[firstClip.id] = firstClip;
        arrangement.clips[secondClip.id] = secondClip;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(240, 10, 80, 30),
          metadata: firstClip.id,
        );
        fixture.viewModel.selectedClips.add(firstClip.id);

        MenuDef? openedMenu;
        ArrangerIdleState.openContextMenuFn = (_, menu) {
          openedMenu = menu;
        };

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kSecondaryMouseButton,
            position: Offset(260, 20),
          ),
        );

        final deleteItem = openedMenu!.children
            .whereType<AnthemMenuItem>()
            .firstWhere((item) => item.text == 'Delete');
        expect(deleteItem.onSelected, isNotNull);
        deleteItem.onSelected!.call();

        expect(arrangement.clips.containsKey(firstClip.id), isFalse);
        expect(arrangement.clips.containsKey(secondClip.id), isTrue);
        expect(
          fixture.project.sequence.patterns.containsKey(sharedPattern.id),
          isTrue,
        );
      },
    );

    test('second click within threshold arms double click on down', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      expect(fixture.idleState.doubleClickPressed, isFalse);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      expect(fixture.idleState.doubleClickPressed, isTrue);
    });

    test('double click flag clears on pointer up', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      expect(fixture.idleState.doubleClickPressed, isTrue);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('large travel prevents double click classification', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(10, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(60, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(60, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(60, 20),
        ),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
    });

    test('pointer cancel clears click tracking', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      expect(fixture.idleState.doubleClickPressed, isTrue);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('single click over empty space clears selected clips', () {
      fixture.viewModel.selectedClips.addAll({_ClipIds.a, _ClipIds.b});

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(280, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(280, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test('single click over non-selected clip selects clicked clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(_ClipIds.selected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {_ClipIds.underCursor});
    });

    test('single click over resize handle selects associated clip', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(240, 10, 16, 30),
        metadata: (id: _ClipIds.underResizeHandle, type: ResizeAreaType.start),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.selected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(255, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(255, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {_ClipIds.underResizeHandle});
    });

    test('double click over clip opens piano roll and sets active pattern', () {
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Pattern 1',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: pattern.id,
        trackId: _TrackIds.a,
        offset: 0,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: clip.id,
      );

      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.detail);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, pattern.id);
      expect(fixture.project.sequence.activeTrackID, _TrackIds.a);
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test('double click over multi-selected clip keeps selection', () {
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Pattern 1',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: pattern.id,
        trackId: _TrackIds.a,
        offset: 0,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: clip.id,
      );
      fixture.viewModel.selectedClips.addAll({
        clip.id,
        _ClipIds.someOtherSelected,
      });

      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.detail);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, pattern.id);
      expect(fixture.project.sequence.activeTrackID, _TrackIds.a);
      expect(fixture.viewModel.selectedClips, {
        clip.id,
        _ClipIds.someOtherSelected,
      });
    });

    test('double click over empty space does not change active editor', () {
      fixture.viewModel.tool = EditorTool.select;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(400, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(400, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(400, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(400, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
      expect(fixture.project.sequence.activePatternID, isNull);
      expect(fixture.project.sequence.activeTrackID, isNull);
    });

    test('ctrl-click over non-selected clip adds it to selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {
        _ClipIds.someOtherSelected,
        _ClipIds.underCursor,
      });
    });

    test('ctrl-click over selected clip removes it from selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: _ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.addAll({
        _ClipIds.underCursor,
        _ClipIds.someOtherSelected,
      });

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {_ClipIds.someOtherSelected});
    });

    test('ctrl-click on empty space clears selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.selectedClips.addAll({_ClipIds.a, _ClipIds.b});

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(420, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test(
      'ctrl-click on resize handle toggles associated clip in selection',
      () {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(240, 10, 16, 30),
          metadata: (
            id: _ClipIds.underResizeHandle,
            type: ResizeAreaType.start,
          ),
        );
        fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(255, 20),
          ),
        );
        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(255, 20)),
        );

        expect(fixture.viewModel.selectedClips, {
          _ClipIds.someOtherSelected,
          _ClipIds.underResizeHandle,
        });

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(245, 20),
          ),
        );
        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(245, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.selectedClips, {_ClipIds.someOtherSelected});
      },
    );
  });

  group('ArrangerDragState', () {
    test('primary down initializes drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.dragState.activePointerId, 1);
      expect(fixture.dragState.dragStartPosition, isNotNull);
      expect(fixture.dragState.dragCurrentPosition, isNotNull);
      expect(fixture.dragState.dragStartPosition!.x, 80);
      expect(fixture.dragState.dragStartPosition!.y, 20);
      expect(fixture.dragState.dragCurrentPosition!.x, 80);
      expect(fixture.dragState.dragCurrentPosition!.y, 20);
      expect(
        fixture.stateMachine.data.activePointerButton,
        ArrangerPointerButton.primary,
      );
      expect(
        fixture.stateMachine.data.activePointerContext?.position,
        const Offset(80, 20),
      );
      expect(
        fixture.dragState.dragStartContext,
        same(fixture.stateMachine.data.activePointerDownContext),
      );
      expect(
        fixture.dragState.dragCurrentContext,
        same(fixture.stateMachine.data.activePointerContext),
      );
      expect(fixture.dragState.dragCurrentContext?.target.isEmpty, isTrue);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });

    test('pointer down over clip sets pressed clip immediately', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: _ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
      expect(fixture.viewModel.pressedClip, _ClipIds.underCursor);
    });

    test(
      'pointer down over resize handle sets pressed clip immediately even without clip hit',
      () {
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(96, 10, 14, 40),
          metadata: (
            id: _ClipIds.underResizeHandle,
            type: ResizeAreaType.start,
          ),
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(100, 20),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
        expect(fixture.viewModel.pressedClip, _ClipIds.underResizeHandle);
      },
    );

    test(
      'pointer up clears pressed clip without crossing activation distance',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(100, 10, 80, 40),
          metadata: _ClipIds.underCursor,
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(120, 20),
          ),
        );
        expect(fixture.viewModel.pressedClip, _ClipIds.underCursor);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(120, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.pressedClip, isNull);
      },
    );

    test(
      'pointer up clears pressed clip from resize-handle press without crossing activation distance',
      () {
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(96, 10, 14, 40),
          metadata: (
            id: _ClipIds.underResizeHandle,
            type: ResizeAreaType.start,
          ),
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(100, 20),
          ),
        );
        expect(fixture.viewModel.pressedClip, _ClipIds.underResizeHandle);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.pressedClip, isNull);
      },
    );

    test('pointer cancel clears pressed clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: _ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );
      expect(fixture.viewModel.pressedClip, _ClipIds.underCursor);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(120, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('select tool down over resize handle does not set pressed clip', () {
      fixture.viewModel.tool = EditorTool.select;
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(96, 10, 14, 40),
        metadata: (id: _ClipIds.underResizeHandle, type: ResizeAreaType.start),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('ctrl-modified down over resize handle does not set pressed clip', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.tool = EditorTool.pencil;
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(96, 10, 14, 40),
        metadata: (id: _ClipIds.underResizeHandle, type: ResizeAreaType.start),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('select tool down over clip does not set pressed clip', () {
      fixture.viewModel.tool = EditorTool.select;
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: _ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('ctrl-modified down over clip does not set pressed clip', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.tool = EditorTool.pencil;
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: _ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test(
      'activation distance remains false below threshold and true above',
      () {
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(80, 20),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(82, 22),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
        expect(
          fixture.stateMachine.data.activePointerContext?.position,
          const Offset(82, 22),
        );
        expect(
          fixture.dragState.dragCurrentContext,
          same(fixture.stateMachine.data.activePointerContext),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(86, 22),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isTrue);
        expect(
          fixture.dragState.dragCurrentContext?.position,
          const Offset(86, 22),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      },
    );

    test('pointer up exits drag and clears drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(90, 22),
        ),
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(90, 22)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.dragState.activePointerId, isNull);
      expect(fixture.dragState.dragStartPosition, isNull);
      expect(fixture.dragState.dragCurrentPosition, isNull);
      expect(fixture.dragState.dragStartContext, isNull);
      expect(fixture.dragState.dragCurrentContext, isNull);
      expect(fixture.stateMachine.data.activePointerButton, isNull);
      expect(fixture.stateMachine.data.activePointerDownContext, isNull);
      expect(fixture.stateMachine.data.activePointerContext, isNull);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });

    test('pointer cancel exits drag and clears drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(90, 22),
        ),
      );

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(90, 22)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.dragState.activePointerId, isNull);
      expect(fixture.dragState.dragStartPosition, isNull);
      expect(fixture.dragState.dragCurrentPosition, isNull);
      expect(fixture.dragState.dragStartContext, isNull);
      expect(fixture.dragState.dragCurrentContext, isNull);
      expect(fixture.stateMachine.data.activePointerButton, isNull);
      expect(fixture.stateMachine.data.activePointerDownContext, isNull);
      expect(fixture.stateMachine.data.activePointerContext, isNull);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });
  });

  group('ArrangerAutomationPointMoveState', () {
    const clipRect = Rect.fromLTWH(100, 0, 240, 60);
    const contentRect = Rect.fromLTWH(100, 16, 240, 44);

    AutomationPointModel makePoint({
      required int offset,
      required double value,
    }) {
      return AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: offset,
        value: value,
      );
    }

    ({ClipModel clip, PatternModel pattern}) addAutomationClip({
      int clipOffset = 100,
      TimeViewModel? timeView,
      List<AutomationPointModel>? points,
    }) {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Automation',
      );
      pattern.automation.points.addAll(
        points ??
            [
              makePoint(offset: 0, value: 0.25),
              makePoint(offset: 240, value: 0.75),
            ],
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: pattern.id,
        trackId: _TrackIds.automationA,
        offset: clipOffset,
        timeView: timeView ?? TimeViewModel(start: 0, end: 240),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      arrangement.clips[clip.id] = clip;

      fixture.viewModel.visibleClips.add(rect: clipRect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    void startAutomationDoubleClickHold(Offset pos) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: pos,
        ),
      );
      fixture.pointerUp(PointerUpEvent(pointer: 1, position: pos));
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: pos,
        ),
      );
    }

    int expectedPointOffsetForClick({
      required ClipModel clip,
      required Offset pos,
      required bool snap,
    }) {
      final rawArrangementTime = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: pos.dx,
      ).round();
      final arrangementTime = snap
          ? getSnappedTime(
              rawTime: rawArrangementTime,
              divisionChanges: fixture.stateMachine.divisionChanges(),
              round: true,
            )
          : rawArrangementTime;
      final clipTimeViewStart = clip.timeView?.start ?? 0;
      final clipTimeViewEnd = clip.timeView?.end ?? clip.width;

      return (arrangementTime - clip.offset + clipTimeViewStart)
          .clamp(clipTimeViewStart, clipTimeViewEnd)
          .toInt();
    }

    double expectedPointValueForClick(Offset pos) {
      return (1 - (pos.dy - contentRect.top) / contentRect.height).clamp(
        0.0,
        1.0,
      );
    }

    double pointCenterX({required ClipModel clip, required int pointOffset}) {
      return timeToPixels(
        time: (clip.offset + pointOffset - (clip.timeView?.start ?? 0))
            .toDouble(),
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
      );
    }

    Offset pointCenter({
      required ClipModel clip,
      required AutomationPointModel point,
    }) {
      return Offset(
        pointCenterX(clip: clip, pointOffset: point.offset),
        contentRect.top + (1 - point.value) * contentRect.height,
      );
    }

    void addHandleAnnotation({
      required ClipModel clip,
      required PatternModel pattern,
      required int pointIndex,
      AutomationHandleKind kind = AutomationHandleKind.point,
      Rect? rect,
    }) {
      final point = pattern.automation.points[pointIndex];
      final center = pointCenter(clip: clip, point: point);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: rect ?? Rect.fromCenter(center: center, width: 16, height: 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: kind,
          pointIndex: pointIndex,
          pointId: point.id,
          center: center,
        ),
      );
    }

    test('double-clicking automation clip content adds a snapped point', () {
      final (:clip, :pattern) = addAutomationClip();
      const clickPos = Offset(147, 38);
      final expectedOffset = expectedPointOffsetForClick(
        clip: clip,
        pos: clickPos,
        snap: true,
      );
      final expectedValue = expectedPointValueForClick(clickPos);
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);
      fixture.viewModel.lastInteractedAutomationTension = 0.35;

      startAutomationDoubleClickHold(clickPos);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, expectedOffset);
      expect(pattern.automation.points[1].value, closeTo(expectedValue, 1e-9));
      expect(pattern.automation.points[1].tension, 0.35);
      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));

      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: clickPos));

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, expectedOffset);

      fixture.project.undo();
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);
    });

    test('alt double-click adds an unsnapped point', () {
      final (:clip, :pattern) = addAutomationClip();
      const clickPos = Offset(147, 38);
      final expectedOffset = expectedPointOffsetForClick(
        clip: clip,
        pos: clickPos,
        snap: false,
      );

      fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
      startAutomationDoubleClickHold(clickPos);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );
      expect(pattern.automation.points[1].offset, expectedOffset);
    });

    test('double-clicking automation clip title does not add a point', () {
      final automationClip = addAutomationClip();
      final pattern = automationClip.pattern;
      const titlePos = Offset(147, 8);

      startAutomationDoubleClickHold(titlePos);

      expect(
        fixture.stateMachine.currentState,
        isNot(isA<ArrangerAutomationPointMoveState>()),
      );
      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: titlePos));
      expect(pattern.automation.points, hasLength(2));
    });

    test('drag after add moves the new point and commits one undo step', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      const clickPos = Offset(147, 38);
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      final movePos = Offset(clickPos.dx + snapSize, clickPos.dy - 11);

      startAutomationDoubleClickHold(clickPos);
      final startOffset = pattern.automation.points[1].offset;
      final startValue = pattern.automation.points[1].value;
      final dragStartX = pointCenterX(
        clip: automationClip.clip,
        pointOffset: startOffset,
      );
      final dragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: dragStartX,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, 240 + dragDelta);

      fixture.pointerUp(PointerUpEvent(pointer: 1, position: movePos));

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(pattern.automation.points[2].offset, 240 + dragDelta);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);

      fixture.project.redo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(pattern.automation.points[2].offset, 240 + dragDelta);
    });

    test('snapped drag after add uses created point center as drag origin', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      const clickPos = Offset(147, 38);

      startAutomationDoubleClickHold(clickPos);
      final startOffset = pattern.automation.points[1].offset;
      final dragStartX = pointCenterX(
        clip: automationClip.clip,
        pointOffset: startOffset,
      );
      expect(dragStartX, isNot(clickPos.dx));
      final movePos = Offset(dragStartX + snapSize / 2, clickPos.dy);
      final centerDragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: dragStartX,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );
      final rawPointerDragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: clickPos.dx,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );
      expect(centerDragDelta, isNot(rawPointerDragDelta));

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        pattern.automation.points[1].offset,
        startOffset + centerDragDelta,
      );
    });

    test('dragging an existing point moves it and later points', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.5),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final clip = automationClip.clip;
      final pattern = automationClip.pattern;
      addHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);

      final point = pattern.automation.points[1];
      final downPos = pointCenter(clip: clip, point: point);
      final startOffset = point.offset;
      final startValue = point.value;
      final laterStartOffset = pattern.automation.points[2].offset;
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      final movePos = Offset(
        downPos.dx + snapSize,
        downPos.dy - contentRect.height * 0.25,
      );
      final dragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: downPos.dx,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );

      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, laterStartOffset + dragDelta);

      fixture.pointerUp(PointerUpEvent(pointer: 1, position: movePos));

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);

      fixture.project.redo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, laterStartOffset + dragDelta);
    });

    test('canceling an existing point drag restores transient edits', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.5),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final clip = automationClip.clip;
      final pattern = automationClip.pattern;
      addHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);

      final point = pattern.automation.points[1];
      final downPos = pointCenter(clip: clip, point: point);
      final startOffset = point.offset;
      final startValue = point.value;
      final laterStartOffset = pattern.automation.points[2].offset;
      final movePos = Offset(downPos.dx + 64, downPos.dy - 11);

      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(pattern.automation.points[1].offset, isNot(startOffset));
      expect(pattern.automation.points[1].value, isNot(startValue));
      expect(pattern.automation.points[2].offset, isNot(laterStartOffset));

      fixture.pointerUp(PointerCancelEvent(pointer: 1, position: movePos));

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);
    });

    test('pointer cancel removes the transient point without undo history', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      const clickPos = Offset(147, 38);

      startAutomationDoubleClickHold(clickPos);
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(210, 28),
        ),
      );
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[2].offset, isNot(240));

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(210, 28)),
      );

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);
    });
  });

  group('ArrangerAutomationTensionChangeState', () {
    const clipRect = Rect.fromLTWH(100, 0, 240, 60);
    const handleCenter = Offset(180, 38);

    AutomationPointModel makePoint({
      required int offset,
      required double value,
      double tension = 0,
    }) {
      return AutomationPointModel(
        idAllocator: _testIdAllocator(),
        offset: offset,
        value: value,
        tension: tension,
      );
    }

    ({ClipModel clip, PatternModel pattern}) addAutomationClip({
      required List<AutomationPointModel> points,
    }) {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Automation',
      );
      pattern.automation.points.addAll(points);
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: pattern.id,
        trackId: _TrackIds.automationA,
        offset: 100,
        timeView: TimeViewModel(start: 0, end: 240),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: clipRect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    void addTensionHandleAnnotation({
      required ClipModel clip,
      required PatternModel pattern,
      required int pointIndex,
    }) {
      final point = pattern.automation.points[pointIndex];
      fixture.viewModel.visibleAutomationHandles.add(
        rect: Rect.fromCenter(center: handleCenter, width: 16, height: 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: pointIndex,
          pointId: point.id,
          center: handleCenter,
        ),
      );
    }

    test('dragging tension handle changes tension and commits undo step', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.75),
          makePoint(offset: 96, value: 0.25, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(point.tension, 0.2);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationTensionChangeState>(),
      );
      expect(point.tension, closeTo(0.7, 1e-9));

      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: movePos));

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(point.tension, closeTo(0.7, 1e-9));
      expect(
        fixture.viewModel.lastInteractedAutomationTension,
        closeTo(0.7, 1e-9),
      );

      fixture.project.undo();
      expect(point.tension, 0.2);

      fixture.project.redo();
      expect(point.tension, closeTo(0.7, 1e-9));
    });

    test('tension drag inverts for rising segments', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.75, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationTensionChangeState>(),
      );
      expect(point.tension, closeTo(-0.3, 1e-9));
    });

    test('canceling tension drag restores transient edit', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.75),
          makePoint(offset: 96, value: 0.25, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
      expect(point.tension, isNot(0.2));

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: movePos),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(point.tension, 0.2);

      fixture.project.undo();
      expect(point.tension, 0.2);
    });
  });

  group('ArrangerCreateClipState', () {
    void startDoubleClickHold({
      Offset firstClickPos = const Offset(100, 20),
      Offset secondClickPos = const Offset(100, 20),
    }) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: firstClickPos,
        ),
      );
      fixture.pointerUp(PointerUpEvent(pointer: 1, position: firstClickPos));
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: secondClickPos,
        ),
      );
    }

    void enterCreateClipState({
      Offset firstClickPos = const Offset(100, 20),
      Offset secondClickPos = const Offset(100, 20),
      Offset movePos = const Offset(180, 20),
    }) {
      startDoubleClickHold(
        firstClickPos: firstClickPos,
        secondClickPos: secondClickPos,
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    test('single-click drag stays in drag state and does not delegate', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(180, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test('double-click hold delegates to create clip state before drag', () {
      startDoubleClickHold();

      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test(
      'double-click hold keeps clip create hint hidden even with time signature changes',
      () {
        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
        arrangement.timeSignatureChanges.add(
          TimeSignatureChangeModel(
            idAllocator: _testIdAllocator(),
            offset: 384,
            timeSignature: TimeSignatureModel(3, 4),
          ),
        );

        const clickPos = Offset(500, 20);
        startDoubleClickHold(firstClickPos: clickPos, secondClickPos: clickPos);

        expect(fixture.viewModel.clipCreateHint, isNull);
      },
    );

    test('double-click drag delegates to create clip state', () {
      enterCreateClipState();

      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNotNull);
    });

    test('clip create hint is anchored to drag start track', () {
      enterCreateClipState(movePos: const Offset(220, 100));

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(_trackIdForRowId(fixture.viewModel, hint!.rowId), _TrackIds.a);
    });

    test('clip create hint can target a phantom automation lane', () {
      fixture.showPhantomAutomationLaneForTrack(_TrackIds.a);

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(220, 80),
      );

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(
        _phantomParentTrackIdForRowId(fixture.viewModel, hint!.rowId),
        _TrackIds.a,
      );
    });

    test('clip create hint can target a real automation lane', () {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(220, 80),
      );

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(
        _trackIdForRowId(fixture.viewModel, hint!.rowId),
        _TrackIds.automationA,
      );
    });

    test('pointer move updates clip create hint end offset', () {
      startDoubleClickHold();
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(420, 20),
        ),
      );

      final firstHint = fixture.viewModel.clipCreateHint!;

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(500, 20),
        ),
      );

      final secondHint = fixture.viewModel.clipCreateHint!;
      expect(secondHint.endOffset, isNot(equals(firstHint.endOffset)));
    });

    test('without drag, pointer up creates auto-sized clip', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      startDoubleClickHold();
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);

      const clickPos = Offset(100, 20);
      final rawStartOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: clickPos.dx,
      );
      final expectedStartOffset = getSnappedTime(
        rawTime: rawStartOffset.round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
        round: true,
      );
      final expectedWidth = getBarLength(
        fixture.project.sequence.ticksPerQuarter,
        fixture.project.sequence.defaultTimeSignature,
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, _TrackIds.a);
      expect(newClip.offset, expectedStartOffset);
      expect(newClip.timeView, isNull);
      expect(newClip.width, expectedWidth);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.detail);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, newClip.patternId);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test(
      'without drag, pointer up creates auto-sized automation lane clip',
      () {
        fixture.showRealAutomationLaneForTrack(_TrackIds.a);

        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        startDoubleClickHold(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final newClip = arrangement.clips.values.last;
        expect(newClip.trackId, _TrackIds.automationA);
        expect(newClip.timeView, isNull);
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);
      },
    );

    test(
      'without drag, pointer up creates a targeted phantom automation lane clip',
      () async {
        final target = fixture.showTargetedPhantomAutomationLaneForTrack(
          _TrackIds.a,
        );
        final parentTrack = fixture.project.tracks[_TrackIds.a]!;

        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        startDoubleClickHold(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(parentTrack.automationLanes, hasLength(1));
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final automationLaneId = parentTrack.automationLanes.single;
        final automationLane = fixture.project.tracks[automationLaneId]!;
        final newClip = arrangement.clips.values.last;
        final pattern = fixture.project.sequence.patterns[newClip.patternId]!;

        expect(automationLane.name, 'Volume');
        expect(automationLane.automationTarget, isNotNull);
        expect(automationLane.automationTarget!.nodeId, target.nodeId);
        expect(automationLane.automationTarget!.portId, target.portId);
        expect(newClip.trackId, automationLaneId);
        expect(newClip.timeView, isNull);
        expect(pattern.name, 'Track - Volume');
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);

        await Future<void>.delayed(Duration.zero);
        fixture.project.undo();

        expect(parentTrack.automationLanes, isEmpty);
        expect(fixture.project.tracks.containsKey(automationLaneId), isFalse);
        expect(fixture.project.sequence.patterns.length, patternCountBefore);
        expect(arrangement.clips.length, clipCountBefore);
      },
    );

    test(
      'double-click hold keeps hint hidden when snap is larger than a bar',
      () {
        fixture.viewModel.timeView.end = 200000;
        fixture.controller.onRenderedViewTransformChanged(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          verticalScrollPosition: fixture.viewModel.verticalScrollPosition,
        );

        final barLength = getBarLength(
          fixture.project.sequence.ticksPerQuarter,
          fixture.project.sequence.defaultTimeSignature,
        );
        final snapSize = fixture.stateMachine
            .divisionChanges()
            .first
            .divisionSnapSize;
        expect(snapSize, greaterThan(barLength));

        startDoubleClickHold();

        expect(fixture.viewModel.clipCreateHint, isNull);
      },
    );

    test('pointer up with non-zero width creates one pattern and one clip', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      enterCreateClipState(movePos: const Offset(420, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      final hint = fixture.viewModel.clipCreateHint!;

      final expectedStart = hint.startOffset < hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedEnd = hint.startOffset > hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedWidth = expectedEnd - expectedStart;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, _trackIdForRowId(fixture.viewModel, hint.rowId));
      expect(newClip.offset, expectedStart.round());
      expect(newClip.timeView, isNotNull);
      expect(newClip.timeView!.start, 0);
      expect(newClip.timeView!.end, expectedWidth.round());
      expect(fixture.projectViewModel.selectedEditor, EditorKind.detail);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, newClip.patternId);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test('pointer up with non-zero width creates automation lane clip', () {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(420, 80),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      final hint = fixture.viewModel.clipCreateHint!;

      final expectedStart = hint.startOffset < hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedEnd = hint.startOffset > hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedWidth = expectedEnd - expectedStart;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, _TrackIds.automationA);
      expect(newClip.offset, expectedStart.round());
      expect(newClip.timeView, isNotNull);
      expect(newClip.timeView!.start, 0);
      expect(newClip.timeView!.end, expectedWidth.round());
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
      expect(fixture.project.sequence.activePatternID, isNull);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test(
      'pointer up with non-zero width creates a targeted phantom automation lane clip',
      () {
        fixture.showTargetedPhantomAutomationLaneForTrack(_TrackIds.a);
        final parentTrack = fixture.project.tracks[_TrackIds.a]!;

        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        enterCreateClipState(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
          movePos: const Offset(420, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        final hint = fixture.viewModel.clipCreateHint!;

        final expectedStart = hint.startOffset < hint.endOffset
            ? hint.startOffset
            : hint.endOffset;
        final expectedEnd = hint.startOffset > hint.endOffset
            ? hint.startOffset
            : hint.endOffset;
        final expectedWidth = expectedEnd - expectedStart;

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(420, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(parentTrack.automationLanes, hasLength(1));
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final automationLaneId = parentTrack.automationLanes.single;
        final newClip = arrangement.clips.values.last;
        expect(newClip.trackId, automationLaneId);
        expect(newClip.offset, expectedStart.round());
        expect(newClip.timeView, isNotNull);
        expect(newClip.timeView!.start, 0);
        expect(newClip.timeView!.end, expectedWidth.round());
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);
      },
    );

    test('pointer up with zero width does not create clip or pattern', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;

      enterCreateClipState(movePos: const Offset(180, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      final hint = fixture.viewModel.clipCreateHint!;
      expect(hint.startOffset, hint.endOffset);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore);
      expect(arrangement.clips.length, clipCountBefore);
    });

    test('leaving create clip state clears clip create hint', () {
      enterCreateClipState(movePos: const Offset(220, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNotNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test(
      'escape cancels create clip and prevents re-entry until pointer release',
      () {
        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;

        enterCreateClipState(movePos: const Offset(420, 20));
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNotNull);

        fixture.pressEscape();

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(500, 20),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(500, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.project.sequence.patterns.length, patternCountBefore);
        expect(arrangement.clips.length, clipCountBefore);
      },
    );
  });

  group('ArrangerClipMoveState', () {
    ClipModel addClip({
      required int offset,
      required Id trackId,
      required Rect rect,
    }) {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: getId(),
        trackId: trackId,
        offset: offset,
        timeView: TimeViewModel(start: 0, end: 96),
      );
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);
      return clip;
    }

    void startClipMove({
      Offset downPos = const Offset(120, 20),
      Offset movePos = const Offset(220, 100),
    }) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    test('pointer up commits clip move and preserves clip track', () {
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      startClipMove();
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      final expectedOffset =
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, expectedOffset);
      expect(clip.trackId, _TrackIds.a);

      fixture.project.undo();

      expect(clip.offset, 100);
      expect(clip.trackId, _TrackIds.a);
    });

    test('dragging automation clip content delegates to clip move', () {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.automationA,
        rect: const Rect.fromLTWH(100, 0, 240, 60),
      );
      fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(140, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, clip.id);
      expect(fixture.viewModel.selectedClips, {_ClipIds.someOtherSelected});

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
      expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
    });

    test('dragging automation tension handle does not move clip', () {
      fixture.showRealAutomationLaneForTrack(_TrackIds.a);
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.automationA,
        rect: const Rect.fromLTWH(100, 0, 240, 60),
      );
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(132, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 0,
          pointId: 900,
          center: const Offset(140, 38),
        ),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(140, 38),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNull);
    });

    test('pressed clip remains set from down through clip move transition', () {
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, clip.id);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 100),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.pressedClip, clip.id);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('moving selected clips is one undoable action', () {
      final firstClip = addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 240,
        trackId: _TrackIds.b,
        rect: const Rect.fromLTWH(260, 70, 80, 40),
      );

      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      startClipMove(movePos: const Offset(260, 100));
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      final firstExpectedOffset =
          fixture.viewModel.clipTimingOverrides[firstClip.id]!.offset;
      final secondExpectedOffset =
          fixture.viewModel.clipTimingOverrides[secondClip.id]!.offset;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 100)),
      );

      expect(firstClip.offset, firstExpectedOffset);
      expect(secondClip.offset, secondExpectedOffset);
      expect(firstClip.trackId, _TrackIds.a);
      expect(secondClip.trackId, _TrackIds.b);

      fixture.project.undo();

      expect(firstClip.offset, 100);
      expect(secondClip.offset, 240);
      expect(firstClip.trackId, _TrackIds.a);
      expect(secondClip.trackId, _TrackIds.b);
    });

    test(
      'snapped move enters at half snap and advances by full snap intervals in both directions',
      () {
        final snapSize = fixture.stateMachine
            .divisionChanges()
            .first
            .divisionSnapSize;
        expect(snapSize, greaterThan(0));
        final halfSnapTrigger = (snapSize + 1) ~/ 2;

        final clip = addClip(
          offset: 300,
          trackId: _TrackIds.a,
          rect: const Rect.fromLTWH(280, 10, 120, 40),
        );

        const downX = 320.0;

        int timeAtX(double x) => pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: x,
        ).round();

        double xForTime(int time) => timeToPixels(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          time: time.toDouble(),
        );

        // Rightward movement
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(downX, 20),
          ),
        );
        final startTimeRight = timeAtX(downX);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeRight + halfSnapTrigger - 1),
              20,
            ),
          ),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
        expect(fixture.viewModel.clipTimingOverrides[clip.id]!.offset, 300);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(xForTime(startTimeRight + halfSnapTrigger), 20),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset,
          300 + snapSize,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeRight + halfSnapTrigger + snapSize),
              20,
            ),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset,
          300 + snapSize * 2,
        );

        fixture.pointerUp(
          const PointerCancelEvent(pointer: 1, position: Offset(0, 0)),
        );

        // Leftward movement
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(downX, 20),
          ),
        );
        final startTimeLeft = timeAtX(downX);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeLeft - (halfSnapTrigger - 1)),
              20,
            ),
          ),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
        expect(fixture.viewModel.clipTimingOverrides[clip.id]!.offset, 300);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(xForTime(startTimeLeft - halfSnapTrigger), 20),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset,
          300 - snapSize,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeLeft - (halfSnapTrigger + snapSize)),
              20,
            ),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset,
          300 - snapSize * 2,
        );
      },
    );

    test('pointer cancel does not commit clip move', () {
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      startClipMove();
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, 100);
      expect(clip.trackId, _TrackIds.a);
      expect(fixture.viewModel.clipTimingOverrides, isEmpty);

      fixture.project.undo();
      expect(clip.offset, 100);
      expect(clip.trackId, _TrackIds.a);
    });
  });

  group('ArrangerClipResizeState', () {
    Id addPattern({int clipAutoWidth = 96}) {
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Pattern',
      );
      pattern.clipAutoWidth = clipAutoWidth;
      fixture.project.sequence.patterns[pattern.id] = pattern;
      return pattern.id;
    }

    ClipModel addClip({
      required int offset,
      required Id trackId,
      required Rect rect,
      required Rect resizeHandleRect,
      required ResizeAreaType resizeAreaType,
      TimeViewModel? timeView,
      int fallbackPatternWidth = 96,
    }) {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = ClipModel(
        idAllocator: _testIdAllocator(),
        patternId: addPattern(clipAutoWidth: fallbackPatternWidth),
        trackId: trackId,
        offset: offset,
        timeView: timeView,
      );
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);
      fixture.viewModel.visibleResizeAreas.add(
        rect: resizeHandleRect,
        metadata: (id: clip.id, type: resizeAreaType),
      );
      return clip;
    }

    void startClipResize({required Offset downPos, required Offset movePos}) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    test('dragging from resize handle delegates to clip resize state', () {
      final clip = addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(96, 10, 14, 40),
        resizeAreaType: ResizeAreaType.start,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(102, 20),
        movePos: const Offset(118, 20),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipResizeState>());
      expect(fixture.viewModel.pressedClip, clip.id);
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
    });

    test(
      'dragging automation clip content resize handle delegates to resize',
      () {
        fixture.showRealAutomationLaneForTrack(_TrackIds.a);
        final clip = addClip(
          offset: 100,
          trackId: _TrackIds.automationA,
          rect: const Rect.fromLTWH(100, 0, 96, 60),
          resizeHandleRect: const Rect.fromLTWH(190, 16, 14, 44),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(192, 38),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.pressedClip, clip.id);
        expect(fixture.viewModel.selectedClips, {_ClipIds.someOtherSelected});

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(220, 38),
          ),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
        expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
      },
    );

    test(
      'dragging automation tension handle over resize handle does not resize',
      () {
        fixture.showRealAutomationLaneForTrack(_TrackIds.a);
        final clip = addClip(
          offset: 100,
          trackId: _TrackIds.automationA,
          rect: const Rect.fromLTWH(100, 0, 96, 60),
          resizeHandleRect: const Rect.fromLTWH(190, 16, 14, 44),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        fixture.viewModel.visibleAutomationHandles.add(
          rect: const Rect.fromLTWH(184, 30, 16, 16),
          metadata: AutomationHandleAnnotation(
            clipId: clip.id,
            kind: AutomationHandleKind.tensionHandle,
            pointIndex: 0,
            pointId: 900,
            center: const Offset(192, 38),
          ),
        );

        startClipResize(
          downPos: const Offset(192, 38),
          movePos: const Offset(220, 38),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipTimingOverrides[clip.id], isNull);
      },
    );

    test('clip resize overrides the global cursor until release', () {
      addClip(
        offset: 100,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(196, 10, 14, 40),
        resizeAreaType: ResizeAreaType.end,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(202, 20),
        movePos: const Offset(220, 20),
      );

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        SystemMouseCursors.resizeLeftRight,
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 20)),
      );

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        MouseCursor.defer,
      );
    });

    test(
      'start resize creates time view for clip without time view and commits via undoable command',
      () {
        final clip = addClip(
          offset: 80,
          trackId: _TrackIds.a,
          rect: const Rect.fromLTWH(80, 10, 64, 40),
          resizeHandleRect: const Rect.fromLTWH(76, 10, 14, 40),
          resizeAreaType: ResizeAreaType.start,
          timeView: null,
          fallbackPatternWidth: 64,
        );

        fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
        startClipResize(
          downPos: const Offset(82, 20),
          movePos: const Offset(92, 20),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        final inProgressOverride =
            fixture.viewModel.clipTimingOverrides[clip.id]!;
        expect(inProgressOverride.offset, equals(90));
        expect(inProgressOverride.timeViewStart, equals(10));
        expect(inProgressOverride.timeViewEnd, equals(64));

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(92, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(clip.offset, equals(90));
        expect(clip.timeView, isNotNull);
        expect(clip.timeView!.start, equals(10));
        expect(clip.timeView!.end, equals(64));

        fixture.project.undo();

        expect(clip.offset, equals(80));
        expect(clip.timeView, isNull);
      },
    );

    test(
      'end resize on selected clips snaps and blocks next snap when it would make a clip non-positive',
      () {
        final snapSize = fixture.stateMachine
            .divisionChanges()
            .first
            .divisionSnapSize;
        final largeClip = addClip(
          offset: 100,
          trackId: _TrackIds.a,
          rect: const Rect.fromLTWH(100, 10, 100, 40),
          resizeHandleRect: const Rect.fromLTWH(194, 10, 14, 40),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 100),
        );
        final smallClipWidth = snapSize + 2;
        final smallClip = addClip(
          offset: 260,
          trackId: _TrackIds.b,
          rect: Rect.fromLTWH(260, 70, smallClipWidth.toDouble(), 40),
          resizeHandleRect: Rect.fromLTWH(
            260 + smallClipWidth.toDouble() - 6,
            70,
            14,
            40,
          ),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: smallClipWidth),
        );

        fixture.viewModel.selectedClips.addAll({largeClip.id, smallClip.id});

        startClipResize(
          downPos: const Offset(198, 20),
          movePos: Offset(198 - (snapSize * 3).toDouble(), 20),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        final largeOverride =
            fixture.viewModel.clipTimingOverrides[largeClip.id]!;
        final smallOverride =
            fixture.viewModel.clipTimingOverrides[smallClip.id]!;
        final largeWidth =
            largeOverride.timeViewEnd - largeOverride.timeViewStart;
        final smallWidth =
            smallOverride.timeViewEnd - smallOverride.timeViewStart;

        expect(smallWidth, equals(2));
        expect(largeWidth, equals(100 - snapSize));

        fixture.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(198 - (snapSize * 3).toDouble(), 20),
          ),
        );

        expect(
          largeClip.timeView!.end - largeClip.timeView!.start,
          equals(100 - snapSize),
        );
        expect(smallClip.timeView!.end - smallClip.timeView!.start, equals(2));

        fixture.project.undo();
        expect(
          largeClip.timeView!.end - largeClip.timeView!.start,
          equals(100),
        );
        expect(
          smallClip.timeView!.end - smallClip.timeView!.start,
          equals(smallClipWidth),
        );
      },
    );

    test(
      'snapped end resize enters at half snap and advances by full snap intervals in both directions',
      () {
        final snapSize = fixture.stateMachine
            .divisionChanges()
            .first
            .divisionSnapSize;
        expect(snapSize, greaterThan(0));
        final halfSnapTrigger = (snapSize + 1) ~/ 2;

        final clip = addClip(
          offset: 120,
          trackId: _TrackIds.a,
          rect: const Rect.fromLTWH(120, 10, 240, 40),
          resizeHandleRect: const Rect.fromLTWH(354, 10, 14, 40),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 240),
        );

        const downX = 358.0;

        int timeAtX(double x) => pixelsToTime(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: x,
        ).round();

        double xForTime(int time) => timeToPixels(
          timeViewStart: fixture.viewModel.timeView.start,
          timeViewEnd: fixture.viewModel.timeView.end,
          viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
          time: time.toDouble(),
        );

        // Rightward resize
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(downX, 20),
          ),
        );
        final startTimeRight = timeAtX(downX);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeRight + halfSnapTrigger - 1),
              20,
            ),
          ),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(xForTime(startTimeRight + halfSnapTrigger), 20),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240 + snapSize,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeRight + halfSnapTrigger + snapSize),
              20,
            ),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240 + snapSize * 2,
        );

        fixture.pointerUp(
          const PointerCancelEvent(pointer: 1, position: Offset(0, 0)),
        );

        // Leftward resize
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(downX, 20),
          ),
        );
        final startTimeLeft = timeAtX(downX);

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeLeft - (halfSnapTrigger - 1)),
              20,
            ),
          ),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(xForTime(startTimeLeft - halfSnapTrigger), 20),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240 - snapSize,
        );

        fixture.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(
              xForTime(startTimeLeft - (halfSnapTrigger + snapSize)),
              20,
            ),
          ),
        );
        expect(
          fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
              fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
          240 - snapSize * 2,
        );
      },
    );

    test('pointer cancel does not commit clip resize', () {
      final clip = addClip(
        offset: 120,
        trackId: _TrackIds.a,
        rect: const Rect.fromLTWH(120, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(210, 10, 14, 40),
        resizeAreaType: ResizeAreaType.end,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(214, 20),
        movePos: const Offset(180, 20),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipResizeState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(180, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, equals(120));
      expect(clip.timeView!.start, equals(0));
      expect(clip.timeView!.end, equals(96));
      expect(fixture.viewModel.clipTimingOverrides, isEmpty);
    });
  });

  group('ArrangerSelectionBoxState', () {
    void enterSelectionBoxState({
      Offset downPos = const Offset(100, 30),
      Offset movePos = const Offset(160, 80),
      bool useCtrlModifier = false,
      bool useShiftModifier = false,
      bool useSelectTool = true,
    }) {
      fixture.viewModel.tool = useSelectTool
          ? EditorTool.select
          : EditorTool.pencil;

      if (useCtrlModifier) {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      }
      if (useShiftModifier) {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.shift);
      }

      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    void addVisibleClip({required Id id, required Rect rect}) {
      fixture.viewModel.visibleClips.add(rect: rect, metadata: id);
    }

    test('select tool drag delegates to selection box state', () {
      enterSelectionBoxState(useSelectTool: true);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('ctrl drag with pencil tool delegates to selection box state', () {
      enterSelectionBoxState(useCtrlModifier: true, useSelectTool: false);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('selection box uses raw view-space pointer coordinates', () {
      const downPos = Offset(100, 30);
      const movePos = Offset(160, 80);
      enterSelectionBoxState(downPos: downPos, movePos: movePos);

      final selectionBox = fixture.viewModel.selectionBox;
      expect(selectionBox, isNotNull);
      expect(selectionBox!.left, equals(downPos.dx));
      expect(selectionBox.top, equals(downPos.dy));
      expect(selectionBox.width, equals(movePos.dx - downPos.dx));
      expect(selectionBox.height, equals(movePos.dy - downPos.dy));
    });

    test('selection box is normalized for reverse drags', () {
      const downPos = Offset(150, 90);
      const movePos = Offset(100, 30);
      enterSelectionBoxState(downPos: downPos, movePos: movePos);

      final selectionBox = fixture.viewModel.selectionBox;
      expect(selectionBox, isNotNull);
      expect(selectionBox!.left, equals(movePos.dx));
      expect(selectionBox.top, equals(movePos.dy));
      expect(selectionBox.width, equals(downPos.dx - movePos.dx));
      expect(selectionBox.height, equals(downPos.dy - movePos.dy));
    });

    test('pointer up clears selection box', () {
      enterSelectionBoxState();
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(160, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test('pointer cancel clears selection box', () {
      enterSelectionBoxState();
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(160, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test(
      'releasing ctrl does not exit selection box while pointer is down',
      () {
        enterSelectionBoxState(useCtrlModifier: true, useSelectTool: false);
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.viewModel.selectionBox, isNotNull);

        fixture.stateMachine.modifierReleased(ArrangerModifierKey.ctrl);

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.viewModel.selectionBox, isNotNull);
      },
    );

    test('escape exits selection box and clears it', () {
      enterSelectionBoxState();
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pressEscape();

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test('escape prevents selection box re-entry until pointer release', () {
      enterSelectionBoxState();
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );

      fixture.pressEscape();
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 140),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 140)),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 30),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(180, 110),
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('view transform updates do not remap selection box coordinates', () {
      enterSelectionBoxState();
      final before = fixture.viewModel.selectionBox!;

      fixture.controller.onRenderedViewTransformChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
        verticalScrollPosition: 48,
      );

      final after = fixture.viewModel.selectionBox!;
      expect(after.left, equals(before.left));
      expect(after.top, equals(before.top));
      expect(after.width, equals(before.width));
      expect(after.height, equals(before.height));
    });

    test(
      'starting drag over selected clip does not latch subtractive mode without shift',
      () {
        const downPos = Offset(100, 30);
        const clipId = _ClipIds.selected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(clipId);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
      },
    );

    test(
      'starting drag over selected clip latches subtractive selection mode with shift',
      () {
        const downPos = Offset(100, 30);
        const clipId = _ClipIds.selected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(clipId);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
          useShiftModifier: true,
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isTrue);
      },
    );

    test(
      'starting drag over non-selected clip does not latch subtractive mode',
      () {
        const downPos = Offset(100, 30);
        const clipId = _ClipIds.notSelected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(_ClipIds.someOtherSelected);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
          useShiftModifier: true,
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
      },
    );

    test('starting drag over empty space does not latch subtractive mode', () {
      fixture.viewModel.selectedClips.add(_ClipIds.selected);

      enterSelectionBoxState(
        downPos: const Offset(100, 30),
        movePos: const Offset(160, 80),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isFalse);
    });

    test(
      'without shift selection box starts with an empty selection snapshot',
      () {
        fixture.viewModel.selectedClips.addAll([_ClipIds.a, _ClipIds.b]);

        enterSelectionBoxState();

        expect(fixture.selectionBoxState.originalSelectedClipsAtEntry, isEmpty);
        expect(fixture.viewModel.selectedClips, isEmpty);

        fixture.viewModel.selectedClips.add(_ClipIds.c);

        expect(fixture.selectionBoxState.originalSelectedClipsAtEntry, isEmpty);

        expect(
          () => fixture.selectionBoxState.originalSelectedClipsAtEntry!.add(
            _ClipIds.d,
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'with shift selection box snapshots existing selection and keeps it stable',
      () {
        fixture.viewModel.selectedClips.addAll([_ClipIds.a, _ClipIds.b]);

        enterSelectionBoxState(useShiftModifier: true);

        expect(
          fixture.selectionBoxState.originalSelectedClipsAtEntry,
          equals({_ClipIds.a, _ClipIds.b}),
        );

        fixture.viewModel.selectedClips
          ..remove(_ClipIds.a)
          ..add(_ClipIds.c);

        expect(
          fixture.selectionBoxState.originalSelectedClipsAtEntry,
          equals({_ClipIds.a, _ClipIds.b}),
        );

        expect(
          () => fixture.selectionBoxState.originalSelectedClipsAtEntry!.add(
            _ClipIds.d,
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'without shift selection box clears existing selection and selects clips in box',
      () {
        addVisibleClip(
          id: _ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(_ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
        );

        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));
      },
    );

    test('with shift additive mode selects clips under selection box', () {
      addVisibleClip(id: _ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(_ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
        useShiftModifier: true,
      );

      expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isFalse);
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({_ClipIds.a, _ClipIds.b}),
      );
    });

    test(
      'without shift drag over selected clip is additive from an empty snapshot',
      () {
        addVisibleClip(
          id: _ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 30, 30),
        );
        fixture.viewModel.selectedClips.addAll({_ClipIds.a, _ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(80, 80),
        );

        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.a}));
      },
    );

    test(
      'with shift subtractive mode deselects selected clips under selection box',
      () {
        addVisibleClip(
          id: _ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 30, 30),
        );
        fixture.viewModel.selectedClips.addAll({_ClipIds.a, _ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(80, 80),
          useShiftModifier: true,
        );

        expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isTrue);
        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));
      },
    );

    test(
      'without shift additive mode reverts to empty selection when box shrinks',
      () {
        addVisibleClip(
          id: _ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(_ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(10, 10),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), isEmpty);
      },
    );

    test(
      'with shift additive mode reverts clip to original selection when box shrinks',
      () {
        addVisibleClip(
          id: _ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(_ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
          useShiftModifier: true,
        );
        expect(
          fixture.viewModel.selectedClips.toSet(),
          equals({_ClipIds.a, _ClipIds.b}),
        );

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(10, 10),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.a}));
      },
    );

    test(
      'with shift subtractive mode reverts clip to original selection when box shrinks',
      () {
        addVisibleClip(
          id: _ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 20, 20),
        );
        addVisibleClip(
          id: _ClipIds.b,
          rect: const Rect.fromLTWH(90, 20, 20, 20),
        );
        fixture.viewModel.selectedClips.addAll({_ClipIds.a, _ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(130, 60),
          useShiftModifier: true,
        );
        expect(fixture.viewModel.selectedClips.toSet(), isEmpty);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(60, 60),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));
      },
    );

    test('without shift cancel restores selected clips to empty snapshot', () {
      addVisibleClip(id: _ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(_ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
      );
      expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));

      fixture.pressEscape();

      expect(fixture.viewModel.selectedClips.toSet(), isEmpty);
    });

    test('with shift cancel restores selected clips to selection snapshot', () {
      addVisibleClip(id: _ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(_ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
        useShiftModifier: true,
      );
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({_ClipIds.a, _ClipIds.b}),
      );

      fixture.pressEscape();

      expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.a}));
    });

    test('pointer up keeps selection result from selection box', () {
      addVisibleClip(id: _ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
      );
      expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(80, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips.toSet(), equals({_ClipIds.b}));
    });

    test('clears selection session data when selection box exits', () {
      fixture.viewModel.selectedClips.add(_ClipIds.a);
      enterSelectionBoxState();

      expect(fixture.selectionBoxState.originalSelectedClipsAtEntry, isEmpty);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(160, 80)),
      );

      expect(fixture.selectionBoxState.originalSelectedClipsAtEntry, isNull);
      expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isFalse);
    });

    test(
      'clears selection session data when selection box is canceled with shift',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: _ClipIds.a,
        );
        fixture.viewModel.selectedClips.add(_ClipIds.a);
        enterSelectionBoxState(useShiftModifier: true);

        expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isTrue);
        expect(
          fixture.selectionBoxState.originalSelectedClipsAtEntry,
          equals({_ClipIds.a}),
        );

        fixture.pressEscape();

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.selectionBoxState.originalSelectedClipsAtEntry, isNull);
        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
      },
    );
  });
}
