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
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/parameter_config.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/menu/menu_model.dart';
import 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/test_project.dart';

export 'package:anthem/helpers/id.dart';
export 'package:anthem/helpers/project_entity_id_allocator.dart';
export 'package:anthem/logic/project_controller.dart';
export 'package:anthem/logic/service_registry.dart';
export 'package:anthem/model/arrangement/clip.dart';
export 'package:anthem/model/pattern/automation_point.dart';
export 'package:anthem/model/pattern/pattern.dart';
export 'package:anthem/model/project.dart';
export 'package:anthem/model/sequencer.dart';
export 'package:anthem/model/shared/anthem_color.dart';
export 'package:anthem/model/store.dart';
export 'package:anthem/model/track.dart';
export 'package:anthem/widgets/basic/menu/menu_model.dart';
export 'package:anthem/widgets/editors/arranger/automation_handle_annotation.dart';
export 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
export 'package:anthem/widgets/editors/arranger/controller/state_machine/arranger_state_machine.dart';
export 'package:anthem/widgets/editors/arranger/view_model.dart';
export 'package:anthem/widgets/editors/shared/helpers/snap_delta.dart';
export 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
export 'package:anthem/widgets/editors/shared/helpers/types.dart';
export 'package:anthem/widgets/project/project_view_model.dart';
export 'package:anthem_codegen/include.dart';
export 'package:flutter/gestures.dart';
export 'package:flutter/services.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_test/flutter_test.dart';
export '../../../../../helpers/test_project.dart' show testIdAllocator;

class TrackIds {
  static const a = 1;
  static const b = 2;
  static const master = 3;
  static const automationA = 4;
}

class ClipIds {
  static const underCursor = 101;
  static const underResizeHandle = 102;
  static const selected = 103;
  static const notSelected = 104;
  static const someOtherSelected = 105;
  static const a = 106;
  static const b = 107;
}

Id? trackIdForRowId(ArrangerViewModel viewModel, Id? rowId) {
  if (rowId == null) {
    return null;
  }

  return switch (viewModel.trackLayout.tryRowLayoutForId(rowId)?.row) {
    ProjectTrackRow(:final trackId) => trackId,
    PhantomAutomationTrackRow() || null => null,
  };
}

Id? phantomParentTrackIdForRowId(ArrangerViewModel viewModel, Id? rowId) {
  if (rowId == null) {
    return null;
  }

  return switch (viewModel.trackLayout.tryRowLayoutForId(rowId)?.row) {
    PhantomAutomationTrackRow(:final phantomLane) => phantomLane.parentTrackId,
    ProjectTrackRow() || null => null,
  };
}

void expectAutomationHandle(
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

TrackModel makeTrack(Id id, String name, TrackType type) {
  return makeTestTrack(id, name, type);
}

class ArrangerStateMachineTestFixture {
  static const viewSize = Size(960, 240);
  static const editorHeight = 240.0;

  final ProjectModel project;
  final ArrangerViewModel viewModel;
  final ProjectViewModel projectViewModel;
  final ProjectController projectController;
  final ArrangerController controller;

  ArrangerStateMachineTestFixture._({
    required this.project,
    required this.viewModel,
    required this.projectViewModel,
    required this.projectController,
    required this.controller,
  });

  factory ArrangerStateMachineTestFixture.create() {
    final project = createTestProject(
      tracks: const [
        TestProjectTrack(id: TrackIds.a, name: 'A'),
        TestProjectTrack(id: TrackIds.b, name: 'B'),
        TestProjectTrack(
          id: TrackIds.master,
          name: 'Master',
          isMasterTrack: true,
        ),
      ],
      trackOrder: const [TrackIds.a, TrackIds.b],
      sendTrackOrder: const [TrackIds.master],
    );

    final viewModel = ArrangerViewModel(
      project: project,
      baseTrackHeight: 60,
      timeRange: TimeRange(0, 960),
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
    viewModel.refreshTrackLayout(editorHeight);

    return ArrangerStateMachineTestFixture._(
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
    viewModel.refreshTrackLayout(editorHeight);
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
    _ensureAutomationTargetNode(target);
    showPhantomAutomationLaneForTrack(trackId);

    return target;
  }

  void _ensureAutomationTargetNode(AutomationParameterTarget target) {
    if (project.processingGraph.nodes[target.nodeId] != null) {
      return;
    }

    project.processingGraph.addNode(
      NodeModel(
        id: target.nodeId,
        owner: NodeOwnerModel(trackId: target.ownerTrackId),
        controlInputPorts: AnthemObservableList.of([
          NodePortModel(
            nodeId: target.nodeId,
            id: target.portId,
            config: NodePortConfigModel(
              dataType: NodePortDataType.control,
              name: target.parameterName,
              parameterConfig: ParameterConfigModel(
                id: target.portId,
                defaultValue: 0.5,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void showRealAutomationLaneForTrack(Id trackId) {
    final parentTrack = project.tracks[trackId]!;
    final automationLane = makeTrack(
      TrackIds.automationA,
      'A Automation',
      TrackType.automationLane,
    )..automationLaneParentTrackId = parentTrack.id;

    project.tracks[automationLane.id] = automationLane;
    parentTrack.automationLanes.add(automationLane.id);
    viewModel.registerTrack(automationLane.id);
    viewModel.automationExpandedByTrackId[trackId] = true;
    viewModel.refreshTrackLayout(editorHeight);
    controller.onTrackLayoutChanged();
  }

  void dispose() {
    controller.dispose();
    ServiceRegistry.mainWindowController.clearAllCursorOverrides();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}

void setUpArrangerStateMachineTestFixture(
  void Function(ArrangerStateMachineTestFixture fixture) setFixture,
) {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ArrangerStateMachineTestFixture fixture;
  late void Function(Offset globalPosition, MenuDef menu)
  defaultOpenContextMenuFn;
  setUp(() {
    defaultOpenContextMenuFn = ArrangerIdleState.openContextMenuFn;
    fixture = ArrangerStateMachineTestFixture.create();
    setFixture(fixture);
  });
  tearDown(() {
    ArrangerIdleState.openContextMenuFn = defaultOpenContextMenuFn;
    fixture.dispose();
  });
}
