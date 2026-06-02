import 'package:anthem/model/shared/time_signature.dart';

import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerClipMoveState', () {
    ClipModel addClip({
      required int offset,
      required Id trackId,
      required Rect rect,
    }) {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: getId(),
        trackId: trackId,
        offset: offset,
        timeView: TimeViewModel(start: 0, end: 96),
      );
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);
      return clip;
    }

    void startClipMove({
      Offset downPos = const Offset(120, 20),
      Offset movePos = const Offset(220, 100),
    }) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    test('pointer up commits clip move and preserves clip track', () {
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      startClipMove();
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      final expectedOffset =
          fixture.viewModel.clipTimingOverrides[clip.id]!.offset;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, expectedOffset);
      expect(clip.trackId, TrackIds.a);

      fixture.project.undo();

      expect(clip.offset, 100);
      expect(clip.trackId, TrackIds.a);
    });

    test('dragging automation clip content delegates to clip move', () {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.automationA,
        rect: const Rect.fromLTWH(100, 0, 240, 60),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(140, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, clip.id);
      expect(fixture.viewModel.selectedClips, {ClipIds.someOtherSelected});

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
      expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
    });

    test('dragging automation tension handle does not move clip', () {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.automationA,
        rect: const Rect.fromLTWH(100, 0, 240, 60),
      );
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(132, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 0,
          pointId: 900,
          center: const Offset(140, 38),
        ),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(140, 38),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 38),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNull);
    });

    test('pressed clip remains set from down through clip move transition', () {
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.pressedClip, clip.id);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 100),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.pressedClip, clip.id);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('moving selected clips is one undoable action', () {
      final firstClip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 240,
        trackId: TrackIds.b,
        rect: const Rect.fromLTWH(260, 70, 80, 40),
      );

      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      startClipMove(movePos: const Offset(260, 100));
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      final firstExpectedOffset =
          fixture.viewModel.clipTimingOverrides[firstClip.id]!.offset;
      final secondExpectedOffset =
          fixture.viewModel.clipTimingOverrides[secondClip.id]!.offset;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 100)),
      );

      expect(firstClip.offset, firstExpectedOffset);
      expect(secondClip.offset, secondExpectedOffset);
      expect(firstClip.trackId, TrackIds.a);
      expect(secondClip.trackId, TrackIds.b);

      fixture.project.undo();

      expect(firstClip.offset, 100);
      expect(secondClip.offset, 240);
      expect(firstClip.trackId, TrackIds.a);
      expect(secondClip.trackId, TrackIds.b);
    });

    test('snapped move applies one snap interval', () {
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      expect(snapSize, greaterThan(0));

      final clip = addClip(
        offset: 300,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(280, 10, 120, 40),
      );

      const downX = 320.0;
      int timeAtX(double x) => pixelsToTime(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: x,
      ).round();
      double xForTime(int time) => timeToPixels(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        time: time.toDouble(),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(downX, 20),
        ),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(xForTime(timeAtX(downX) + snapSize), 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(
        fixture.viewModel.clipTimingOverrides[clip.id]!.offset,
        300 + snapSize,
      );
    });

    test('shortcut snap nudge moves selected clips in time and undoes', () {
      final firstClip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 240,
        trackId: TrackIds.b,
        rect: const Rect.fromLTWH(260, 70, 80, 40),
      );
      final unselectedClip = addClip(
        offset: 360,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(380, 10, 80, 40),
      );
      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight),
      );

      expect(firstClip.offset, 100 + snapSize);
      expect(secondClip.offset, 240 + snapSize);
      expect(unselectedClip.offset, 360);
      expect(firstClip.trackId, TrackIds.a);
      expect(secondClip.trackId, TrackIds.b);
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({firstClip.id, secondClip.id}),
      );

      fixture.project.undo();
      expect(firstClip.offset, 100);
      expect(secondClip.offset, 240);

      fixture.project.redo();
      expect(firstClip.offset, 100 + snapSize);
      expect(secondClip.offset, 240 + snapSize);
    });

    test('shortcut snap nudge clamps selected clips at arrangement start', () {
      final firstClip = addClip(
        offset: 10,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(10, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 80,
        trackId: TrackIds.b,
        rect: const Rect.fromLTWH(80, 70, 80, 40),
      );
      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft),
      );

      expect(firstClip.offset, 0);
      expect(secondClip.offset, 70);
    });

    test('shortcut bar nudge moves selected clips by one default bar', () {
      final firstClip = addClip(
        offset: 96,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(96, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 192,
        trackId: TrackIds.b,
        rect: const Rect.fromLTWH(192, 70, 80, 40),
      );
      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      final barLength = getBarLength(
        fixture.project.sequence.ticksPerQuarter,
        fixture.project.sequence.defaultTimeSignature,
      );

      fixture.controller.onShortcut(
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.arrowRight,
        ),
      );

      expect(firstClip.offset, 96 + barLength);
      expect(secondClip.offset, 192 + barLength);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft),
      );

      expect(firstClip.offset, 96);
      expect(secondClip.offset, 192);
    });

    test('shortcut bar nudge uses the active time signature', () {
      final arrangement = fixture
          .project
          .sequence
          .arrangements[fixture.project.sequence.activeArrangementID]!;
      arrangement.timeSignatureChanges.add(
        TimeSignatureChangeModel(
          idAllocator: testIdAllocator(),
          offset: 384,
          timeSignature: TimeSignatureModel(3, 4),
        ),
      );
      final firstClip = addClip(
        offset: 384,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(384, 10, 80, 40),
      );
      final secondClip = addClip(
        offset: 480,
        trackId: TrackIds.b,
        rect: const Rect.fromLTWH(480, 70, 80, 40),
      );
      fixture.viewModel.selectedClips.addAll({firstClip.id, secondClip.id});

      fixture.controller.onShortcut(
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.arrowRight,
        ),
      );

      expect(firstClip.offset, 672);
      expect(secondClip.offset, 768);

      fixture.controller.onShortcut(
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowLeft),
      );

      expect(firstClip.offset, 384);
      expect(secondClip.offset, 480);
    });

    test(
      'shortcut bar nudge left uses the previous time signature at a change',
      () {
        final arrangement = fixture
            .project
            .sequence
            .arrangements[fixture.project.sequence.activeArrangementID]!;
        arrangement.timeSignatureChanges.add(
          TimeSignatureChangeModel(
            idAllocator: testIdAllocator(),
            offset: 384,
            timeSignature: TimeSignatureModel(3, 4),
          ),
        );
        final clip = addClip(
          offset: 384,
          trackId: TrackIds.a,
          rect: const Rect.fromLTWH(384, 10, 80, 40),
        );
        fixture.viewModel.selectedClips.add(clip.id);

        fixture.controller.onShortcut(
          LogicalKeySet(
            LogicalKeyboardKey.control,
            LogicalKeyboardKey.arrowLeft,
          ),
        );

        expect(clip.offset, 0);
      },
    );

    test('pointer cancel does not commit clip move', () {
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 80, 40),
      );

      startClipMove();
      expect(fixture.stateMachine.currentState, isA<ArrangerClipMoveState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(220, 100)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, 100);
      expect(clip.trackId, TrackIds.a);
      expect(fixture.viewModel.clipTimingOverrides, isEmpty);

      fixture.project.undo();
      expect(clip.offset, 100);
      expect(clip.trackId, TrackIds.a);
    });
  });
}
