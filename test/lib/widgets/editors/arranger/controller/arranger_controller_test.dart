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
import 'package:anthem/logic/commands/device_commands.dart';
import 'package:anthem/logic/commands/track_commands.dart';
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/track_controller.dart';
import 'package:anthem/model/device.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/processing_graph/node.dart';
import 'package:anthem/model/processing_graph/node_port.dart';
import 'package:anthem/model/processing_graph/node_port_config.dart';
import 'package:anthem/model/processing_graph/processing_graph.dart';
import 'package:anthem/model/processing_graph/processors/sequence_automation_provider.dart';
import 'package:anthem/model/processing_graph/processors/tone_generator.dart';
import 'package:anthem/model/processing_graph/processors/utility.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/helpers.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockProjectController extends Mock implements ProjectController {
  @override
  void openPatternInPianoRoll(Id patternID) {
    super.noSuchMethod(Invocation.method(#openPatternInPianoRoll, [patternID]));
  }

  @override
  Future<void> publishProcessingGraph() => Future<void>.value();
}

class MockTrackController extends Mock implements TrackController {
  @override
  Iterable<(Id trackId, bool isSendTrack, int trackDepth)> getTracksIterable({
    bool includeCollapsedTracks = false,
  }) {
    return super.noSuchMethod(
          Invocation.method(#getTracksIterable, [], {
            #includeCollapsedTracks: includeCollapsedTracks,
          }),
          returnValue: const <(Id, bool, int)>[],
        )
        as Iterable<(Id, bool, int)>;
  }

  @override
  ({Set<Id> deletedClipIds, Set<Id> deletedPatternIds}) deleteClips({
    required Id arrangementId,
    required Iterable<Id> clipIds,
  }) {
    return super.noSuchMethod(
          Invocation.method(#deleteClips, [], {
            #arrangementId: arrangementId,
            #clipIds: clipIds,
          }),
          returnValue: (deletedClipIds: <Id>{}, deletedPatternIds: <Id>{}),
        )
        as ({Set<Id> deletedClipIds, Set<Id> deletedPatternIds});
  }

  @override
  void setActiveTrack(Id? id) {
    super.noSuchMethod(Invocation.method(#setActiveTrack, [id]));
  }
}

class _TrackIds {
  static const a = 1;
  static const a1 = 2;
  static const a2 = 3;
  static const a2a = 4;
  static const b = 5;

  static const s = 6;
  static const s1 = 7;
  static const master = 8;
}

TrackModel _makeTrack(Id id, String name, TrackType type) {
  return TrackModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    name: name,
    color: AnthemColor.randomHue(),
    type: type,
  );
}

Iterable<(Id trackId, bool isSendTrack, int trackDepth)> _getTracksIterable(
  ProjectModel project,
  ArrangerViewModel viewModel, {
  required bool includeCollapsedTracks,
}) sync* {
  final topLevelTracks = project.trackOrder
      .map((trackId) => (trackId, false))
      .followedBy(project.sendTrackOrder.map((trackId) => (trackId, true)));

  Iterable<(Id, bool, int)> yieldChildren(
    Id trackId,
    bool isSendTrack,
    int currentDepth,
  ) sync* {
    yield (trackId, isSendTrack, currentDepth);

    final track = project.tracks[trackId]!;
    if (!track.isAutomationLane &&
        (includeCollapsedTracks ||
            (viewModel.automationExpandedByTrackId[trackId] ?? false))) {
      for (final automationLaneId in track.automationLanes) {
        yield (automationLaneId, isSendTrack, currentDepth + 1);
      }
    }

    for (final childTrackId in track.childTracks) {
      yield* yieldChildren(childTrackId, isSendTrack, currentDepth + 1);
    }
  }

  for (final topLevelTrack in topLevelTracks) {
    yield* yieldChildren(topLevelTrack.$1, topLevelTrack.$2, 0);
  }
}

class _ArrangerControllerTestFixture {
  final ProjectModel project;
  final ArrangerViewModel viewModel;
  final ArrangerController controller;
  final MockProjectController mockProjectController;
  final MockTrackController mockTrackController;

  _ArrangerControllerTestFixture._({
    required this.project,
    required this.viewModel,
    required this.controller,
    required this.mockProjectController,
    required this.mockTrackController,
  });

