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
import 'package:anthem/logic/track_controller.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
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
}

class MockTrackController extends Mock implements TrackController {
  @override
  Iterable<(Id trackId, bool isSendTrack, int trackDepth)> getTracksIterable() {
    return super.noSuchMethod(
          Invocation.method(#getTracksIterable, []),
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
) sync* {
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
      _TrackIds.a1: _makeTrack(_TrackIds.a1, 'A1', TrackType.instrument),
      _TrackIds.a2: _makeTrack(_TrackIds.a2, 'A2', TrackType.group),
      _TrackIds.a2a: _makeTrack(_TrackIds.a2a, 'A2a', TrackType.instrument),
      _TrackIds.b: _makeTrack(_TrackIds.b, 'B', TrackType.instrument),
      _TrackIds.s: _makeTrack(_TrackIds.s, 'S', TrackType.group),
      _TrackIds.s1: _makeTrack(_TrackIds.s1, 'S1', TrackType.instrument),
      _TrackIds.master: _makeTrack(
        _TrackIds.master,
        'Master',
        TrackType.instrument,
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
    when(
      mockTrackController.getTracksIterable(),
    ).thenAnswer((_) => _getTracksIterable(project));
    ServiceRegistry.initializeProject(
      project,
      overrides: ProjectServiceFactoryOverrides(
        projectController: (_, _) => mockProjectController,
        trackController: (_, _) => mockTrackController,
      ),
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

  ({Id patternId, Id clipId}) createClipAndGetCreatedIds({
    required Id trackId,
    required double offset,
    required double width,
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
    verify(
      fixture.mockProjectController.openPatternInPianoRoll(
        createdPatternIds.single,
      ),
    ).called(1);

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
