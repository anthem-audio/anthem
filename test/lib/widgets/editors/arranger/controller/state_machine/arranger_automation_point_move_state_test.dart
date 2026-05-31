import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerAutomationPointMoveState', () {
    const clipRect = Rect.fromLTWH(100, 0, 240, 60);
    const contentRect = Rect.fromLTWH(100, 16, 240, 44);

    AutomationPointModel makePoint({
      required int offset,
      required double value,
    }) {
      return AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: offset,
        value: value,
      );
    }

    ({ClipModel clip, PatternModel pattern}) addAutomationClip({
      int clipOffset = 100,
      TimeViewModel? timeView,
      List<AutomationPointModel>? points,
    }) {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Automation',
      );
      pattern.automation.points.addAll(
        points ??
            [
              makePoint(offset: 0, value: 0.25),
              makePoint(offset: 240, value: 0.75),
            ],
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: pattern.id,
        trackId: TrackIds.automationA,
        offset: clipOffset,
        timeView: timeView ?? TimeViewModel(start: 0, end: 240),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      arrangement.clips[clip.id] = clip;

      fixture.viewModel.visibleClips.add(rect: clipRect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    void startAutomationDoubleClickHold(Offset pos) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: pos,
        ),
      );
      fixture.pointerUp(PointerUpEvent(pointer: 1, position: pos));
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: pos,
        ),
      );
    }

    int expectedPointOffsetForClick({
      required ClipModel clip,
      required Offset pos,
      required bool snap,
    }) {
      final rawArrangementTime = pixelsToTime(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: pos.dx,
      ).round();
      final arrangementTime = snap
          ? getSnappedTime(
              rawTime: rawArrangementTime,
              divisionChanges: fixture.stateMachine.divisionChanges(),
              round: true,
            )
          : rawArrangementTime;
      final clipTimeViewStart = clip.timeView?.start ?? 0;
      final clipTimeViewEnd = clip.timeView?.end ?? clip.width;

      return (arrangementTime - clip.offset + clipTimeViewStart)
          .clamp(clipTimeViewStart, clipTimeViewEnd)
          .toInt();
    }

    double expectedPointValueForClick(Offset pos) {
      return (1 - (pos.dy - contentRect.top) / contentRect.height).clamp(
        0.0,
        1.0,
      );
    }

    double pointCenterX({required ClipModel clip, required int pointOffset}) {
      return timeToPixels(
        time: (clip.offset + pointOffset - (clip.timeView?.start ?? 0))
            .toDouble(),
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
      );
    }

    Offset pointCenter({
      required ClipModel clip,
      required AutomationPointModel point,
    }) {
      return Offset(
        pointCenterX(clip: clip, pointOffset: point.offset),
        contentRect.top + (1 - point.value) * contentRect.height,
      );
    }

    void addHandleAnnotation({
      required ClipModel clip,
      required PatternModel pattern,
      required int pointIndex,
      AutomationHandleKind kind = AutomationHandleKind.point,
      Rect? rect,
    }) {
      final point = pattern.automation.points[pointIndex];
      final center = pointCenter(clip: clip, point: point);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: rect ?? Rect.fromCenter(center: center, width: 16, height: 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: kind,
          pointIndex: pointIndex,
          pointId: point.id,
          center: center,
        ),
      );
    }

    test('double-clicking automation clip content adds a snapped point', () {
      final (:clip, :pattern) = addAutomationClip();
      const clickPos = Offset(147, 38);
      final expectedOffset = expectedPointOffsetForClick(
        clip: clip,
        pos: clickPos,
        snap: true,
      );
      final expectedValue = expectedPointValueForClick(clickPos);
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);
      fixture.viewModel.lastInteractedAutomationTension = 0.35;

      startAutomationDoubleClickHold(clickPos);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, expectedOffset);
      expect(pattern.automation.points[1].value, closeTo(expectedValue, 1e-9));
      expect(pattern.automation.points[1].tension, 0.35);
      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));

      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: clickPos));

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, expectedOffset);

      fixture.project.undo();
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);
    });

    test('alt double-click adds an unsnapped point', () {
      final (:clip, :pattern) = addAutomationClip();
      const clickPos = Offset(147, 38);
      final expectedOffset = expectedPointOffsetForClick(
        clip: clip,
        pos: clickPos,
        snap: false,
      );

      fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
      startAutomationDoubleClickHold(clickPos);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );
      expect(pattern.automation.points[1].offset, expectedOffset);
    });

    test('double-clicking automation clip title does not add a point', () {
      final automationClip = addAutomationClip();
      final pattern = automationClip.pattern;
      const titlePos = Offset(147, 8);

      startAutomationDoubleClickHold(titlePos);

      expect(
        fixture.stateMachine.currentState,
        isNot(isA<ArrangerAutomationPointMoveState>()),
      );
      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: titlePos));
      expect(pattern.automation.points, hasLength(2));
    });

    test('drag after add moves the new point and commits one undo step', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      const clickPos = Offset(147, 38);
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      final movePos = Offset(clickPos.dx + snapSize, clickPos.dy - 11);

      startAutomationDoubleClickHold(clickPos);
      final startOffset = pattern.automation.points[1].offset;
      final startValue = pattern.automation.points[1].value;
      final dragStartX = pointCenterX(
        clip: automationClip.clip,
        pointOffset: startOffset,
      );
      final dragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: dragStartX,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, 240 + dragDelta);

      fixture.pointerUp(PointerUpEvent(pointer: 1, position: movePos));

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(pattern.automation.points[2].offset, 240 + dragDelta);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);

      fixture.project.redo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(pattern.automation.points[2].offset, 240 + dragDelta);
    });

    test('snapped drag after add uses created point center as drag origin', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      const clickPos = Offset(147, 38);

      startAutomationDoubleClickHold(clickPos);
      final startOffset = pattern.automation.points[1].offset;
      final dragStartX = pointCenterX(
        clip: automationClip.clip,
        pointOffset: startOffset,
      );
      expect(dragStartX, isNot(clickPos.dx));
      final movePos = Offset(dragStartX + snapSize / 2, clickPos.dy);
      final centerDragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: dragStartX,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );
      final rawPointerDragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: clickPos.dx,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );
      expect(centerDragDelta, isNot(rawPointerDragDelta));

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        pattern.automation.points[1].offset,
        startOffset + centerDragDelta,
      );
    });

    test('dragging an existing point moves it and later points', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.5),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final clip = automationClip.clip;
      final pattern = automationClip.pattern;
      addHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);

      final point = pattern.automation.points[1];
      final downPos = pointCenter(clip: clip, point: point);
      final startOffset = point.offset;
      final startValue = point.value;
      final laterStartOffset = pattern.automation.points[2].offset;
      final snapSize = fixture.stateMachine
          .divisionChanges()
          .first
          .divisionSnapSize;
      final movePos = Offset(
        downPos.dx + snapSize,
        downPos.dy - contentRect.height * 0.25,
      );
      final dragDelta = getSnappedDragDelta(
        startTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: downPos.dx,
        ).round(),
        currentTime: pixelsToTime(
          timeViewStart: fixture.viewModel.timeRange.start,
          timeViewEnd: fixture.viewModel.timeRange.end,
          viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
          pixelOffsetFromLeft: movePos.dx,
        ).round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
      );

      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: downPos,
        ),
      );
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationPointMoveState>(),
      );

      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, laterStartOffset + dragDelta);

      fixture.pointerUp(PointerUpEvent(pointer: 1, position: movePos));

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);

      fixture.project.redo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset + dragDelta);
      expect(
        pattern.automation.points[1].value,
        closeTo(startValue + 0.25, 1e-9),
      );
      expect(pattern.automation.points[2].offset, laterStartOffset + dragDelta);
    });

    test('canceling an existing point drag restores transient edits', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.5),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final clip = automationClip.clip;
      final pattern = automationClip.pattern;
      addHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);

      final point = pattern.automation.points[1];
      final downPos = pointCenter(clip: clip, point: point);
      final startOffset = point.offset;
      final startValue = point.value;
      final laterStartOffset = pattern.automation.points[2].offset;
      final movePos = Offset(downPos.dx + 64, downPos.dy - 11);

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

      expect(pattern.automation.points[1].offset, isNot(startOffset));
      expect(pattern.automation.points[1].value, isNot(startValue));
      expect(pattern.automation.points[2].offset, isNot(laterStartOffset));

      fixture.pointerUp(PointerCancelEvent(pointer: 1, position: movePos));

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[1].offset, startOffset);
      expect(pattern.automation.points[1].value, startValue);
      expect(pattern.automation.points[2].offset, laterStartOffset);
    });

    test('pointer cancel removes the transient point without undo history', () {
      final automationClip = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 240, value: 0.75),
        ],
      );
      final pattern = automationClip.pattern;
      const clickPos = Offset(147, 38);

      startAutomationDoubleClickHold(clickPos);
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(210, 28),
        ),
      );
      expect(pattern.automation.points, hasLength(3));
      expect(pattern.automation.points[2].offset, isNot(240));

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(210, 28)),
      );

      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);

      fixture.project.undo();

      expect(pattern.automation.points, hasLength(2));
      expect(pattern.automation.points[0].offset, 0);
      expect(pattern.automation.points[1].offset, 240);
    });
  });
}
