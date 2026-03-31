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
import 'package:anthem/model/shared/loop_points.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/state_machine/timeline_state_machine.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _RecordingSequencerApi implements SequencerApi {
  final List<double> jumpedTo = [];

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
  void updateLoopPoints(Id sequenceId) {}
}

class _TimelineTestEngine extends Mock implements Engine {
  final Stream<EngineState> _engineStateStream =
      const Stream<EngineState>.empty();
  final _RecordingSequencerApi _sequencerApi;
  final bool _isRunning;

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
}

ProjectEntityIdAllocator _testIdAllocator([Id Function()? allocateId]) {
  return ProjectEntityIdAllocator.test(allocateId ?? getId);
}

class _TimelineControllerTestFixture {
  static const viewSize = Size(800, 38);
  static const timeViewStart = 0.0;
  static const timeViewEnd = 960.0;

  final ProjectModel project;
  final PatternModel pattern;
  final TimelineController controller;
  final _RecordingSequencerApi sequencerApi;
  final _TimelineTestEngine engine;

  _TimelineControllerTestFixture._({
    required this.project,
    required this.pattern,
    required this.controller,
    required this.sequencerApi,
    required this.engine,
  });

  factory _TimelineControllerTestFixture.create({bool engineRunning = false}) {
    final project = ProjectModel.create();
    final sequencerApi = _RecordingSequencerApi();
    final engine = _TimelineTestEngine(sequencerApi, isRunning: engineRunning);
    project.engine = engine;
    project.engineState = engineRunning
        ? EngineState.running
        : EngineState.stopped;

    final pattern = PatternModel(
      idAllocator: _testIdAllocator(),
      name: 'Pattern 1',
    );
    project.sequence.patterns[pattern.id] = pattern;
    project.sequence.setActivePattern(pattern.id);

    final controller = TimelineController(
      project: project,
      arrangementID: null,
      patternID: pattern.id,
    );

    return _TimelineControllerTestFixture._(
      project: project,
      pattern: pattern,
      controller: controller,
      sequencerApi: sequencerApi,
      engine: engine,
    );
  }

  void syncRenderedView() {
    controller.onViewSizeChanged(viewSize);
    controller.onRenderedTimeViewChanged(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
    );
  }

  double pointerXForTime(double time) {
    return timeToPixels(
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      viewPixelWidth: viewSize.width,
      time: time,
    );
  }

  int expectedPlayheadTargetTime(double rawTime, {required bool ignoreSnap}) {
    return controller.resolveTimelineTime(
      rawTime: rawTime,
      ignoreSnap: ignoreSnap,
      viewWidthInPixels: viewSize.width,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      round: true,
    );
  }

  int expectedLoopTargetTime(
    double rawTime, {
    required bool ignoreSnap,
    int startTime = 0,
  }) {
    return controller.resolveTimelineTime(
      rawTime: rawTime,
      ignoreSnap: ignoreSnap,
      viewWidthInPixels: viewSize.width,
      timeViewStart: timeViewStart,
      timeViewEnd: timeViewEnd,
      round: true,
      startTime: startTime,
    );
  }

  LoopPointsModel? get loopPoints => pattern.loopPoints;

