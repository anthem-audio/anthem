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
import 'package:anthem/logic/devices/device_factory.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/logic/track_controller.dart';
import 'package:anthem/model/device.dart';
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
  static const automationA = 9;
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
    project.sequence = SequencerModel(
      idAllocator: ProjectEntityIdAllocator.test(getId),
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
      timeView: TimeRange(0, 960),
    );

    AnthemStore.instance.projects[project.id] = project;

    final controller = ArrangerController(
      viewModel: viewModel,
      project: project,
    );
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
        timeView: TimeRange(0, 960),
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

        utilityNode.lastChangedControlPortId = UtilityProcessorModel.gainPortId;

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

        deviceNode.lastChangedControlPortId =
            ToneGeneratorProcessorModel.frequencyPortId;

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
  });

  ({Id patternId, Id clipId}) createClipAndGetCreatedIds({
    required Id trackId,
    required double offset,
    required double width,
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
      final parentTrack = fixture.project.tracks[_TrackIds.a]!;
      final automationLane = _makeTrack(
        _TrackIds.automationA,
        'A Automation',
        TrackType.automationLane,
      )..automationLaneParentTrackId = parentTrack.id;

      fixture.project.tracks[automationLane.id] = automationLane;
      parentTrack.automationLanes.add(automationLane.id);
      fixture.viewModel.registerTrack(automationLane.id);

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
      expect(pattern.name, equals(automationLane.name));
    });
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
