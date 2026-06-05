import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerClipResizeState', () {
    Id addPattern({int clipAutoWidth = 96}) {
      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Pattern',
      );
      pattern.clipAutoWidth = clipAutoWidth;
      fixture.project.sequence.patterns[pattern.id] = pattern;
      return pattern.id;
    }

    ClipModel addClip({
      required int offset,
      required Id trackId,
      required Rect rect,
      required Rect resizeHandleRect,
      required ResizeAreaType resizeAreaType,
      TimeViewModel? timeView,
      int fallbackPatternWidth = 96,
    }) {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: addPattern(clipAutoWidth: fallbackPatternWidth),
        trackId: trackId,
        offset: offset,
        timeView: timeView,
      );
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);
      fixture.viewModel.visibleResizeAreas.add(
        rect: resizeHandleRect,
        metadata: (id: clip.id, type: resizeAreaType),
      );
      return clip;
    }

    void startClipResize({required Offset downPos, required Offset movePos}) {
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

    test('dragging from resize handle delegates to clip resize state', () {
      final clip = addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(96, 10, 14, 40),
        resizeAreaType: ResizeAreaType.start,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(102, 20),
        movePos: const Offset(118, 20),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipResizeState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
    });

    test(
      'dragging automation clip content resize handle delegates to resize',
      () {
        fixture.showRealAutomationLaneForTrack(TrackIds.a);
        final clip = addClip(
          offset: 100,
          trackId: TrackIds.automationA,
          rect: const Rect.fromLTWH(100, 0, 96, 60),
          resizeHandleRect: const Rect.fromLTWH(190, 16, 14, 44),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(192, 38),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.selectedClips, {ClipIds.someOtherSelected});

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(220, 38),
          ),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);
        expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
      },
    );

    test(
      'dragging automation tension handle over resize handle does not resize',
      () {
        fixture.showRealAutomationLaneForTrack(TrackIds.a);
        final clip = addClip(
          offset: 100,
          trackId: TrackIds.automationA,
          rect: const Rect.fromLTWH(100, 0, 96, 60),
          resizeHandleRect: const Rect.fromLTWH(190, 16, 14, 44),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 96),
        );
        fixture.viewModel.visibleAutomationHandles.add(
          rect: const Rect.fromLTWH(184, 30, 16, 16),
          metadata: AutomationHandleAnnotation(
            clipId: clip.id,
            kind: AutomationHandleKind.tensionHandle,
            pointIndex: 0,
            pointId: 900,
            center: const Offset(192, 38),
          ),
        );

        startClipResize(
          downPos: const Offset(192, 38),
          movePos: const Offset(220, 38),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipTimingOverrides[clip.id], isNull);
      },
    );

    test('clip resize overrides the global cursor until release', () {
      addClip(
        offset: 100,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(100, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(196, 10, 14, 40),
        resizeAreaType: ResizeAreaType.end,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(202, 20),
        movePos: const Offset(220, 20),
      );

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        SystemMouseCursors.resizeLeftRight,
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 20)),
      );

      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        MouseCursor.defer,
      );
    });

    test(
      'start resize creates time view for clip without time view and commits via undoable command',
      () {
        final clip = addClip(
          offset: 80,
          trackId: TrackIds.a,
          rect: const Rect.fromLTWH(80, 10, 64, 40),
          resizeHandleRect: const Rect.fromLTWH(76, 10, 14, 40),
          resizeAreaType: ResizeAreaType.start,
          timeView: null,
          fallbackPatternWidth: 64,
        );

        fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
        startClipResize(
          downPos: const Offset(82, 20),
          movePos: const Offset(92, 20),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        final inProgressOverride =
            fixture.viewModel.clipTimingOverrides[clip.id]!;
        expect(inProgressOverride.offset, equals(90));
        expect(inProgressOverride.timeViewStart, equals(10));
        expect(inProgressOverride.timeViewEnd, equals(64));

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(92, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(clip.offset, equals(90));
        expect(clip.timeView, isNotNull);
        expect(clip.timeView!.start, equals(10));
        expect(clip.timeView!.end, equals(64));

        fixture.project.undo();

        expect(clip.offset, equals(80));
        expect(clip.timeView, isNull);
      },
    );

    test(
      'end resize on selected clips snaps and blocks next snap when it would make a clip non-positive',
      () {
        final snapSize = fixture.stateMachine
            .divisionChanges()
            .first
            .divisionSnapSize;
        final largeClip = addClip(
          offset: 100,
          trackId: TrackIds.a,
          rect: const Rect.fromLTWH(100, 10, 100, 40),
          resizeHandleRect: const Rect.fromLTWH(194, 10, 14, 40),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: 100),
        );
        final smallClipWidth = snapSize + 2;
        final smallClip = addClip(
          offset: 260,
          trackId: TrackIds.b,
          rect: Rect.fromLTWH(260, 70, smallClipWidth.toDouble(), 40),
          resizeHandleRect: Rect.fromLTWH(
            260 + smallClipWidth.toDouble() - 6,
            70,
            14,
            40,
          ),
          resizeAreaType: ResizeAreaType.end,
          timeView: TimeViewModel(start: 0, end: smallClipWidth),
        );

        fixture.viewModel.selectedClips.addAll({largeClip.id, smallClip.id});

        startClipResize(
          downPos: const Offset(198, 20),
          movePos: Offset(198 - (snapSize * 3).toDouble(), 20),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerClipResizeState>(),
        );
        final largeOverride =
            fixture.viewModel.clipTimingOverrides[largeClip.id]!;
        final smallOverride =
            fixture.viewModel.clipTimingOverrides[smallClip.id]!;
        final largeWidth =
            largeOverride.timeViewEnd - largeOverride.timeViewStart;
        final smallWidth =
            smallOverride.timeViewEnd - smallOverride.timeViewStart;

        expect(smallWidth, equals(2));
        expect(largeWidth, equals(100 - snapSize));

        fixture.pointerUp(
          PointerUpEvent(
            pointer: 1,
            position: Offset(198 - (snapSize * 3).toDouble(), 20),
          ),
        );

        expect(
          largeClip.timeView!.end - largeClip.timeView!.start,
          equals(100 - snapSize),
        );
        expect(smallClip.timeView!.end - smallClip.timeView!.start, equals(2));

        fixture.project.undo();
        expect(
          largeClip.timeView!.end - largeClip.timeView!.start,
          equals(100),
        );
        expect(
          smallClip.timeView!.end - smallClip.timeView!.start,
          equals(smallClipWidth),
        );
      },
    );

    test('snapped end resize applies one snap interval', () {
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      expect(snapSize, greaterThan(0));

      final clip = addClip(
        offset: 120,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(120, 10, 240, 40),
        resizeHandleRect: const Rect.fromLTWH(354, 10, 14, 40),
        resizeAreaType: ResizeAreaType.end,
        timeView: TimeViewModel(start: 0, end: 240),
      );

      const downX = 358.0;
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

      expect(fixture.stateMachine.currentState, isA<ArrangerClipResizeState>());
      expect(
        fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewEnd -
            fixture.viewModel.clipTimingOverrides[clip.id]!.timeViewStart,
        240 + snapSize,
      );
    });

    test('pointer cancel does not commit clip resize', () {
      final clip = addClip(
        offset: 120,
        trackId: TrackIds.a,
        rect: const Rect.fromLTWH(120, 10, 96, 40),
        resizeHandleRect: const Rect.fromLTWH(210, 10, 14, 40),
        resizeAreaType: ResizeAreaType.end,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      startClipResize(
        downPos: const Offset(214, 20),
        movePos: const Offset(180, 20),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerClipResizeState>());
      expect(fixture.viewModel.clipTimingOverrides[clip.id], isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(180, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(clip.offset, equals(120));
      expect(clip.timeView!.start, equals(0));
      expect(clip.timeView!.end, equals(96));
      expect(fixture.viewModel.clipTimingOverrides, isEmpty);
    });
  });
}
