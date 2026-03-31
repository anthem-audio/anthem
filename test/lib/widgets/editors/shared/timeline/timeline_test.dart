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
import 'package:anthem/helpers/project_entity_id_allocator.dart';
import 'package:anthem/model/arrangement/arrangement.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/shared/time_signature.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/editors/shared/timeline/timeline.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

enum _TimelineTargetKind { pattern, arrangement }

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

class _RecordingSequencerApi implements SequencerApi {
  final List<double> jumpedTo = [];
  final List<Id> updatedLoopPointSequences = [];

  @override
  void cleanUpTrack(Id trackId) {}

  @override
  void compileArrangement(
    Id arrangementId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void compilePattern(
    Id patternId, {
    List<Id>? tracksToRebuild,
    List<InvalidationRange>? invalidationRanges,
  }) {}

  @override
  void jumpPlayheadTo(double offset) {
    jumpedTo.add(offset);
  }

  @override
  void updateLoopPoints(Id sequenceId) {
    updatedLoopPointSequences.add(sequenceId);
  }
}

class _TimelineTestEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();
  final _RecordingSequencerApi _sequencerApi;
  bool _isRunning;

  _TimelineTestEngine(this._sequencerApi, {bool isRunning = false})
    : _isRunning = isRunning;

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<EngineState> get engineStateStream => _engineStateStream;

  @override
  SequencerApi get sequencerApi => _sequencerApi;

  @override
  Future<void> dispose() async {}

  void setRunning(bool isRunning) {
    _isRunning = isRunning;
  }
}

class _TimelineTestFixture {
  static const timelineKey = Key('timeline-under-test');
  static const viewSize = Size(800, 38);

  final _TimelineTargetKind targetKind;
  final ProjectModel project;
  final PatternModel pattern;
  final ArrangementModel arrangement;
  final KeyboardModifiers keyboardModifiers = KeyboardModifiers();
  final TimeRange timeView;
  final _RecordingSequencerApi sequencerApi;
  final _TimelineTestEngine engine;
  final AnimationController animationController;
  final Animation<double> timeViewStartAnimation;
  final Animation<double> timeViewEndAnimation;

  _TimelineTestFixture._({
    required this.targetKind,
    required this.project,
    required this.pattern,
    required this.arrangement,
    required this.timeView,
    required this.sequencerApi,
    required this.engine,
    required this.animationController,
    required this.timeViewStartAnimation,
    required this.timeViewEndAnimation,
  });

  factory _TimelineTestFixture.create({
    required _TimelineTargetKind targetKind,
    bool engineRunning = false,
  }) {
    final project = ProjectModel.create();
    final sequencerApi = _RecordingSequencerApi();
    final engine = _TimelineTestEngine(sequencerApi, isRunning: engineRunning);
    project.engine = engine;
    project.engineState = engineRunning
        ? EngineState.running
        : EngineState.stopped;

    final arrangement =
        project.sequence.arrangements[project.sequence.activeArrangementID]!;
    final pattern = PatternModel(
      idAllocator: _testIdAllocator(),
      name: 'Pattern 1',
    );
    project.sequence.patterns[pattern.id] = pattern;
    project.sequence.setActivePattern(pattern.id);

    project.sequence.activeTransportSequenceID = switch (targetKind) {
      _TimelineTargetKind.pattern => pattern.id,
      _TimelineTargetKind.arrangement => arrangement.id,
    };
    project.sequence.playbackStartPosition = 0;

    final timeView = TimeRange(0, 960);
    final animationController = AnimationController(
      vsync: const TestVSync(),
      duration: Duration.zero,
      value: 1,
    );

    return _TimelineTestFixture._(
      targetKind: targetKind,
      project: project,
      pattern: pattern,
      arrangement: arrangement,
      timeView: timeView,
      sequencerApi: sequencerApi,
      engine: engine,
      animationController: animationController,
      timeViewStartAnimation: AlwaysStoppedAnimation(timeView.start),
      timeViewEndAnimation: AlwaysStoppedAnimation(timeView.end),
    );
  }