  void setLoopPoints(int start, int end) {
    pattern.loopPoints = LoopPointsModel(start, end);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimelineController Step 7 routing', () {
    late _TimelineControllerTestFixture fixture;

    setUp(() {
      fixture = _TimelineControllerTestFixture.create();
    });

    tearDown(() {
      fixture.controller.dispose();
    });

    test('pointer routing enters and exits the pointer session state', () {
      final controller = fixture.controller;

      controller.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(10, 6),
          buttons: kPrimaryButton,
        ),
      );

      expect(
        controller.stateMachine.currentState,
        isA<TimelinePointerSessionState>(),
      );
      expect(controller.stateMachine.data.activePointerId, 1);
      expect(controller.stateMachine.data.activePointerButtons, kPrimaryButton);

      controller.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(24, 12),
          buttons: kPrimaryButton,
        ),
      );

      final pointerSessionState =
          controller.stateMachine.currentState as TimelinePointerSessionState;
      expect(
        pointerSessionState.dragStartPosition?.toOffset(),
        const Offset(10, 6),
      );
      expect(
        pointerSessionState.dragCurrentPosition?.toOffset(),
        const Offset(24, 12),
      );

      controller.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(24, 12)),
      );

      expect(controller.stateMachine.currentState, isA<TimelineIdleState>());
      expect(controller.stateMachine.data.activePointerId, isNull);
      expect(controller.stateMachine.data.activeInteractionFamily, isNull);
    });

    test('modifier and rendered-view routing update machine data', () {
      final controller = fixture.controller;

      controller.syncModifierState(
        ctrlPressed: true,
        altPressed: false,
        shiftPressed: true,
      );
      controller.onViewSizeChanged(const Size(800, 38));
      controller.onRenderedTimeViewChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
      );

      final data = controller.stateMachine.data;
      expect(data.isCtrlPressed, isTrue);
      expect(data.isAltPressed, isFalse);
      expect(data.isShiftPressed, isTrue);
      expect(data.viewSize, const Size(800, 38));
      expect(data.renderedTimeViewStart, 120);
      expect(data.renderedTimeViewEnd, 1080);
    });

    test(
      'pointer-down pressed-loop-handle metadata syncs into pointer session and clears on cancel',
      () {
        final controller = fixture.controller;

        controller.pointerDown(
          const PointerDownEvent(
            pointer: 7,
            position: Offset(32, 5),
            buttons: kPrimaryButton,
          ),
          pressedLoopHandle: TimelineLoopHandle.end,
        );

        final loopHandleMoveState =
            controller.stateMachine.currentState as TimelineLoopHandleMoveState;
        expect(loopHandleMoveState.pressedLoopHandle, TimelineLoopHandle.end);
        expect(
          controller.stateMachine.data.activePressedLoopHandle,
          TimelineLoopHandle.end,
        );

        controller.pointerCancel(
          const PointerCancelEvent(pointer: 7, position: Offset(32, 5)),
        );

        expect(controller.stateMachine.currentState, isA<TimelineIdleState>());
        expect(controller.stateMachine.data.activePressedLoopHandle, isNull);
        expect(controller.stateMachine.data.activePointerId, isNull);
      },
    );
  });

  group('TimelineController Step 8 playhead drag', () {
    late _TimelineControllerTestFixture fixture;

    setUp(() {
      fixture = _TimelineControllerTestFixture.create();
      fixture.syncRenderedView();
    });

    tearDown(() {
      fixture.controller.dispose();
    });

    test(
      'beginning playhead drag enters the playhead state and updates playback start',
      () {
        final controller = fixture.controller;
        const downTime = 145.2;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(downTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          controller.stateMachine.currentState,
          isA<TimelinePlayheadDragState>(),
        );
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.playheadDrag,
        );
        expect(
          fixture.project.sequence.activeTransportSequenceID,
          fixture.pattern.id,
        );
        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(downTime, ignoreSnap: false),
        );
      },
    );

    test(
      'pointer move and alt changes update playback start while playhead drag is active',
      () {
        final controller = fixture.controller;
        const downTime = 145.2;
        const moveTime = 193.7;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(downTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        controller.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(moveTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: false),
        );

        controller.syncModifierState(
          ctrlPressed: false,
          altPressed: true,
          shiftPressed: false,
        );

        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: true),
        );
      },
    );

    test(
      'additional pointer downs are ignored while playhead drag is active',
      () {
        final controller = fixture.controller;
        const initialDownTime = 145.2;
        const ignoredDownTime = 320.4;
        const moveTime = 193.7;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(initialDownTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(
            initialDownTime,
            ignoreSnap: false,
          ),
        );
        expect(controller.stateMachine.data.activePointerId, 1);

        controller.pointerDown(
          PointerDownEvent(
            pointer: 2,
            position: Offset(fixture.pointerXForTime(ignoredDownTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          controller.stateMachine.currentState,
          isA<TimelinePlayheadDragState>(),
        );
        expect(controller.stateMachine.data.activePointerId, 1);
        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(
            initialDownTime,
            ignoreSnap: false,
          ),
        );

        controller.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(moveTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(moveTime, ignoreSnap: false),
        );

        controller.pointerUp(
          PointerUpEvent(
            pointer: 2,
            position: Offset(fixture.pointerXForTime(ignoredDownTime), 24),
          ),
        );

        expect(
          controller.stateMachine.currentState,
          isA<TimelinePlayheadDragState>(),
        );
        expect(controller.stateMachine.data.activePointerId, 1);

        controller.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(moveTime), 24),
          ),
        );

        expect(controller.stateMachine.currentState, isA<TimelineIdleState>());
      },
    );

    test('pointer up clears playhead jump dedup state for the next drag', () {
      fixture.controller.dispose();
      fixture = _TimelineControllerTestFixture.create(engineRunning: true);
      fixture.syncRenderedView();

      final controller = fixture.controller;
      const downTime = 145.2;
      final expectedTargetTime = fixture
          .expectedPlayheadTargetTime(downTime, ignoreSnap: false)
          .toDouble();

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(downTime), 24),
          buttons: kPrimaryButton,
        ),
      );
      controller.pointerUp(
        PointerUpEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(downTime), 24),
        ),
      );

      controller.pointerDown(
        PointerDownEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(downTime), 24),
          buttons: kPrimaryButton,
        ),
      );

      expect(
        fixture.sequencerApi.jumpedTo,
        equals([expectedTargetTime, expectedTargetTime]),
      );
    });

    test(
      'pointer cancel clears playhead jump dedup state for the next drag',
      () {
        fixture.controller.dispose();
        fixture = _TimelineControllerTestFixture.create(engineRunning: true);
        fixture.syncRenderedView();

        final controller = fixture.controller;
        const downTime = 145.2;
        final expectedTargetTime = fixture
            .expectedPlayheadTargetTime(downTime, ignoreSnap: false)
            .toDouble();

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(downTime), 24),
            buttons: kPrimaryButton,
          ),
        );
        controller.pointerCancel(
          PointerCancelEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(downTime), 24),
          ),
        );

        controller.pointerDown(
          PointerDownEvent(
            pointer: 2,
            position: Offset(fixture.pointerXForTime(downTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          fixture.sequencerApi.jumpedTo,
          equals([expectedTargetTime, expectedTargetTime]),
        );
      },
    );
  });

  group('TimelineController Step 9 loop create', () {
    late _TimelineControllerTestFixture fixture;

    setUp(() {
      fixture = _TimelineControllerTestFixture.create();
      fixture.syncRenderedView();
      fixture.controller.syncModifierState(
        ctrlPressed: true,
        altPressed: false,
        shiftPressed: false,
      );
    });

    tearDown(() {
      fixture.controller.dispose();
    });

    test(
      'beginning loop create enters the loop-create state, captures the anchor time, and clears existing loop points when alt is not pressed',
      () {
        fixture.setLoopPoints(192, 384);

        final controller = fixture.controller;
        const startTime = 355.8;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            buttons: kPrimaryButton,
          ),
        );

        final loopCreateState =
            controller.stateMachine.currentState as TimelineLoopCreateState;
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.loopCreate,
        );
        expect(loopCreateState.startTime, isNotNull);
        expect(
          loopCreateState.startTime,
          fixture.expectedLoopTargetTime(startTime, ignoreSnap: false),
        );
        expect(fixture.loopPoints, isNull);
      },
    );

    test(
      'pointer move and alt changes update loop points while loop create is active',
      () {
        final controller = fixture.controller;
        const startTime = 355.8;
        const endTime = 140.1;
        final expectedStart = fixture.expectedLoopTargetTime(
          endTime,
          ignoreSnap: false,
        );
        final expectedEnd = fixture.expectedLoopTargetTime(
          startTime,
          ignoreSnap: false,
        );

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            buttons: kPrimaryButton,
          ),
        );

        controller.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(endTime), 5),
            buttons: kPrimaryButton,
          ),
        );

        expect(fixture.loopPoints, isNotNull);
        expect(fixture.loopPoints!.start, expectedStart);
        expect(fixture.loopPoints!.end, expectedEnd);

        controller.syncModifierState(
          ctrlPressed: false,
          altPressed: true,
          shiftPressed: false,
        );

        expect(fixture.loopPoints, isNotNull);
        expect(fixture.loopPoints!.start, endTime.round());
        expect(
          fixture.loopPoints!.end,
          fixture.expectedLoopTargetTime(startTime, ignoreSnap: false),
        );
      },
    );

    test('zero-width loop create clears loop points', () {
      fixture.setLoopPoints(192, 384);

      final controller = fixture.controller;
      const startTime = 355.8;

      controller.syncModifierState(
        ctrlPressed: true,
        altPressed: true,
        shiftPressed: false,
      );
      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(startTime), 5),
          buttons: kPrimaryButton,
        ),
      );

      controller.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(startTime), 5),
          buttons: kPrimaryButton,
        ),
      );

      expect(fixture.loopPoints, isNull);
    });

    test('pointer up exits loop create back to idle', () {
      final controller = fixture.controller;

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(220), 5),
          buttons: kPrimaryButton,
        ),
      );
      controller.pointerUp(
        PointerUpEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(420), 5),
        ),
      );

      expect(controller.stateMachine.currentState, isA<TimelineIdleState>());
      expect(controller.stateMachine.data.activeInteractionFamily, isNull);
    });
  });

  group('TimelineController Step 10 loop-handle drag', () {
    late _TimelineControllerTestFixture fixture;

    setUp(() {
      fixture = _TimelineControllerTestFixture.create();
      fixture.syncRenderedView();
      fixture.setLoopPoints(192, 384);
    });

    tearDown(() {
      fixture.controller.dispose();
    });

    test(
      'beginning loop-handle move enters the loop-handle state and captures the pressed handle',
      () {
        final controller = fixture.controller;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(192), 5),
            buttons: kPrimaryButton,
          ),
          pressedLoopHandle: TimelineLoopHandle.start,
        );

        final loopHandleMoveState =
            controller.stateMachine.currentState as TimelineLoopHandleMoveState;
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.loopHandleMove,
        );
        expect(loopHandleMoveState.activeHandle, TimelineLoopHandle.start);
        expect(loopHandleMoveState.originalHandleTime, 192);
      },
    );

    test(
      'start-handle drag updates only the start bound and alt changes re-resolve it mid-drag',
      () {
        final controller = fixture.controller;
        const moveTime = 121.4;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(192), 5),
            buttons: kPrimaryButton,
          ),
          pressedLoopHandle: TimelineLoopHandle.start,
        );

        controller.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(moveTime), 5),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          fixture.loopPoints!.start,
          fixture.expectedLoopTargetTime(
            moveTime,
            ignoreSnap: false,
            startTime: 192,
          ),
        );
        expect(fixture.loopPoints!.end, 384);

        controller.syncModifierState(
          ctrlPressed: false,
          altPressed: true,
          shiftPressed: false,
        );

        expect(
          fixture.loopPoints!.start,
          fixture.expectedLoopTargetTime(
            moveTime,
            ignoreSnap: true,
            startTime: 192,
          ),
        );
        expect(fixture.loopPoints!.end, 384);
      },
    );

    test('end-handle drag updates only the end bound', () {
      final controller = fixture.controller;
      const moveTime = 515.6;

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(384), 5),
          buttons: kPrimaryButton,
        ),
        pressedLoopHandle: TimelineLoopHandle.end,
      );

      controller.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(moveTime), 5),
          buttons: kPrimaryButton,
        ),
      );

      expect(fixture.loopPoints!.start, 192);
      expect(
        fixture.loopPoints!.end,
        fixture.expectedLoopTargetTime(
          moveTime,
          ignoreSnap: false,
          startTime: 384,
        ),
      );
    });

    test('invalid handle crossing is ignored', () {
      final controller = fixture.controller;
      const moveTime = 420.0;

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(192), 5),
          buttons: kPrimaryButton,
        ),
        pressedLoopHandle: TimelineLoopHandle.start,
      );

      controller.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(moveTime), 5),
          buttons: kPrimaryButton,
        ),
      );

      expect(fixture.loopPoints!.start, 192);
      expect(fixture.loopPoints!.end, 384);
    });
  });

  group('TimelineController Step 11 automatic classification', () {
    late _TimelineControllerTestFixture fixture;

    setUp(() {
      fixture = _TimelineControllerTestFixture.create();
      fixture.syncRenderedView();
    });

    tearDown(() {
      fixture.controller.dispose();
    });

    test(
      'pointer down below the loop bar automatically starts playhead drag',
      () {
        final controller = fixture.controller;
        const downTime = 145.2;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(downTime), 24),
            buttons: kPrimaryButton,
          ),
        );

        expect(
          controller.stateMachine.currentState,
          isA<TimelinePlayheadDragState>(),
        );
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.playheadDrag,
        );
        expect(
          fixture.project.sequence.activeTransportSequenceID,
          fixture.pattern.id,
        );
        expect(
          fixture.project.sequence.playbackStartPosition,
          fixture.expectedPlayheadTargetTime(downTime, ignoreSnap: false),
        );
      },
    );

    test(
      'double-click in the loop bar automatically starts loop create on the second press',
      () {
        final controller = fixture.controller;
        const startTime = 120.0;
        const firstDownTimestamp = Duration(milliseconds: 100);
        const firstUpTimestamp = Duration(milliseconds: 120);
        const secondDownTimestamp = Duration(milliseconds: 220);

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            buttons: kPrimaryButton,
            timeStamp: firstDownTimestamp,
          ),
        );
        expect(
          controller.stateMachine.data.activePointerIsDoubleClick,
          isFalse,
        );
        expect(
          controller.stateMachine.currentState,
          isA<TimelinePointerSessionState>(),
        );
        controller.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            timeStamp: firstUpTimestamp,
          ),
        );

        controller.pointerDown(
          PointerDownEvent(
            pointer: 2,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            buttons: kPrimaryButton,
            timeStamp: secondDownTimestamp,
          ),
        );
        expect(controller.stateMachine.data.activePointerIsDoubleClick, isTrue);

        final loopCreateState =
            controller.stateMachine.currentState as TimelineLoopCreateState;
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.loopCreate,
        );
        expect(loopCreateState.startTime, isNotNull);
        expect(
          loopCreateState.startTime,
          fixture.expectedLoopTargetTime(startTime, ignoreSnap: false),
        );
        expect(
          fixture.project.sequence.activeTransportSequenceID,
          fixture.pattern.id,
        );
      },
    );

    test(
      'double-click in the loop bar requires the second press to stay near the first click',
      () {
        final controller = fixture.controller;
        const firstTime = 120.0;
        const secondTime = 320.0;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(firstTime), 5),
            buttons: kPrimaryButton,
            timeStamp: Duration(milliseconds: 100),
          ),
        );
        controller.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(firstTime), 5),
            timeStamp: Duration(milliseconds: 120),
          ),
        );

        controller.pointerDown(
          PointerDownEvent(
            pointer: 2,
            position: Offset(fixture.pointerXForTime(secondTime), 5),
            buttons: kPrimaryButton,
            timeStamp: Duration(milliseconds: 220),
          ),
        );

        expect(
          controller.stateMachine.data.activePointerIsDoubleClick,
          isFalse,
        );
        expect(
          controller.stateMachine.currentState,
          isA<TimelinePointerSessionState>(),
        );
        expect(controller.stateMachine.data.activeInteractionFamily, isNull);
      },
    );

    test(
      'secondary presses clear pending primary double-click qualification',
      () {
        final controller = fixture.controller;
        const clickTime = 120.0;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(clickTime), 5),
            buttons: kPrimaryButton,
            timeStamp: Duration(milliseconds: 100),
          ),
        );
        controller.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(clickTime), 5),
            timeStamp: Duration(milliseconds: 120),
          ),
        );

        controller.pointerDown(
          const PointerDownEvent(
            pointer: 2,
            position: Offset(80, 24),
            buttons: kSecondaryButton,
            timeStamp: Duration(milliseconds: 220),
          ),
        );
        controller.pointerUp(
          const PointerUpEvent(
            pointer: 2,
            position: Offset(80, 24),
            timeStamp: Duration(milliseconds: 240),
          ),
        );

        controller.pointerDown(
          PointerDownEvent(
            pointer: 3,
            position: Offset(fixture.pointerXForTime(clickTime), 5),
            buttons: kPrimaryButton,
            timeStamp: Duration(milliseconds: 320),
          ),
        );

        expect(
          controller.stateMachine.data.activePointerIsDoubleClick,
          isFalse,
        );
        expect(
          controller.stateMachine.currentState,
          isA<TimelinePointerSessionState>(),
        );
        expect(controller.stateMachine.data.activeInteractionFamily, isNull);
      },
    );

    test('primary drags clear pending primary double-click qualification', () {
      final controller = fixture.controller;
      const initialClickTime = 120.0;
      const dragDownTime = 320.0;
      const dragMoveTime = 420.0;

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(initialClickTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 100),
        ),
      );
      controller.pointerUp(
        PointerUpEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(initialClickTime), 5),
          timeStamp: Duration(milliseconds: 120),
        ),
      );

      controller.pointerDown(
        PointerDownEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(dragDownTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 220),
        ),
      );
      controller.pointerMove(
        PointerMoveEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(dragMoveTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 260),
        ),
      );
      controller.pointerUp(
        PointerUpEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(dragMoveTime), 5),
          timeStamp: Duration(milliseconds: 300),
        ),
      );

      controller.pointerDown(
        PointerDownEvent(
          pointer: 3,
          position: Offset(fixture.pointerXForTime(initialClickTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 360),
        ),
      );

      expect(controller.stateMachine.data.activePointerIsDoubleClick, isFalse);
      expect(
        controller.stateMachine.currentState,
        isA<TimelinePointerSessionState>(),
      );
      expect(controller.stateMachine.data.activeInteractionFamily, isNull);
    });

    test('double-click does not chain to a third rapid primary press', () {
      final controller = fixture.controller;
      const clickTime = 120.0;

      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(clickTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 100),
        ),
      );
      controller.pointerUp(
        PointerUpEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(clickTime), 5),
          timeStamp: Duration(milliseconds: 120),
        ),
      );

      controller.pointerDown(
        PointerDownEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(clickTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 220),
        ),
      );
      expect(controller.stateMachine.data.activePointerIsDoubleClick, isTrue);
      controller.pointerUp(
        PointerUpEvent(
          pointer: 2,
          position: Offset(fixture.pointerXForTime(clickTime), 5),
          timeStamp: Duration(milliseconds: 240),
        ),
      );

      controller.pointerDown(
        PointerDownEvent(
          pointer: 3,
          position: Offset(fixture.pointerXForTime(clickTime), 5),
          buttons: kPrimaryButton,
          timeStamp: Duration(milliseconds: 320),
        ),
      );

      expect(controller.stateMachine.data.activePointerIsDoubleClick, isFalse);
      expect(
        controller.stateMachine.currentState,
        isA<TimelinePointerSessionState>(),
      );
      expect(controller.stateMachine.data.activeInteractionFamily, isNull);
    });

    test(
      'secondary click in the loop bar automatically starts loop create',
      () {
        final controller = fixture.controller;
        const startTime = 320.4;
        const endTime = 470.2;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(startTime), 5),
            buttons: kSecondaryButton,
          ),
        );
        controller.pointerMove(
          PointerMoveEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(endTime), 5),
            buttons: kSecondaryButton,
          ),
        );

        expect(
          controller.stateMachine.currentState,
          isA<TimelineLoopCreateState>(),
        );
        expect(
          fixture.project.sequence.activeTransportSequenceID,
          fixture.pattern.id,
        );
        expect(fixture.loopPoints, isNotNull);
        expect(
          fixture.loopPoints!.start,
          fixture.expectedLoopTargetTime(startTime, ignoreSnap: false),
        );
        expect(
          fixture.loopPoints!.end,
          fixture.expectedLoopTargetTime(endTime, ignoreSnap: false),
        );
      },
    );

    test('ctrl-primary loop bar press automatically starts loop create', () {
      final controller = fixture.controller;
      const startTime = 355.8;
      const endTime = 140.1;

      controller.syncModifierState(
        ctrlPressed: true,
        altPressed: false,
        shiftPressed: false,
      );
      controller.pointerDown(
        PointerDownEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(startTime), 5),
          buttons: kPrimaryButton,
        ),
      );
      controller.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          position: Offset(fixture.pointerXForTime(endTime), 5),
          buttons: kPrimaryButton,
        ),
      );

      expect(
        controller.stateMachine.currentState,
        isA<TimelineLoopCreateState>(),
      );
      expect(
        fixture.project.sequence.activeTransportSequenceID,
        fixture.pattern.id,
      );
      expect(fixture.loopPoints, isNotNull);
      expect(
        fixture.loopPoints!.start,
        fixture.expectedLoopTargetTime(endTime, ignoreSnap: false),
      );
      expect(
        fixture.loopPoints!.end,
        fixture.expectedLoopTargetTime(startTime, ignoreSnap: false),
      );
    });

    test(
      'pressed loop-handle metadata automatically starts loop-handle drag on pointer down',
      () {
        fixture.setLoopPoints(192, 384);
        final controller = fixture.controller;

        controller.pointerDown(
          PointerDownEvent(
            pointer: 1,
            position: Offset(fixture.pointerXForTime(192), 5),
            buttons: kPrimaryButton,
          ),
          pressedLoopHandle: TimelineLoopHandle.start,
        );

        final loopHandleMoveState =
            controller.stateMachine.currentState as TimelineLoopHandleMoveState;
        expect(
          controller.stateMachine.data.activeInteractionFamily,
          TimelineInteractionFamily.loopHandleMove,
        );
        expect(loopHandleMoveState.activeHandle, TimelineLoopHandle.start);
        expect(loopHandleMoveState.originalHandleTime, 192);
        expect(
          fixture.project.sequence.activeTransportSequenceID,
          fixture.pattern.id,
        );
      },
    );
  });
}