  factory _ArrangerControllerTestFixture.create() {
    final project = ProjectModel();
    project.isHydrated = true;
    project.idCounter = 1000;
    project.sequence = SequencerModel(
      idAllocator: ProjectEntityIdAllocator.test(getId),
    );
    project.processingGraph = ProcessingGraphModel.create(
      masterOutputNodeId: project.idAllocator.allocateId(),
    );

    final tracks = <Id, TrackModel>{
      _TrackIds.a: _makeTrack(_TrackIds.a, 'A', TrackType.group),
      _TrackIds.a1: _makeTrack(_TrackIds.a1, 'A1', TrackType.normal),
      _TrackIds.a2: _makeTrack(_TrackIds.a2, 'A2', TrackType.group),
      _TrackIds.a2a: _makeTrack(_TrackIds.a2a, 'A2a', TrackType.normal),
      _TrackIds.b: _makeTrack(_TrackIds.b, 'B', TrackType.normal),
      _TrackIds.s: _makeTrack(_TrackIds.s, 'S', TrackType.group),
      _TrackIds.s1: _makeTrack(_TrackIds.s1, 'S1', TrackType.normal),
      _TrackIds.master: _makeTrack(
        _TrackIds.master,
        'Master',
        TrackType.normal,
      ),
    };

    tracks[_TrackIds.a]!.childTracks.addAll([_TrackIds.a1, _TrackIds.a2]);
    tracks[_TrackIds.a2]!.childTracks.add(_TrackIds.a2a);
    tracks[_TrackIds.s]!.childTracks.add(_TrackIds.s1);

    for (final track in tracks.values) {
      for (final childId in track.childTracks) {
        tracks[childId]!.parentTrackId = track.id;
      }
    }

    project.tracks = AnthemObservableMap.of(tracks);
    project.trackOrder = AnthemObservableList.of([_TrackIds.a, _TrackIds.b]);
    project.sendTrackOrder = AnthemObservableList.of([
      _TrackIds.s,
      _TrackIds.master,
    ]);
    final viewModel = ArrangerViewModel(
      project: project,
      baseTrackHeight: 60,
      timeRange: TimeRange(0, 960),
    );

    AnthemStore.instance.projects[project.id] = project;
    final mockProjectController = MockProjectController();
    final mockTrackController = MockTrackController();
    when(mockTrackController.getTracksIterable()).thenAnswer(
      (_) =>
          _getTracksIterable(project, viewModel, includeCollapsedTracks: false),
    );
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides([
        overrideService(
          projectControllerService,
          (_, _) => mockProjectController,
        ),
        overrideService(arrangerViewModelService, (_, _) => viewModel),
        overrideService(trackControllerService, (_, _) => mockTrackController),
      ]),
    );
    final controller = ArrangerController(
      viewModel: viewModel,
      project: project,
    );