  Id get sequenceId => switch (targetKind) {
    _TimelineTargetKind.pattern => pattern.id,
    _TimelineTargetKind.arrangement => arrangement.id,
  };

  LoopPointsModel? get loopPoints => switch (targetKind) {
    _TimelineTargetKind.pattern => pattern.loopPoints,
    _TimelineTargetKind.arrangement => arrangement.loopPoints,
  };

  List<TimeSignatureChangeModel> get timeSignatureChanges =>
      switch (targetKind) {
        _TimelineTargetKind.pattern => pattern.timeSignatureChanges,
        _TimelineTargetKind.arrangement => arrangement.timeSignatureChanges,
      };

  void setLoopPoints(int start, int end) {
    final points = LoopPointsModel(start, end);

    switch (targetKind) {
      case _TimelineTargetKind.pattern:
        pattern.loopPoints = points;
      case _TimelineTargetKind.arrangement:
        arrangement.loopPoints = points;
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProjectModel>.value(value: project),
          Provider<TimeRange>.value(value: timeView),
          ChangeNotifierProvider<KeyboardModifiers>.value(
            value: keyboardModifiers,
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: timelineKey,
              width: viewSize.width,
              height: viewSize.height,
              child: switch (targetKind) {
                _TimelineTargetKind.pattern => Timeline.pattern(
                  patternID: pattern.id,
                  timeViewAnimationController: animationController,
                  timeViewStartAnimation: timeViewStartAnimation,
                  timeViewEndAnimation: timeViewEndAnimation,
                ),
                _TimelineTargetKind.arrangement => Timeline.arrangement(
                  arrangementID: arrangement.id,
                  timeViewAnimationController: animationController,
                  timeViewStartAnimation: timeViewStartAnimation,
                  timeViewEndAnimation: timeViewEndAnimation,
                ),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> setModifiers(
    WidgetTester tester, {
    bool? ctrl,
    bool? alt,
    bool? shift,
  }) async {
    if (ctrl != null) {
      keyboardModifiers.setCtrl(ctrl);
    }
    if (alt != null) {
      keyboardModifiers.setAlt(alt);
    }
    if (shift != null) {
      keyboardModifiers.setShift(shift);
    }
    await tester.pump();
  }

  Offset globalPositionForLocal(WidgetTester tester, Offset localPosition) {
    return tester.getTopLeft(find.byKey(timelineKey)) + localPosition;
  }

  Offset localPositionForTime(double time, {required double y}) {
    return Offset(
      timeToPixels(
        timeViewStart: timeView.start,
        timeViewEnd: timeView.end,
        viewPixelWidth: viewSize.width,
        time: time,
      ),
      y,
    );
  }

  Offset loopBarPositionForTime(double time) {
    return localPositionForTime(time, y: loopAreaHeight / 2);
  }

  Offset playheadPositionForTime(double time) {
    return localPositionForTime(time, y: loopAreaHeight + 8);
  }

  Offset loopStartHandlePosition() {
    final points = loopPoints!;
    return loopBarPositionForTime(points.start.toDouble());
  }

  Offset loopEndHandlePosition() {
    final points = loopPoints!;
    return loopBarPositionForTime(points.end.toDouble());
  }

  Future<TestGesture> createMouseGesture(
    WidgetTester tester, {
    int buttons = kPrimaryMouseButton,
  }) {
    return tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: buttons,
    );
  }

  int snappedTime(int rawTime, {bool round = false, int startTime = 0}) {
    return getSnappedTime(
      rawTime: rawTime,
      divisionChanges: getDivisionChanges(
        viewWidthInPixels: viewSize.width,
        snap: AutoSnap(),
        defaultTimeSignature: project.sequence.defaultTimeSignature,
        timeSignatureChanges: timeSignatureChanges,
        ticksPerQuarter: project.sequence.ticksPerQuarter,
        timeViewStart: timeView.start,
        timeViewEnd: timeView.end,
        minPixelsPerSection: minorMinPixels,
      ),
      round: round,
      startTime: startTime,
    );
  }

  int expectedPlayheadTargetTime(double rawTime, {required bool ignoreSnap}) {
    final clampedTime = rawTime < 0 ? 0 : rawTime;
    if (ignoreSnap) {
      return clampedTime.round();
    }

    return snappedTime(clampedTime.toInt(), round: true);
  }

  int expectedLoopTargetTime(
    double rawTime, {
    required bool ignoreSnap,
    int startTime = 0,
  }) {
    final clampedTime = rawTime < 0 ? 0 : rawTime;
    if (ignoreSnap) {
      return clampedTime.round();
    }

    return snappedTime(clampedTime.toInt(), round: true, startTime: startTime);
  }

  void dispose() {
    animationController.dispose();
    project.visualizationProvider.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('timeline fixture', () {
    testWidgets('pumps a pattern timeline target', (tester) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.pattern,
      );
      addTearDown(fixture.dispose);

      await fixture.pump(tester);

      expect(find.byKey(_TimelineTestFixture.timelineKey), findsOneWidget);
      expect(fixture.sequenceId, equals(fixture.pattern.id));
      expect(fixture.loopPoints, isNull);
    });

    testWidgets('pumps an arrangement timeline target', (tester) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.arrangement,
      );
      addTearDown(fixture.dispose);

      await fixture.pump(tester);

      expect(find.byKey(_TimelineTestFixture.timelineKey), findsOneWidget);
      expect(fixture.sequenceId, equals(fixture.arrangement.id));
      expect(fixture.loopPoints, isNull);
    });
  });

