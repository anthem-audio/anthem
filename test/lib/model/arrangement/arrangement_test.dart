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
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart'
    show InvalidationRange;
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _MockSequencerApi extends Mock implements SequencerApi {}

class _RunningEngine extends Mock implements Engine {
  final SequencerApi _sequencerApi;
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();

  _RunningEngine(this._sequencerApi);

  @override
  bool get isRunning => true;

  @override
  SequencerApi get sequencerApi => _sequencerApi;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;
}

ClipModel _createClip({
  required Id id,
  required Id patternId,
  Id? trackId,
  int offset = 0,
}) {
  return ClipModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    patternId: patternId,
    trackId: trackId ?? getId(),
    offset: offset,
  );
}

ArrangementModel _createArrangement() {
  final arrangement = ArrangementModel(
    idAllocator: ProjectEntityIdAllocator.test(getId),
    name: 'A',
  );
  arrangement.setParentPropertiesOnChildren();
  return arrangement;
}

ClipModel _createClipWithTimeView({
  required Id id,
  required Id patternId,
  required Id trackId,
  required int offset,
  required int start,
  required int end,
}) {
  return ClipModel(
    idAllocator: ProjectEntityIdAllocator.test(() => id),
    patternId: patternId,
    trackId: trackId,
    offset: offset,
    timeView: TimeViewModel(start: start, end: end),
  );
}