    return _ArrangerControllerTestFixture._(
      project: project,
      viewModel: viewModel,
      controller: controller,
      mockProjectController: mockProjectController,
      mockTrackController: mockTrackController,
    );
  }

  void expectSelectedTracks(Iterable<Id> expected) {
    expect(viewModel.selectedTracks.toSet(), equals(expected.toSet()));
  }

  void dispose() {
    controller.dispose();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ArrangerControllerTestFixture fixture;

  setUp(() {
    fixture = _ArrangerControllerTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('setBaseTrackHeight', () {
    test(
      'recalculates scroll extent and clamps vertical scroll immediately',
      () {
        const editorHeight = 300.0;

        fixture.viewModel.refreshTrackLayout(editorHeight);
        expect(fixture.viewModel.maxVerticalScrollPosition, greaterThan(0));

        fixture.viewModel.verticalScrollPosition = 100;
        fixture.viewModel.refreshTrackLayout(editorHeight);

        fixture.controller.setBaseTrackHeight(0, minTrackHeight);

        expect(fixture.viewModel.maxVerticalScrollPosition, 0);
        expect(fixture.viewModel.verticalScrollPosition, 0);
        expect(
          fixture.viewModel.trackPositionCalculator.getTrackPosition(0),
          0,
        );
      },
    );
  });

  group('automation target resolution', () {
    test('uses node owner metadata for track and device parameters', () {
      fixture.dispose();

      final project = ProjectModel.create();
      final viewModel = ArrangerViewModel(
        project: project,
        baseTrackHeight: 60,
        timeRange: TimeRange(0, 960),
      );
      final mockProjectController = MockProjectController();

      AnthemStore.instance.projects[project.id] = project;
      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(
            projectControllerService,
            (_, _) => mockProjectController,
          ),
          overrideService(arrangerViewModelService, (_, _) => viewModel),
        ]),
      );

      try {
        ServiceRegistry.forProject(project.id).arrangerController;
        final track = project.tracks[project.trackOrder.first]!;
        final utilityNode = track.requireProcessing.utilityNode!;
        final utilityPort = utilityNode.getPortById(
          UtilityProcessorModel.gainPortId,
        );

        utilityPort.parameterValue = 0.42;

        var target = viewModel.lastTweakedAutomationTarget;
        expect(target, isNotNull);
        expect(target!.ownerTrackId, equals(track.id));
        expect(target.nodeId, equals(utilityNode.id));
        expect(target.portId, equals(UtilityProcessorModel.gainPortId));
        expect(target.ownerName, equals('Track'));
        expect(target.parameterName, equals('Volume'));
        expect(target.title, equals('Track Volume'));

        DeviceAddRemoveCommand.add(
          project: project,
          trackId: track.id,
          device: DeviceDescriptorForCommand(type: DeviceType.toneGenerator),
        ).execute(project);

        final device = track.requireProcessing.devices.single;
        final deviceNode =
            project.processingGraph.nodes[device.nodeIds.single]!;
        final frequencyPort = deviceNode.getPortById(
          ToneGeneratorProcessorModel.frequencyPortId,
        );

        frequencyPort.parameterValue = 0.56;

        target = viewModel.lastTweakedAutomationTarget;
        expect(target, isNotNull);
        expect(target!.ownerTrackId, equals(track.id));
        expect(target.nodeId, equals(deviceNode.id));
        expect(
          target.portId,
          equals(ToneGeneratorProcessorModel.frequencyPortId),
        );
        expect(target.ownerName, equals('Tone Generator'));
        expect(
          target.parameterName,
          equals('Parameter ${ToneGeneratorProcessorModel.frequencyPortId}'),
        );
        expect(
          target.title,
          equals(
            'Tone Generator '
            'Parameter ${ToneGeneratorProcessorModel.frequencyPortId}',
          ),
        );
      } finally {
        ServiceRegistry.removeProject(project.id);
        AnthemStore.instance.projects.remove(project.id);
        project.dispose();
      }
    });

    test(
      'createAutomationLaneForTarget stores parameter name as lane name',
      () {
        const target = AutomationParameterTarget(
          ownerTrackId: _TrackIds.a,
          nodeId: 123,
          portId: 456,
          ownerName: 'Filter',
          parameterName: 'Cutoff',
        );

        fixture.controller.createAutomationLaneForTarget(target);

        final parentTrack = fixture.project.tracks[_TrackIds.a]!;
        expect(parentTrack.automationLanes, hasLength(1));

        final lane =
            fixture.project.tracks[parentTrack.automationLanes.single]!;
        expect(lane.name, equals('Cutoff'));
        expect(lane.automationTarget, isNotNull);
        expect(lane.automationTarget!.nodeId, equals(target.nodeId));
        expect(lane.automationTarget!.portId, equals(target.portId));
        expect(
          fixture.viewModel.automationExpandedByTrackId[target.ownerTrackId],
          isTrue,
        );
      },
    );

    test('parameter changes update last tweaked automation target', () {
      fixture.dispose();

      final project = ProjectModel.create();
      final viewModel = ArrangerViewModel(
        project: project,
        baseTrackHeight: 60,
        timeRange: TimeRange(0, 960),
      );

      AnthemStore.instance.projects[project.id] = project;
      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(arrangerViewModelService, (_, _) => viewModel),
        ]),
      );

      try {
        final controller = ServiceRegistry.forProject(
          project.id,
        ).arrangerController;
        final parentTrack = project.tracks[project.trackOrder.first]!;
        final utilityNode = parentTrack.requireProcessing.utilityNode!;
        final utilityPort = utilityNode.getPortById(
          UtilityProcessorModel.gainPortId,
        );
        final target = controller.resolveAutomationTarget(
          nodeId: utilityNode.id,
          portId: utilityPort.id,
        );

        expect(target, isNotNull);

        expect(controller.createAutomationLaneForTarget(target!), isNotNull);

        utilityPort.parameterValue = 0.41;

        expect(viewModel.lastTweakedAutomationTarget, isNotNull);
        expect(
          viewModel.lastTweakedAutomationTarget!.ownerTrackId,
          equals(parentTrack.id),
        );
        expect(
          viewModel.lastTweakedAutomationTarget!.nodeId,
          equals(utilityNode.id),
        );
        expect(
          viewModel.lastTweakedAutomationTarget!.portId,
          equals(UtilityProcessorModel.gainPortId),
        );
      } finally {
        ServiceRegistry.removeProject(project.id);
        AnthemStore.instance.projects.remove(project.id);
        project.dispose();
      }
    });

    test('suppressed parameter changes do not update automation target', () {
      fixture.dispose();

      final project = ProjectModel.create();
      final viewModel = ArrangerViewModel(
        project: project,
        baseTrackHeight: 60,
        timeRange: TimeRange(0, 960),
      );

      AnthemStore.instance.projects[project.id] = project;
      ServiceRegistry.initializeProject(
        project,
        overrides: ProjectServiceFactoryOverrides([
          overrideService(arrangerViewModelService, (_, _) => viewModel),
        ]),
      );

      try {
        ServiceRegistry.forProject(project.id).arrangerController;
        final parentTrack = project.tracks[project.trackOrder.first]!;
        final utilityNode = parentTrack.requireProcessing.utilityNode!;
        final utilityPort = utilityNode.getPortById(
          UtilityProcessorModel.gainPortId,
        );

        utilityNode.withoutParameterTouchTracking(() {
          utilityPort.parameterValue = 0.41;
        });

        expect(viewModel.lastTweakedAutomationTarget, isNull);
      } finally {
        ServiceRegistry.removeProject(project.id);
        AnthemStore.instance.projects.remove(project.id);
        project.dispose();
      }
    });

    test(
      'non-parameter control port changes do not update automation target',
      () {
        fixture.dispose();

        final project = ProjectModel.create();
        final viewModel = ArrangerViewModel(
          project: project,
          baseTrackHeight: 60,
          timeRange: TimeRange(0, 960),
        );

        AnthemStore.instance.projects[project.id] = project;
        ServiceRegistry.initializeProject(
          project,
          overrides: ProjectServiceFactoryOverrides([
            overrideService(arrangerViewModelService, (_, _) => viewModel),
          ]),
        );

        try {
          ServiceRegistry.forProject(project.id).arrangerController;
          final parentTrack = project.tracks[project.trackOrder.first]!;
          final utilityNode = parentTrack.requireProcessing.utilityNode!;
          final nonParameterPort = NodePortModel(
            nodeId: utilityNode.id,
            id: 999,
            config: NodePortConfigModel(dataType: NodePortDataType.control),
          );

          utilityNode.controlInputPorts.add(nonParameterPort);
          nonParameterPort.parameterValue = 0.41;

          expect(viewModel.lastTweakedAutomationTarget, isNull);
        } finally {
          ServiceRegistry.removeProject(project.id);
          AnthemStore.instance.projects.remove(project.id);
          project.dispose();
        }
      },
    );
  });

  ({Id patternId, Id clipId}) createClipAndGetCreatedIds({
    required Id trackId,
    required double offset,
    double? width,
    bool expectPianoRollOpened = true,
  }) {
    final arrangementId = fixture.project.sequence.activeArrangementID!;
    final arrangement = fixture.project.sequence.arrangements[arrangementId]!;

    final beforePatternIds = fixture.project.sequence.patterns.keys.toSet();
    final beforeClipIds = arrangement.clips.keys.toSet();

    fixture.controller.createClip(
      trackId: trackId,
      offset: offset,
      width: width,
    );

    final createdPatternIds = fixture.project.sequence.patterns.keys
        .toSet()
        .difference(beforePatternIds);
    final createdClipIds = arrangement.clips.keys.toSet().difference(
      beforeClipIds,
    );

    expect(createdPatternIds, hasLength(1));
    expect(createdClipIds, hasLength(1));
    verify(fixture.mockTrackController.setActiveTrack(trackId)).called(1);
    if (expectPianoRollOpened) {
      verify(
        fixture.mockProjectController.openPatternInPianoRoll(
          createdPatternIds.single,
        ),
      ).called(1);
    } else {
      verifyNever(
        fixture.mockProjectController.openPatternInPianoRoll(
          createdPatternIds.single,
        ),
      );
    }

    return (patternId: createdPatternIds.single, clipId: createdClipIds.single);
  }

  ({TrackModel parentTrack, NodeModel utilityNode, NodePortModel port})
  configureUtilityAutomationTarget({double? parameterValue}) {
    final parentTrack = fixture.project.tracks[_TrackIds.a]!;

    fixture.project.processingGraph = ProcessingGraphModel.create(
      masterOutputNodeId: getId(),
    );
    parentTrack.createAndRegisterNodes(
      fixture.project,
      fixture.project.idAllocator,
    );

    final utilityNode = parentTrack.requireProcessing.utilityNode!;
    final port = utilityNode.getPortById(UtilityProcessorModel.gainPortId);
    if (parameterValue != null) {
      port.parameterValue = parameterValue;
    }

    return (parentTrack: parentTrack, utilityNode: utilityNode, port: port);
  }

  ({TrackModel automationLane, NodePortModel port}) addUtilityAutomationLane({
    double? parameterValue,
  }) {
    final (:parentTrack, :utilityNode, :port) =
        configureUtilityAutomationTarget(parameterValue: parameterValue);

    AutomationLaneAddRemoveCommand.add(
      project: fixture.project,
      parentTrackId: parentTrack.id,
      nodeId: utilityNode.id,
      portId: UtilityProcessorModel.gainPortId,
      name: 'Volume',
    ).execute(fixture.project);

    final automationLane =
        fixture.project.tracks[parentTrack.automationLanes.single]!;

    return (automationLane: automationLane, port: port);
  }

  void addAutomationClip({
    required TrackModel track,
    required int offset,
    required int width,
    required double startValue,
    required double endValue,
  }) {
    final pattern = PatternModel(
      idAllocator: fixture.project.idAllocator,
      name: 'Existing automation',
    );
    pattern.automation.points.addAll([
      AutomationPointModel(
        idAllocator: fixture.project.idAllocator,
        offset: 0,
        value: startValue,
      ),
      AutomationPointModel(
        idAllocator: fixture.project.idAllocator,
        offset: width,
        value: endValue,
      ),
    ]);

    fixture.project.sequence.patterns[pattern.id] = pattern;

    final arrangement = fixture
        .project
        .sequence
        .arrangements[fixture.project.sequence.activeArrangementID]!;
    final clip = ClipModel(
      idAllocator: fixture.project.idAllocator,
      patternId: pattern.id,
      trackId: track.id,
      offset: offset,
      timeView: TimeViewModel(start: 0, end: width),
    );

    arrangement.clips[clip.id] = clip;
  }

  group('createClip', () {
    test(
      'creates a pattern and clip in active arrangement with rounded timing',
      () {
        final arrangementId = fixture.project.sequence.activeArrangementID;
        expect(arrangementId, isNotNull);

        final createdIds = createClipAndGetCreatedIds(
          trackId: _TrackIds.a1,
          offset: 12.6,
          width: 47.4,
        );

        final arrangement =
            fixture.project.sequence.arrangements[arrangementId!]!;
        final clip = arrangement.clips[createdIds.clipId]!;
        final pattern =
            fixture.project.sequence.patterns[createdIds.patternId]!;

        expect(clip.patternId, equals(pattern.id));
        expect(clip.trackId, equals(_TrackIds.a1));
        expect(clip.offset, equals(13));
        expect(clip.timeView, isNotNull);
        expect(clip.timeView!.start, equals(0));
        expect(clip.timeView!.end, equals(47));
        expect(pattern.automation.points, isEmpty);
      },
    );

    test('copies track metadata onto created pattern', () {
      final track = fixture.project.tracks[_TrackIds.b]!;

      final createdIds = createClipAndGetCreatedIds(
        trackId: _TrackIds.b,
        offset: 0,
        width: 96,
      );

      final pattern = fixture.project.sequence.patterns[createdIds.patternId]!;

      expect(pattern.name, equals(track.name));
      expect(pattern.color.hue, equals(track.color.hue));
      expect(pattern.color.palette, equals(track.color.palette));
      expect(identical(pattern.color, track.color), isFalse);
    });

    test('is a single undo/redo action', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;

      final createdIds = createClipAndGetCreatedIds(
        trackId: _TrackIds.a2a,
        offset: 24,
        width: 32,
      );

      expect(
        fixture.project.sequence.patterns.containsKey(createdIds.patternId),
        isTrue,
      );
      expect(arrangement.clips.containsKey(createdIds.clipId), isTrue);

      fixture.project.undo();

      expect(
        fixture.project.sequence.patterns.containsKey(createdIds.patternId),
        isFalse,
      );
      expect(arrangement.clips.containsKey(createdIds.clipId), isFalse);

      fixture.project.redo();

      expect(
        fixture.project.sequence.patterns.containsKey(createdIds.patternId),
        isTrue,
      );
      expect(arrangement.clips.containsKey(createdIds.clipId), isTrue);
    });

    test('rounds offset and width near integer boundaries', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;

      final createdIds = createClipAndGetCreatedIds(
        trackId: _TrackIds.s1,
        offset: 10.49,
        width: 0.51,
      );

      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = arrangement.clips[createdIds.clipId]!;

      expect(clip.offset, equals(10));
      expect(clip.timeView, isNotNull);
      expect(clip.timeView!.start, equals(0));
      expect(clip.timeView!.end, equals(1));
    });

    test('automation lane clips are created without opening an editor', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final (:automationLane, :port) = addUtilityAutomationLane(
        parameterValue: 0.42,
      );

      final createdIds = createClipAndGetCreatedIds(
        trackId: automationLane.id,
        offset: 24,
        width: 96,
        expectPianoRollOpened: false,
      );

      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = arrangement.clips[createdIds.clipId]!;
      final pattern = fixture.project.sequence.patterns[createdIds.patternId]!;

      expect(clip.patternId, equals(pattern.id));
      expect(clip.trackId, equals(automationLane.id));
      expect(automationLane.name, equals('Volume'));
      expect(pattern.name, equals('Track - Volume'));
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, equals(0));
      expect(pattern.automation.points[1].offset, equals(96));
      expect(
        pattern.automation.points[0].value,
        closeTo(port.parameterValue!, 0.000001),
      );
      expect(
        pattern.automation.points[1].value,
        closeTo(port.parameterValue!, 0.000001),
      );
    });

    test('automation clip seed points use held lane value at clip start', () {
      final (:automationLane, :port) = addUtilityAutomationLane(
        parameterValue: 0.91,
      );
      addAutomationClip(
        track: automationLane,
        offset: 0,
        width: 96,
        startValue: 0.2,
        endValue: 0.7,
      );
      port.parameterValue = 0.13;

      final createdIds = createClipAndGetCreatedIds(
        trackId: automationLane.id,
        offset: 144,
        width: 48,
        expectPianoRollOpened: false,
      );

      final pattern = fixture.project.sequence.patterns[createdIds.patternId]!;

      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].value, closeTo(0.7, 0.000001));
      expect(pattern.automation.points[1].value, closeTo(0.7, 0.000001));
    });

    test('unbounded automation clips seed the end point at default width', () {
      final (:automationLane, port: _) = addUtilityAutomationLane(
        parameterValue: 0.37,
      );

      final createdIds = createClipAndGetCreatedIds(
        trackId: automationLane.id,
        offset: 24,
        expectPianoRollOpened: false,
      );

      final arrangement = fixture
          .project
          .sequence
          .arrangements[fixture.project.sequence.activeArrangementID!]!;
      final clip = arrangement.clips[createdIds.clipId]!;
      final pattern = fixture.project.sequence.patterns[createdIds.patternId]!;

      expect(clip.timeView, isNull);
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, equals(0));
      expect(pattern.automation.points[1].offset, equals(clip.width));
    });

    test('automation clip seed points fall back to provider empty value', () {
      final (:automationLane, :port) = addUtilityAutomationLane(
        parameterValue: 0.37,
      );
      final provider =
          automationLane
                  .requireAutomationProcessing
                  .sequenceAutomationProviderNode!
                  .processor
              as SequenceAutomationProviderProcessorModel;
      port.parameterValue = 0.82;

      final createdIds = createClipAndGetCreatedIds(
        trackId: automationLane.id,
        offset: 24,
        width: 96,
        expectPianoRollOpened: false,
      );

      final pattern = fixture.project.sequence.patterns[createdIds.patternId]!;

      expect(pattern.automation.points, hasLength(2));
      expect(
        pattern.automation.points[0].value,
        closeTo(provider.emptyValue, 0.000001),
      );
      expect(
        pattern.automation.points[1].value,
        closeTo(provider.emptyValue, 0.000001),
      );
    });

    test(
      'phantom automation clips seed from current value through empty value',
      () {
        final (:parentTrack, :utilityNode, :port) =
            configureUtilityAutomationTarget(parameterValue: 0.64);
        final target = fixture.controller.resolveAutomationTarget(
          nodeId: utilityNode.id,
          portId: port.id,
        );
        expect(target, isNotNull);

        final arrangement = fixture
            .project
            .sequence
            .arrangements[fixture.project.sequence.activeArrangementID]!;
        final beforeTrackIds = fixture.project.tracks.keys.toSet();
        final beforePatternIds = fixture.project.sequence.patterns.keys.toSet();
        final beforeClipIds = arrangement.clips.keys.toSet();

        fixture.controller.createClipForAutomationTarget(
          target: target!,
          offset: 24,
          width: 96,
        );

        final createdTrackIds = fixture.project.tracks.keys.toSet().difference(
          beforeTrackIds,
        );
        final createdPatternIds = fixture.project.sequence.patterns.keys
            .toSet()
            .difference(beforePatternIds);
        final createdClipIds = arrangement.clips.keys.toSet().difference(
          beforeClipIds,
        );

        expect(createdTrackIds, hasLength(1));
        expect(createdPatternIds, hasLength(1));
        expect(createdClipIds, hasLength(1));

        final automationLane = fixture.project.tracks[createdTrackIds.single]!;
        final pattern =
            fixture.project.sequence.patterns[createdPatternIds.single]!;
        final provider =
            automationLane
                    .requireAutomationProcessing
                    .sequenceAutomationProviderNode!
                    .processor
                as SequenceAutomationProviderProcessorModel;

        expect(parentTrack.automationLanes.single, equals(automationLane.id));
        expect(provider.emptyValue, closeTo(port.parameterValue!, 0.000001));
        expect(pattern.automation.points, hasLength(2));
        expect(pattern.automation.points[0].value, closeTo(0.64, 0.000001));
        expect(pattern.automation.points[1].value, closeTo(0.64, 0.000001));
        verify(
          fixture.mockTrackController.setActiveTrack(automationLane.id),
        ).called(1);
        verifyNever(
          fixture.mockProjectController.openPatternInPianoRoll(
            createdPatternIds.single,
          ),
        );
      },
    );
  });

  group('Track selection basics', () {
    test('selectTrack selects only target and resets shift state', () {
      fixture.viewModel.selectedTracks.addAll([_TrackIds.a, _TrackIds.s1]);
      fixture.viewModel.lastShiftClickRange = (
        selected: [_TrackIds.a],
        notSelected: [_TrackIds.s1],
      );

      fixture.controller.selectTrack(_TrackIds.b);

      fixture.expectSelectedTracks([_TrackIds.b]);
      expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.b));
      expect(fixture.viewModel.lastShiftClickRange, isNull);
    });

    test('toggleTrackSelection toggles target and resets shift state', () {
      fixture.viewModel.lastShiftClickRange = (
        selected: [_TrackIds.a],
        notSelected: [],
      );

      fixture.controller.toggleTrackSelection(_TrackIds.a1);

      fixture.expectSelectedTracks([_TrackIds.a1]);
      expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.a1));
      expect(fixture.viewModel.lastShiftClickRange, isNull);

      fixture.viewModel.lastShiftClickRange = (
        selected: [_TrackIds.a1],
        notSelected: [],
      );

      fixture.controller.toggleTrackSelection(_TrackIds.a1);

      fixture.expectSelectedTracks([]);
      expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.a1));
      expect(fixture.viewModel.lastShiftClickRange, isNull);
    });
  });

  group('deleteClips', () {
    test('delegates to ProjectController and updates selected clips', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final selectedClipA = getId();
      final selectedClipB = getId();
      final unselectedClip = getId();
      final clipIdsToDelete = [selectedClipA, unselectedClip];

      fixture.viewModel.selectedClips.addAll([selectedClipA, selectedClipB]);

      when(
        fixture.mockTrackController.deleteClips(
          arrangementId: arrangementId,
          clipIds: clipIdsToDelete,
        ),
      ).thenReturn((
        deletedClipIds: {selectedClipA},
        deletedPatternIds: <Id>{},
      ));

      fixture.controller.deleteClips(clipIdsToDelete);

      verify(
        fixture.mockTrackController.deleteClips(
          arrangementId: arrangementId,
          clipIds: clipIdsToDelete,
        ),
      ).called(1);

      expect(fixture.viewModel.selectedClips.contains(selectedClipA), isFalse);
      expect(fixture.viewModel.selectedClips.contains(selectedClipB), isTrue);
    });
  });

  group('shiftClickToTrack', () {
    test('no anchor falls back to toggle behavior', () {
      fixture.controller.shiftClickToTrack(_TrackIds.a2a);

      fixture.expectSelectedTracks([_TrackIds.a2a]);
      expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.a2a));
      expect(fixture.viewModel.lastShiftClickRange, isNull);
    });

    test('selects inclusive range using depth-first tree order', () {
      fixture.controller.selectTrack(_TrackIds.a1);

      fixture.controller.shiftClickToTrack(_TrackIds.b);

      fixture.expectSelectedTracks([
        _TrackIds.a1,
        _TrackIds.a2,
        _TrackIds.a2a,
        _TrackIds.b,
      ]);
    });

    test('works across regular and send tracks in visual order', () {
      fixture.controller.selectTrack(_TrackIds.b);

      fixture.controller.shiftClickToTrack(_TrackIds.s1);

      fixture.expectSelectedTracks([_TrackIds.b, _TrackIds.s, _TrackIds.s1]);
    });

    test('reverts prior shift range before applying new one', () {
      fixture.controller.selectTrack(_TrackIds.a1);

      fixture.controller.shiftClickToTrack(_TrackIds.b);
      fixture.expectSelectedTracks([
        _TrackIds.a1,
        _TrackIds.a2,
        _TrackIds.a2a,
        _TrackIds.b,
      ]);

      fixture.controller.shiftClickToTrack(_TrackIds.a2a);

      fixture.expectSelectedTracks([_TrackIds.a1, _TrackIds.a2, _TrackIds.a2a]);
      expect(fixture.viewModel.selectedTracks.contains(_TrackIds.b), isFalse);
    });

    test(
      'falls back to selectTrack when anchor is no longer in track list',
      () {
        fixture.controller.selectTrack(_TrackIds.a1);

        fixture.project.tracks[_TrackIds.a]!.childTracks.remove(_TrackIds.a1);
        fixture.project.tracks.remove(_TrackIds.a1);

        fixture.controller.shiftClickToTrack(_TrackIds.b);

        fixture.expectSelectedTracks([_TrackIds.b]);
        expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.b));
        expect(fixture.viewModel.lastShiftClickRange, isNull);
      },
    );

    test('does nothing when there is no active arrangement', () {
      fixture.controller.selectTrack(_TrackIds.a1);
      fixture.project.sequence.activeArrangementID = null;

      fixture.controller.shiftClickToTrack(_TrackIds.b);

      fixture.expectSelectedTracks([_TrackIds.a1]);
      expect(fixture.viewModel.lastToggledTrack, equals(_TrackIds.a1));
      expect(fixture.viewModel.lastShiftClickRange, isNull);
    });
  });
}
