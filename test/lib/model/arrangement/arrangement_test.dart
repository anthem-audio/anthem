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

ClipModel _createClip({required Id id, required Id patternId, int offset = 0}) {
  return ClipModel.create(
    id: id,
    patternId: patternId,
    trackId: getId(),
    offset: offset,
  );
}

ArrangementModel _createArrangement() {
  final arrangement = ArrangementModel.create(name: 'A', id: getId());
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
  return ClipModel.create(
    id: id,
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
  group('ArrangementModel pattern clip reference cache', () {
    test('is not serialized', () {
      final arrangement = _createArrangement();
      final serialized = arrangement.toJson();

      expect(serialized.containsKey('patternClipReferenceCounts'), isFalse);
    });

    test('is rebuilt from clips when deserialized', () {
      final patternA = getId();
      final patternB = getId();
      final clipA1 = _createClip(id: getId(), patternId: patternA, offset: 0);
      final clipA2 = _createClip(id: getId(), patternId: patternA, offset: 96);
      final clipB = _createClip(id: getId(), patternId: patternB, offset: 192);

      final arrangement = ArrangementModel.fromJson({
        'id': getId(),
        'name': 'Deserialized arrangement',
        'clips': {
          clipA1.id: clipA1.toJson(),
          clipA2.id: clipA2.toJson(),
          clipB.id: clipB.toJson(),
        },
        'timeSignatureChanges': <Map<String, dynamic>>[],
      });

      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
      expect(
        arrangement.patternClipReferenceCounts.keys.toSet(),
        equals({patternA, patternB}),
      );
    });

    test('updates on clip add and remove', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clipA1 = _createClip(id: getId(), patternId: patternA);
      final clipA2 = _createClip(id: getId(), patternId: patternA);
      final clipB = _createClip(id: getId(), patternId: patternB);

      arrangement.clips[clipA1.id] = clipA1;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));

      arrangement.clips[clipA2.id] = clipA2;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(2));

      arrangement.clips[clipB.id] = clipB;
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      arrangement.clips.remove(clipA1.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));

      arrangement.clips.remove(clipA2.id);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
    });

    test('updates correctly when map put replaces an existing clip', () {
      final arrangement = _createArrangement();
      final patternA = getId();
      final patternB = getId();
      final clipId = getId();

      arrangement.clips[clipId] = _createClip(id: clipId, patternId: patternA);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(0));

      arrangement.clips[clipId] = _createClip(id: clipId, patternId: patternB);
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));
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

      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      // Writing same value should not change counts.
      clip1.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(1));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(1));

      clip2.patternId = patternB;
      expect(arrangement.getPatternClipReferenceCount(patternA), equals(0));
      expect(arrangement.getPatternClipReferenceCount(patternB), equals(2));
      expect(
        arrangement.patternClipReferenceCounts.containsKey(patternA),
        isFalse,
      );
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

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

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
            arrangement.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        verification.called(1);

        final captured = verification.captured;
        final tracksToRebuild = captured[0] as List<String>;
        final invalidationRanges = captured[1] as List<InvalidationRange>;

        expect(
          tracksToRebuild.toSet(),
          equals(<String>{oldTrackId, newTrackId}),
        );
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

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

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
            arrangement.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        verification.called(1);

        final captured = verification.captured;
        final tracksToRebuild = captured[0] as List<String>;
        final invalidationRanges = captured[1] as List<InvalidationRange>;

        expect(
          tracksToRebuild.toSet(),
          equals(<String>{oldTrackId, newTrackId}),
        );
        expect(invalidationRanges, hasLength(1));
        expect(invalidationRanges[0].start, equals(100));
        expect(invalidationRanges[0].end, equals(196));
      },
    );
  });
}
