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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
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

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pattern compiler invalidation', () {
    test(
      'compiles NO_TRACK pattern events and maps invalidation to arrangement tracks',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = ProjectModel.create()..engine = runningEngine;

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

        final pattern = PatternModel.create(name: 'Pattern A');
        final note = NoteModel(
          key: 60,
          velocity: 0.9,
          length: 20,
          offset: 60,
          pan: 0,
        );
        pattern.notes.add(note);
        project.sequence.patterns[pattern.id] = pattern;

        final trackA = getId();
        final trackB = getId();
        final trackC = getId();

        final clipA = _createClipWithTimeView(
          id: getId(),
          patternId: pattern.id,
          trackId: trackA,
          offset: 100,
          start: 0,
          end: 96,
        );
        final clipB = _createClipWithTimeView(
          id: getId(),
          patternId: pattern.id,
          trackId: trackB,
          offset: 300,
          start: 48,
          end: 120,
        );
        final clipC = _createClipWithTimeView(
          id: getId(),
          patternId: pattern.id,
          trackId: trackC,
          offset: 500,
          start: 0,
          end: 32,
        );

        arrangement.clips[clipA.id] = clipA;
        arrangement.clips[clipB.id] = clipB;
        arrangement.clips[clipC.id] = clipC;

        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        note.key = 61;
        await _flushMicrotasks();

        final patternCompileVerification = verify(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        patternCompileVerification.called(1);

        final patternCompileCaptured = patternCompileVerification.captured;
        final patternTracksToRebuild =
            patternCompileCaptured[0] as List<String>;
        final patternInvalidationRanges =
            patternCompileCaptured[1] as List<InvalidationRange>;

        expect(patternTracksToRebuild, equals(<String>['NO_TRACK']));
        expect(patternInvalidationRanges, hasLength(1));
        expect(patternInvalidationRanges[0].start, equals(60));
        expect(patternInvalidationRanges[0].end, equals(80));

        final arrangementCompileVerification = verify(
          sequencerApi.compileArrangement(
            arrangement.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        arrangementCompileVerification.called(1);

        final arrangementCompileCaptured =
            arrangementCompileVerification.captured;
        final arrangementTracksToRebuild =
            arrangementCompileCaptured[0] as List<String>;
        final arrangementInvalidationRanges =
            arrangementCompileCaptured[1] as List<InvalidationRange>;

        expect(
          arrangementTracksToRebuild.toSet(),
          equals(<String>{trackA, trackB}),
        );
        expect(arrangementInvalidationRanges, hasLength(2));
        expect(arrangementInvalidationRanges[0].start, equals(160));
        expect(arrangementInvalidationRanges[0].end, equals(180));
        expect(arrangementInvalidationRanges[1].start, equals(312));
        expect(arrangementInvalidationRanges[1].end, equals(332));
      },
    );

    test(
      'does not recompile arrangement tracks when invalidation does not touch any clip view',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = ProjectModel.create()..engine = runningEngine;

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

        final pattern = PatternModel.create(name: 'Pattern B');
        final note = NoteModel(
          key: 60,
          velocity: 0.9,
          length: 20,
          offset: 60,
          pan: 0,
        );
        pattern.notes.add(note);
        project.sequence.patterns[pattern.id] = pattern;

        final clip = _createClipWithTimeView(
          id: getId(),
          patternId: pattern.id,
          trackId: getId(),
          offset: 100,
          start: 0,
          end: 40,
        );
        arrangement.clips[clip.id] = clip;

        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        note.velocity = 0.7;
        await _flushMicrotasks();

        final patternCompileVerification = verify(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
            invalidationRanges: captureAnyNamed('invalidationRanges'),
          ),
        );
        patternCompileVerification.called(1);

        final patternCompileCaptured = patternCompileVerification.captured;
        final patternTracksToRebuild =
            patternCompileCaptured[0] as List<String>;
        final patternInvalidationRanges =
            patternCompileCaptured[1] as List<InvalidationRange>;

        expect(patternTracksToRebuild, equals(<String>['NO_TRACK']));
        expect(patternInvalidationRanges, hasLength(1));
        expect(patternInvalidationRanges[0].start, equals(60));
        expect(patternInvalidationRanges[0].end, equals(80));

        verifyNever(
          sequencerApi.compileArrangement(
            arrangement.id,
            tracksToRebuild: anyNamed('tracksToRebuild'),
            invalidationRanges: anyNamed('invalidationRanges'),
          ),
        );
      },
    );
  });
}