ProjectModel _createProjectWithRunningMockEngine({
  required _RunningEngine engine,
}) {
  final project = ProjectModel.create();

  project.engine = engine;
  return project;
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrangementModel clip reference caches', () {
    test('is not serialized', () {
      final arrangement = _createArrangement();
      final serialized = arrangement.toJson();

      expect(serialized.containsKey('patternClipReferenceCounts'), isFalse);
      expect(serialized.containsKey('patternClipIdsByPatternId'), isFalse);
      expect(serialized.containsKey('trackClipIdsByTrackId'), isFalse);
    });

    test('is rebuilt from clips when deserialized', () {
      final patternA = getId();
      final patternB = getId();
      final trackA = getId();
      final trackB = getId();
      final clipA1 = _createClip(
        id: getId(),
        patternId: patternA,
        trackId: trackA,
        offset: 0,
      );
      final clipA2 = _createClip(
        id: getId(),
        patternId: patternA,
        trackId: trackA,
        offset: 96,
      );
      final clipB = _createClip(
        id: getId(),
        patternId: patternB,
        trackId: trackB,
        offset: 192,
      );

      final arrangement = ArrangementModel.fromJson({
        'id': getId(),
        'name': 'Deserialized arrangement',
        'clips': {
          clipA1.id.toString(): clipA1.toJson(),
          clipA2.id.toString(): clipA2.toJson(),
          clipB.id.toString(): clipB.toJson(),
        },
        'timeSignatureChanges': <Map<String, dynamic>>[],
      });

      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(
        arrangement.getClipIdsForPattern(patternA).toSet(),
        equals({clipA1.id, clipA2.id}),
      );
      expect(arrangement.getClipIdsForPattern(patternB), equals([clipB.id]));
      expect(
        arrangement.patternClipReferenceCounts.keys.toSet(),
        equals({patternA, patternB}),
      );
      expect(
        arrangement.patternClipIdsByPatternId.keys.toSet(),
        equals({patternA, patternB}),
      );
      expect(
        arrangement.getClipIdsForTrack(trackA).toSet(),
        equals({clipA1.id, clipA2.id}),
      );
      expect(arrangement.getClipIdsForTrack(trackB), equals([clipB.id]));
      expect(arrangement.hasClipsForTrack(trackA), isTrue);
      expect(arrangement.hasClipsForTrack(getId()), isFalse);
      expect(
        arrangement.trackClipIdsByTrackId.keys.toSet(),
        equals({trackA, trackB}),
      );
    });

    test('updates on clip add and remove', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final trackA = getId();
      final trackB = getId();
      final clipA1 = _createClip(
        id: getId(),
        patternId: patternA,
        trackId: trackA,
      );
      final clipA2 = _createClip(
        id: getId(),
        patternId: patternA,
        trackId: trackA,
      );
      final clipB = _createClip(
        id: getId(),
        patternId: patternB,
        trackId: trackB,
      );

      arrangement.clips[clipA1.id] = clipA1;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getClipIdsForPattern(patternA), equals([clipA1.id]));
      expect(arrangement.getClipIdsForTrack(trackA), equals([clipA1.id]));
      expect(arrangement.hasClipsForTrack(trackA), isTrue);

      arrangement.clips[clipA2.id] = clipA2;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(
        arrangement.getClipIdsForPattern(patternA).toSet(),
        equals({clipA1.id, clipA2.id}),
      );
      expect(
        arrangement.getClipIdsForTrack(trackA).toSet(),
        equals({clipA1.id, clipA2.id}),
      );

      arrangement.clips[clipB.id] = clipB;
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(arrangement.getClipIdsForPattern(patternB), equals([clipB.id]));
      expect(arrangement.getClipIdsForTrack(trackB), equals([clipB.id]));

      arrangement.clips.remove(clipA1.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getClipIdsForPattern(patternA), equals([clipA2.id]));
      expect(arrangement.getClipIdsForTrack(trackA), equals([clipA2.id]));

      arrangement.clips.remove(clipA2.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getClipIdsForPattern(patternA), isEmpty);
      expect(arrangement.getClipIdsForTrack(trackA), isEmpty);
      expect(arrangement.hasClipsForTrack(trackA), isFalse);
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
      expect(
        arrangement.patternClipIdsByPatternId.containsKey(patternA),
        isFalse,
      );
      expect(arrangement.trackClipIdsByTrackId.containsKey(trackA), isFalse);
    });

    test('updates correctly when map put replaces an existing clip', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final trackA = getId();
      final trackB = getId();
      final clipId = getId();

      arrangement.clips[clipId] = _createClip(
        id: clipId,
        patternId: patternA,
        trackId: trackA,
      );
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(0));
      expect(arrangement.getClipIdsForPattern(patternA), equals([clipId]));
      expect(arrangement.getClipIdsForPattern(patternB), isEmpty);
      expect(arrangement.getClipIdsForTrack(trackA), equals([clipId]));
      expect(arrangement.getClipIdsForTrack(trackB), isEmpty);

      arrangement.clips[clipId] = _createClip(
        id: clipId,
        patternId: patternB,
        trackId: trackB,
      );
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(arrangement.getClipIdsForPattern(patternA), isEmpty);
      expect(arrangement.getClipIdsForPattern(patternB), equals([clipId]));
      expect(arrangement.getClipIdsForTrack(trackA), isEmpty);
      expect(arrangement.getClipIdsForTrack(trackB), equals([clipId]));
    });

    test('updates when a clip patternId changes', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clip1 = _createClip(id: getId(), patternId: patternA);
      final clip2 = _createClip(id: getId(), patternId: patternA);

      arrangement.clips[clip1.id] = clip1;
      arrangement.clips[clip2.id] = clip2;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(0));
      expect(
        arrangement.getClipIdsForPattern(patternA).toSet(),
        equals({clip1.id, clip2.id}),
      );
      expect(arrangement.getClipIdsForPattern(patternB), isEmpty);

      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(arrangement.getClipIdsForPattern(patternA), equals([clip2.id]));
      expect(arrangement.getClipIdsForPattern(patternB), equals([clip1.id]));

      // Writing same value should not change counts.
      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(arrangement.getClipIdsForPattern(patternA), equals([clip2.id]));
      expect(arrangement.getClipIdsForPattern(patternB), equals([clip1.id]));

      clip2.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(2));
      expect(arrangement.getClipIdsForPattern(patternA), isEmpty);
      expect(
        arrangement.getClipIdsForPattern(patternB).toSet(),
        equals({clip1.id, clip2.id}),
      );
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
      expect(
        arrangement.patternClipIdsByPatternId.containsKey(patternA),
        isFalse,
      );
    });

    test('updates when a clip trackId changes', () {
      final arrangement = _createArrangement();
      final patternId = getId();
      final trackA = getId();
      final trackB = getId();
      final clip1 = _createClip(
        id: getId(),
        patternId: patternId,
        trackId: trackA,
      );
      final clip2 = _createClip(
        id: getId(),
        patternId: patternId,
        trackId: trackA,
      );

      arrangement.clips[clip1.id] = clip1;
      arrangement.clips[clip2.id] = clip2;
      expect(
        arrangement.getClipIdsForTrack(trackA).toSet(),
        equals({clip1.id, clip2.id}),
      );
      expect(arrangement.getClipIdsForTrack(trackB), isEmpty);

      clip1.trackId = trackB;
      expect(arrangement.getClipIdsForTrack(trackA), equals([clip2.id]));
      expect(arrangement.getClipIdsForTrack(trackB), equals([clip1.id]));
      expect(arrangement.hasClipsForTrack(trackA), isTrue);
      expect(arrangement.hasClipsForTrack(trackB), isTrue);

      // Writing same value should not change indexes.
      clip1.trackId = trackB;
      expect(arrangement.getClipIdsForTrack(trackA), equals([clip2.id]));
      expect(arrangement.getClipIdsForTrack(trackB), equals([clip1.id]));

      clip2.trackId = trackB;
      expect(arrangement.getClipIdsForTrack(trackA), isEmpty);
      expect(
        arrangement.getClipIdsForTrack(trackB).toSet(),
        equals({clip1.id, clip2.id}),
      );
      expect(arrangement.trackClipIdsByTrackId.containsKey(trackA), isFalse);
    });
  });

  group('ArrangementModel track compile invalidation', () {
    test(
      'rebuilds both old and new tracks when clip trackId changes',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = _createProjectWithRunningMockEngine(
          engine: runningEngine,
        );

        final arrangement = project.sequence.arrangement;

        final oldTrackId = getId();
        final newTrackId = getId();
        final clip = _createClipWithTimeView(
          id: getId(),
          patternId: getId(),
          trackId: oldTrackId,
          offset: 96,
          start: 0,
          end: 48,
        );

        arrangement.clips[clip.id] = clip;
        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        clip.trackId = newTrackId;
        await _flushMicrotasks();

        final verification = verify(
          sequencerApi.compileArrangement(
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        verification.called(1);

        final captured = verification.captured;
        final tracksToRebuild = captured[0] as List<Id>;
        final invalidationRanges = captured[1] as List<InvalidationRange>;

        expect(tracksToRebuild.toSet(), equals(<Id>{oldTrackId, newTrackId}));
        expect(invalidationRanges, hasLength(1));
        expect(invalidationRanges[0].start, equals(96));
        expect(invalidationRanges[0].end, equals(144));
      },
    );

    test(
      'rebuilds both old and new tracks when replacing a clip on a new track',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = _createProjectWithRunningMockEngine(
          engine: runningEngine,
        );

        final arrangement = project.sequence.arrangement;

        final clipId = getId();
        final oldTrackId = getId();
        final newTrackId = getId();

        arrangement.clips[clipId] = _createClipWithTimeView(
          id: clipId,
          patternId: getId(),
          trackId: oldTrackId,
          offset: 100,
          start: 0,
          end: 96,
        );
        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        arrangement.clips[clipId] = _createClipWithTimeView(
          id: clipId,
          patternId: getId(),
          trackId: newTrackId,
          offset: 140,
          start: 0,
          end: 48,
        );
        await _flushMicrotasks();

        final verification = verify(
          sequencerApi.compileArrangement(
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        verification.called(1);

        final captured = verification.captured;
        final tracksToRebuild = captured[0] as List<Id>;
        final invalidationRanges = captured[1] as List<InvalidationRange>;

        expect(tracksToRebuild.toSet(), equals(<Id>{oldTrackId, newTrackId}));
        expect(invalidationRanges, hasLength(1));
        expect(invalidationRanges[0].start, equals(100));
        expect(invalidationRanges[0].end, equals(196));
      },
    );
  });
}
