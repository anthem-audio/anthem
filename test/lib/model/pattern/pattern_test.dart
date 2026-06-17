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

import 'dart:ui' as ui;

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/engine_api/messages/messages.dart'
    show InvalidationRange;
import 'package:anthem/helpers/id.dart';
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/arrangement/clip.dart';
import 'package:anthem/model/pattern/automation_point.dart';
import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/clip/packed_texture.dart';
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

Future<void> _waitForAutomationCompileDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 125));
  await _flushMicrotasks();
}

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

int _ticksPerBar(ProjectModel project) {
  final timeSignature = project.sequence.defaultTimeSignature;
  final ticksPerBarDouble =
      project.sequence.ticksPerQuarter /
      (timeSignature.denominator / 4) *
      timeSignature.numerator;
  final ticksPerBar = ticksPerBarDouble.round();

  assert(ticksPerBarDouble == ticksPerBar);

  return ticksPerBar;
}

int _sixteenthNote(ProjectModel project) {
  final sixteenthNoteDouble = project.sequence.ticksPerQuarter / 4;
  final sixteenthNote = sixteenthNoteDouble.round();

  assert(sixteenthNoteDouble == sixteenthNote);

  return sixteenthNote;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pattern clip auto width', () {
    test('defaults to the next bar after content', () async {
      final project = ProjectModel.create();
      final ticksPerBar = _ticksPerBar(project);
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Bar-sized Pattern',
      );
      final note = NoteModel(
        idAllocator: _testIdAllocator(),
        key: 60,
        velocity: 0.8,
        length: 17,
        offset: ticksPerBar,
        pan: 0,
      );
      pattern.notes[note.id] = note;
      project.sequence.patterns[pattern.id] = pattern;

      await _flushMicrotasks();

      expect(pattern.clipAutoSizeMode, PatternClipAutoSizeMode.nextBar);
      expect(pattern.getContentWidth(), equals(ticksPerBar + 17));
      expect(pattern.clipAutoWidth, equals(ticksPerBar * 2));
    });

    test('content mode uses the exact content end', () async {
      final project = ProjectModel.create();
      final ticksPerBar = _ticksPerBar(project);
      final contentEnd = ticksPerBar + 17;
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Content-sized Pattern',
      )..clipAutoSizeMode = PatternClipAutoSizeMode.content;
      pattern.automation.points.addAll([
        AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: 0,
          value: 0.25,
        ),
        AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: contentEnd,
          value: 0.75,
        ),
      ]);
      project.sequence.patterns[pattern.id] = pattern;

      await _flushMicrotasks();

      expect(pattern.getWidth(), equals(ticksPerBar * 2));
      expect(pattern.clipAutoWidth, equals(contentEnd));
    });

    test('content mode uses a sixteenth-note minimum width', () async {
      final project = ProjectModel.create();
      final sixteenthNote = _sixteenthNote(project);
      project.sequence.defaultTimeSignature = TimeSignatureModel(7, 8);
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Minimum Content Pattern',
      )..clipAutoSizeMode = PatternClipAutoSizeMode.content;
      pattern.automation.points.add(
        AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: 0,
          value: 0.25,
        ),
      );
      project.sequence.patterns[pattern.id] = pattern;

      await _flushMicrotasks();

      expect(_ticksPerBar(project), isNot(equals(sixteenthNote)));
      expect(pattern.getContentWidth(), equals(sixteenthNote));
      expect(pattern.clipAutoWidth, equals(sixteenthNote));
    });

    test(
      'content mode updates arrangement width when content changes within one bar',
      () async {
        final project = ProjectModel.create();
        final ticksPerBar = _ticksPerBar(project);
        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID!]!;
        final arrangementWidthStep = ticksPerBar * 4;
        final initialArrangementWidth = arrangementWidthStep * 4;
        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Content-sized Automation',
        )..clipAutoSizeMode = PatternClipAutoSizeMode.content;
        final endPoint = AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: 100,
          value: 0.75,
        );
        pattern.automation.points.addAll([
          AutomationPointModel(
            idAllocator: _testIdAllocator(),
            offset: 0,
            value: 0.25,
          ),
          endPoint,
        ]);
        project.sequence.patterns[pattern.id] = pattern;

        final clip = ClipModel(
          idAllocator: _testIdAllocator(),
          patternId: pattern.id,
          trackId: getId(),
          offset: initialArrangementWidth - 150,
        );
        arrangement.clips[clip.id] = clip;

        await _flushMicrotasks();

        expect(pattern.clipAutoWidth, equals(100));
        expect(arrangement.viewWidth, equals(initialArrangementWidth));

        endPoint.offset = 200;
        await _flushMicrotasks();

        expect(pattern.clipAutoWidth, equals(200));
        expect(
          arrangement.viewWidth,
          equals(initialArrangementWidth + arrangementWidthStep),
        );
      },
    );
  });

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

        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Pattern A',
        );
        final note = NoteModel(
          idAllocator: _testIdAllocator(),
          key: 60,
          velocity: 0.9,
          length: 20,
          offset: 60,
          pan: 0,
        );
        pattern.notes[note.id] = note;
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
        final patternTracksToRebuild = patternCompileCaptured[0] as List<Id>;
        final patternInvalidationRanges =
            patternCompileCaptured[1] as List<InvalidationRange>;

        expect(patternTracksToRebuild, equals(<Id>[-1]));
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
            arrangementCompileCaptured[0] as List<Id>;
        final arrangementInvalidationRanges =
            arrangementCompileCaptured[1] as List<InvalidationRange>;

        expect(
          arrangementTracksToRebuild.toSet(),
          equals(<Id>{trackA, trackB}),
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

        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Pattern B',
        );
        final note = NoteModel(
          idAllocator: _testIdAllocator(),
          key: 60,
          velocity: 0.9,
          length: 20,
          offset: 60,
          pan: 0,
        );
        pattern.notes[note.id] = note;
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
        final patternTracksToRebuild = patternCompileCaptured[0] as List<Id>;
        final patternInvalidationRanges =
            patternCompileCaptured[1] as List<InvalidationRange>;

        expect(patternTracksToRebuild, equals(<Id>[-1]));
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

    test(
      'rate-limits automation point changes and keeps trailing compile',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = ProjectModel.create()..engine = runningEngine;

        final arrangement = project
            .sequence
            .arrangements[project.sequence.activeArrangementID]!;

        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Automation Pattern',
        );
        final firstPoint = AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: 10,
          value: 0.25,
        );
        final secondPoint = AutomationPointModel(
          idAllocator: _testIdAllocator(),
          offset: 30,
          value: 0.75,
        );
        pattern.automation.points.addAll([firstPoint, secondPoint]);
        project.sequence.patterns[pattern.id] = pattern;

        final trackId = getId();
        final clip = _createClipWithTimeView(
          id: getId(),
          patternId: pattern.id,
          trackId: trackId,
          offset: 100,
          start: 0,
          end: 96,
        );
        arrangement.clips[clip.id] = clip;

        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        firstPoint.value = 0.3;
        firstPoint.value = 0.4;
        firstPoint.value = 0.5;

        await _flushMicrotasks();

        final patternCompileVerification = verify(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
          ),
        );
        patternCompileVerification.called(1);

        final patternCompileCaptured = patternCompileVerification.captured;
        final patternTracksToRebuild = patternCompileCaptured[0] as List<Id>;

        expect(patternTracksToRebuild, equals(<Id>[-1]));

        final arrangementCompileVerification = verify(
          sequencerApi.compileArrangement(
            arrangement.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
          ),
        );
        arrangementCompileVerification.called(1);

        final arrangementCompileCaptured =
            arrangementCompileVerification.captured;
        final arrangementTracksToRebuild =
            arrangementCompileCaptured[0] as List<Id>;

        expect(arrangementTracksToRebuild, equals(<Id>[trackId]));

        clearInteractions(sequencerApi);

        await _waitForAutomationCompileDebounce();

        final trailingPatternCompileVerification = verify(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
          ),
        );
        trailingPatternCompileVerification.called(1);

        final trailingPatternCompileCaptured =
            trailingPatternCompileVerification.captured;
        final trailingPatternTracksToRebuild =
            trailingPatternCompileCaptured[0] as List<Id>;

        expect(trailingPatternTracksToRebuild, equals(<Id>[-1]));

        final trailingArrangementCompileVerification = verify(
          sequencerApi.compileArrangement(
            arrangement.id,
            tracksToRebuild: captureAnyNamed('tracksToRebuild'),
          ),
        );
        trailingArrangementCompileVerification.called(1);

        final trailingArrangementCompileCaptured =
            trailingArrangementCompileVerification.captured;
        final trailingArrangementTracksToRebuild =
            trailingArrangementCompileCaptured[0] as List<Id>;

        expect(trailingArrangementTracksToRebuild, equals(<Id>[trackId]));
      },
    );
  });

  group('Pattern note overrides', () {
    test(
      'update local note geometry and width without compiling the engine',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = ProjectModel.create()..engine = runningEngine;

        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Pattern Preview',
        );
        final note = NoteModel(
          idAllocator: _testIdAllocator(),
          key: 60,
          velocity: 0.75,
          length: 20,
          offset: 60,
          pan: 0,
        );
        pattern.notes[note.id] = note;
        project.sequence.patterns[pattern.id] = pattern;

        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        final initialClipAutoWidth = pattern.clipAutoWidth;
        final initialUpdateSignal = pattern.clipNotesUpdateSignal.value;

        pattern.setNoteOverride(noteId: note.id, offset: 500, length: 200);

        await _flushMicrotasks();

        final resolvedNote = pattern.resolveNoteById(note.id);
        expect(resolvedNote, isNotNull);
        expect(resolvedNote!.offset, equals(500));
        expect(resolvedNote.length, equals(200));
        expect(resolvedNote.hasOverride, isTrue);

        expect(pattern.clipAutoWidth, greaterThan(initialClipAutoWidth));
        expect(
          pattern.clipNotesUpdateSignal.value,
          isNot(equals(initialUpdateSignal)),
        );
        expect(pattern.clipNotesRenderCache.rawVertices, isNotNull);
        expect(pattern.clipNotesRenderCache.rawVertices![0], equals(500.0));
        expect(pattern.clipNotesRenderCache.rawVertices![2], equals(700.0));

        verifyNever(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: anyNamed('tracksToRebuild'),
            invalidationRanges: anyNamed('invalidationRanges'),
          ),
        );
        verifyNever(
          sequencerApi.compileArrangement(
            project.sequence.activeArrangementID!,
            tracksToRebuild: anyNamed('tracksToRebuild'),
            invalidationRanges: anyNamed('invalidationRanges'),
          ),
        );
      },
    );

    test(
      'preview-only notes update local geometry and width without compiling the engine',
      () async {
        final sequencerApi = _MockSequencerApi();
        final runningEngine = _RunningEngine(sequencerApi);
        final project = ProjectModel.create()..engine = runningEngine;

        final pattern = PatternModel(
          idAllocator: _testIdAllocator(),
          name: 'Pattern Preview',
        );
        project.sequence.patterns[pattern.id] = pattern;

        await _flushMicrotasks();
        clearInteractions(sequencerApi);

        final initialClipAutoWidth = pattern.clipAutoWidth;
        final initialUpdateSignal = pattern.clipNotesUpdateSignal.value;

        final previewNote = NoteModel(
          idAllocator: _testIdAllocator(),
          key: 64,
          velocity: 0.5,
          length: 240,
          offset: 520,
          pan: -0.25,
        );
        pattern.addPreviewNote(previewNote);

        await _flushMicrotasks();

        final resolvedNote = pattern.resolveNoteById(previewNote.id);
        expect(resolvedNote, isNotNull);
        expect(resolvedNote!.offset, equals(520));
        expect(resolvedNote.length, equals(240));
        expect(resolvedNote.isPreviewOnly, isTrue);

        expect(pattern.clipAutoWidth, greaterThan(initialClipAutoWidth));
        expect(
          pattern.clipNotesUpdateSignal.value,
          isNot(equals(initialUpdateSignal)),
        );
        expect(pattern.clipNotesRenderCache.rawVertices, isNotNull);
        expect(pattern.clipNotesRenderCache.rawVertices![0], equals(520.0));
        expect(pattern.clipNotesRenderCache.rawVertices![2], equals(760.0));

        verifyNever(
          sequencerApi.compilePattern(
            pattern.id,
            tracksToRebuild: anyNamed('tracksToRebuild'),
            invalidationRanges: anyNamed('invalidationRanges'),
          ),
        );
        verifyNever(
          sequencerApi.compileArrangement(
            project.sequence.activeArrangementID!,
            tracksToRebuild: anyNamed('tracksToRebuild'),
            invalidationRanges: anyNamed('invalidationRanges'),
          ),
        );
      },
    );
  });

  group('Pattern title atlas state', () {
    test('clears the atlas rect when the pattern name changes', () async {
      final project = ProjectModel.create();
      final pattern = PatternModel(
        idAllocator: _testIdAllocator(),
        name: 'Pattern Title',
      );
      project.sequence.patterns[pattern.id] = pattern;

      await _flushMicrotasks();

      project.sequence.clipTitleAtlasEntriesByPatternId[pattern.id] =
          const PackedTextureEntry(
            atlasIndex: 0,
            rect: ui.Rect.fromLTWH(10, 20, 30, 40),
          );

      pattern.name = 'Renamed Pattern Title';
      await _flushMicrotasks();

      expect(
        project.sequence.clipTitleAtlasEntriesByPatternId[pattern.id],
        isNull,
      );
    });
  });
}