  group('playhead drag', () {
    testWidgets(
      'pattern timeline drag activates the transport target and updates playback start',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        const downTime = 145.2;
        const moveTime = 333.4;
        final gesture = await fixture.createMouseGesture(tester);
        await gesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(downTime),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(moveTime),
          ),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(
          fixture.project.sequence.activeTransportSequenceID,
          equals(fixture.pattern.id),
        );
        expect(
          fixture.project.sequence.playbackStartPosition,
          equals(
            fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: false),
          ),
        );
      },
    );

    testWidgets(
      'running engine deduplicates playhead jumps in the same snap bucket',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
          engineRunning: true,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        const downTime = 145.2;
        const sameSnapMoveTime = 146.1;
        const nextSnapMoveTime = 193.7;
        final gesture = await fixture.createMouseGesture(tester);
        await gesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(downTime),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(sameSnapMoveTime),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(nextSnapMoveTime),
          ),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(
          fixture.sequencerApi.jumpedTo,
          equals([
            fixture
                .expectedPlayheadTargetTime(downTime, ignoreSnap: false)
                .toDouble(),
            fixture
                .expectedPlayheadTargetTime(nextSnapMoveTime, ignoreSnap: false)
                .toDouble(),
          ]),
        );
      },
    );

    testWidgets('alt changes mid-drag re-resolve the playhead without snap', (
      tester,
    ) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.pattern,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);

      const downTime = 145.2;
      const moveTime = 193.7;
      final gesture = await fixture.createMouseGesture(tester);
      await gesture.down(
        fixture.globalPositionForLocal(
          tester,
          fixture.playheadPositionForTime(downTime),
        ),
      );
      await tester.pump();
      await gesture.moveTo(
        fixture.globalPositionForLocal(
          tester,
          fixture.playheadPositionForTime(moveTime),
        ),
      );
      await tester.pump();

      expect(
        fixture.project.sequence.playbackStartPosition,
        equals(fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: false)),
      );

      await fixture.setModifiers(tester, alt: true);

      expect(
        fixture.project.sequence.playbackStartPosition,
        equals(fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: true)),
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
      'pointer up clears playhead drag state so a later loop create works',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        const playheadMoveTime = 280.4;
        final playheadGesture = await fixture.createMouseGesture(tester);
        await playheadGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(120),
          ),
        );
        await tester.pump();
        await playheadGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(playheadMoveTime),
          ),
        );
        await tester.pump();
        await playheadGesture.up();
        await tester.pump();

        final expectedPlayheadPosition = fixture.expectedPlayheadTargetTime(
          playheadMoveTime,
          ignoreSnap: false,
        );

        await fixture.setModifiers(tester, ctrl: true);
        final loopGesture = await fixture.createMouseGesture(tester);
        await loopGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(420.5),
          ),
        );
        await tester.pump();
        await loopGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(610.2),
          ),
        );
        await tester.pump();
        await loopGesture.up();
        await tester.pump();

        expect(
          fixture.project.sequence.playbackStartPosition,
          equals(expectedPlayheadPosition),
        );
        expect(fixture.loopPoints, isNotNull);
      },
    );

    testWidgets(
      'pointer cancel after playhead drag clears state so a later loop create works',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        const playheadMoveTime = 280.4;
        final playheadGesture = await fixture.createMouseGesture(tester);
        await playheadGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(120),
          ),
        );
        await tester.pump();
        await playheadGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(playheadMoveTime),
          ),
        );
        await tester.pump();
        await playheadGesture.cancel();
        await tester.pump();

        final expectedPlayheadPosition = fixture.expectedPlayheadTargetTime(
          playheadMoveTime,
          ignoreSnap: false,
        );

        await fixture.setModifiers(tester, ctrl: true);
        final loopGesture = await fixture.createMouseGesture(tester);
        await loopGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(420.5),
          ),
        );
        await tester.pump();
        await loopGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(610.2),
          ),
        );
        await tester.pump();
        await loopGesture.up();
        await tester.pump();

        expect(
          fixture.project.sequence.playbackStartPosition,
          equals(expectedPlayheadPosition),
        );
        expect(fixture.loopPoints, isNotNull);
      },
    );
  });

  group('loop create', () {
    testWidgets(
      'ctrl-primary loop drag on arrangement creates snapped loop points and activates the target',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.arrangement,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        await fixture.setModifiers(tester, ctrl: true);
        const startTime = 355.8;
        const endTime = 140.1;
        final gesture = await fixture.createMouseGesture(tester);
        await gesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(startTime),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(endTime),
          ),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        final expectedStart = fixture.expectedLoopTargetTime(
          endTime,
          ignoreSnap: false,
        );
        final expectedEnd = fixture.expectedLoopTargetTime(
          startTime,
          ignoreSnap: false,
        );

        expect(
          fixture.project.sequence.activeTransportSequenceID,
          equals(fixture.arrangement.id),
        );
        expect(fixture.loopPoints, isNotNull);
        expect(fixture.loopPoints!.start, equals(expectedStart));
        expect(fixture.loopPoints!.end, equals(expectedEnd));
      },
    );

    testWidgets(
      'secondary-click loop drag creates snapped loop points on the real widget path',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        const startTime = 320.4;
        const endTime = 470.2;
        final gesture = await fixture.createMouseGesture(
          tester,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(startTime),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(endTime),
          ),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(
          fixture.project.sequence.activeTransportSequenceID,
          equals(fixture.pattern.id),
        );
        expect(fixture.loopPoints, isNotNull);
        expect(
          fixture.loopPoints!.start,
          equals(fixture.expectedLoopTargetTime(startTime, ignoreSnap: false)),
        );
        expect(
          fixture.loopPoints!.end,
          equals(fixture.expectedLoopTargetTime(endTime, ignoreSnap: false)),
        );
      },
    );

    testWidgets(
      'double-click in the loop bar starts loop creation on a pattern target',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        final gesture = await fixture.createMouseGesture(tester);
        final firstClickPosition = fixture.globalPositionForLocal(
          tester,
          fixture.loopBarPositionForTime(120),
        );

        await gesture.down(firstClickPosition);
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(fixture.loopPoints, isNull);

        const dragEndTime = 260.7;
        await gesture.down(firstClickPosition);
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(dragEndTime),
          ),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(fixture.loopPoints, isNotNull);
        expect(
          fixture.loopPoints!.start,
          equals(fixture.expectedLoopTargetTime(120, ignoreSnap: false)),
        );
        expect(
          fixture.loopPoints!.end,
          equals(
            fixture.expectedLoopTargetTime(dragEndTime, ignoreSnap: false),
          ),
        );
      },
    );

    testWidgets('alt changes mid-drag re-resolve loop create without snap', (
      tester,
    ) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.arrangement,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);

      await fixture.setModifiers(tester, ctrl: true);
      const startTime = 355.8;
      const endTime = 140.1;
      final gesture = await fixture.createMouseGesture(tester);
      await gesture.down(
        fixture.globalPositionForLocal(
          tester,
          fixture.loopBarPositionForTime(startTime),
        ),
      );
      await tester.pump();
      await gesture.moveTo(
        fixture.globalPositionForLocal(
          tester,
          fixture.loopBarPositionForTime(endTime),
        ),
      );
      await tester.pump();

      expect(
        fixture.loopPoints!.start,
        equals(fixture.expectedLoopTargetTime(endTime, ignoreSnap: false)),
      );
      expect(
        fixture.loopPoints!.end,
        equals(fixture.expectedLoopTargetTime(startTime, ignoreSnap: false)),
      );

      await fixture.setModifiers(tester, alt: true);

      expect(fixture.loopPoints!.start, equals(endTime.round()));
      expect(
        fixture.loopPoints!.end,
        equals(fixture.expectedLoopTargetTime(startTime, ignoreSnap: false)),
      );

      await gesture.up();
      await tester.pump();
    });

    testWidgets(
      'pointer up after loop creation clears create state so a later handle drag works',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.arrangement,
        );
        addTearDown(fixture.dispose);
        fixture.setLoopPoints(192, 384);
        await fixture.pump(tester);

        await fixture.setModifiers(tester, ctrl: true);
        final loopCreateGesture = await fixture.createMouseGesture(tester);
        await loopCreateGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(120),
          ),
        );
        await tester.pump();
        await loopCreateGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(300),
          ),
        );
        await tester.pump();
        await loopCreateGesture.up();
        await tester.pump();
        await fixture.setModifiers(tester, ctrl: false);
        final createdLoopEnd = fixture.loopPoints!.end;

        final newEndTime = 430.2;
        final handleGesture = await fixture.createMouseGesture(tester);
        await handleGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopEndHandlePosition(),
          ),
        );
        await tester.pump();
        await handleGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(newEndTime),
          ),
        );
        await tester.pump();
        await handleGesture.up();
        await tester.pump();

        expect(
          fixture.loopPoints!.end,
          equals(
            fixture.expectedLoopTargetTime(
              newEndTime,
              ignoreSnap: false,
              startTime: createdLoopEnd,
            ),
          ),
        );
      },
    );

    testWidgets(
      'pointer cancel after loop creation clears state so a later playhead drag works',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.arrangement,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);

        await fixture.setModifiers(tester, ctrl: true);
        final loopCreateGesture = await fixture.createMouseGesture(tester);
        await loopCreateGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(120),
          ),
        );
        await tester.pump();
        await loopCreateGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(300),
          ),
        );
        await tester.pump();
        await loopCreateGesture.cancel();
        await tester.pump();

        await fixture.setModifiers(tester, ctrl: false);
        const playheadMoveTime = 520.8;
        final playheadGesture = await fixture.createMouseGesture(tester);
        await playheadGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(440.2),
          ),
        );
        await tester.pump();
        await playheadGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.playheadPositionForTime(playheadMoveTime),
          ),
        );
        await tester.pump();
        await playheadGesture.up();
        await tester.pump();

        expect(
          fixture.project.sequence.playbackStartPosition,
          equals(
            fixture.expectedPlayheadTargetTime(
              playheadMoveTime,
              ignoreSnap: false,
            ),
          ),
        );
      },
    );
  });

  group('loop handle drag', () {
    testWidgets('dragging the loop start handle updates only the start bound', (
      tester,
    ) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.arrangement,
      );
      addTearDown(fixture.dispose);
      fixture.setLoopPoints(192, 384);
      await fixture.pump(tester);

      const moveTime = 121.4;
      final gesture = await fixture.createMouseGesture(tester);
      await gesture.down(
        fixture.globalPositionForLocal(
          tester,
          fixture.loopStartHandlePosition(),
        ),
      );
      await tester.pump();
      await gesture.moveTo(
        fixture.globalPositionForLocal(
          tester,
          fixture.loopBarPositionForTime(moveTime),
        ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(
        fixture.loopPoints!.start,
        equals(
          fixture.expectedLoopTargetTime(
            moveTime,
            ignoreSnap: false,
            startTime: 192,
          ),
        ),
      );
      expect(fixture.loopPoints!.end, equals(384));
    });

    testWidgets(
      'alt changes mid-drag re-resolve the loop start handle without snap',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.arrangement,
        );
        addTearDown(fixture.dispose);
        fixture.setLoopPoints(192, 384);
        await fixture.pump(tester);

        const moveTime = 121.4;
        final gesture = await fixture.createMouseGesture(tester);
        await gesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopStartHandlePosition(),
          ),
        );
        await tester.pump();
        await gesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(moveTime),
          ),
        );
        await tester.pump();

        expect(
          fixture.loopPoints!.start,
          equals(
            fixture.expectedLoopTargetTime(
              moveTime,
              ignoreSnap: false,
              startTime: 192,
            ),
          ),
        );

        await fixture.setModifiers(tester, alt: true);

        expect(
          fixture.loopPoints!.start,
          equals(
            fixture.expectedLoopTargetTime(
              moveTime,
              ignoreSnap: true,
              startTime: 192,
            ),
          ),
        );
        expect(fixture.loopPoints!.end, equals(384));

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets('dragging the loop end handle updates only the end bound', (
      tester,
    ) async {
      final fixture = _TimelineTestFixture.create(
        targetKind: _TimelineTargetKind.pattern,
      );
      addTearDown(fixture.dispose);
      fixture.setLoopPoints(192, 384);
      await fixture.pump(tester);

      const moveTime = 515.6;
      final gesture = await fixture.createMouseGesture(tester);
      await gesture.down(
        fixture.globalPositionForLocal(tester, fixture.loopEndHandlePosition()),
      );
      await tester.pump();
      await gesture.moveTo(
        fixture.globalPositionForLocal(
          tester,
          fixture.loopBarPositionForTime(moveTime),
        ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(fixture.loopPoints!.start, equals(192));
      expect(
        fixture.loopPoints!.end,
        equals(
          fixture.expectedLoopTargetTime(
            moveTime,
            ignoreSnap: false,
            startTime: 384,
          ),
        ),
      );
    });

    testWidgets(
      'pointer cancel after loop-handle drag clears handle state so a later loop create works',
      (tester) async {
        final fixture = _TimelineTestFixture.create(
          targetKind: _TimelineTargetKind.pattern,
        );
        addTearDown(fixture.dispose);
        fixture.setLoopPoints(192, 384);
        await fixture.pump(tester);

        final handleGesture = await fixture.createMouseGesture(tester);
        await handleGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopStartHandlePosition(),
          ),
        );
        await tester.pump();
        await handleGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(144),
          ),
        );
        await tester.pump();
        await handleGesture.cancel();
        await tester.pump();

        await fixture.setModifiers(tester, ctrl: true);
        final createGesture = await fixture.createMouseGesture(tester);
        await createGesture.down(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(480),
          ),
        );
        await tester.pump();
        await createGesture.moveTo(
          fixture.globalPositionForLocal(
            tester,
            fixture.loopBarPositionForTime(660),
          ),
        );
        await tester.pump();
        await createGesture.up();
        await tester.pump();

        expect(
          fixture.loopPoints!.start,
          equals(fixture.expectedLoopTargetTime(480, ignoreSnap: false)),
        );
        expect(
          fixture.loopPoints!.end,
          equals(fixture.expectedLoopTargetTime(660, ignoreSnap: false)),
        );
      },
    );
  });
}
