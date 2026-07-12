import 'package:anthem/widgets/editors/arranger/rendering/clip_content_visibility.dart';

import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerIdleState', () {
    ({ClipModel clip, PatternModel pattern}) addVisibleAutomationClip({
      Id clipId = ClipIds.underCursor,
      Rect rect = const Rect.fromLTWH(110, 15, 40, 45),
    }) {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Automation',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: testIdAllocator(() => clipId),
        patternId: pattern.id,
        trackId: TrackIds.automationA,
        offset: 100,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;
      fixture.viewModel.visibleClips.add(rect: rect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    test('hover over track updates cursor location', () {
      fixture.hover(const Offset(120, 20));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        TrackIds.a,
      );
    });

    test('hover over phantom automation lane updates cursor location', () {
      fixture.showPhantomAutomationLaneForTrack(TrackIds.a);

      fixture.hover(const Offset(120, 80));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        phantomParentTrackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        TrackIds.a,
      );
    });

    test('hover over real automation lane updates cursor location', () {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      fixture.hover(const Offset(120, 80));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        TrackIds.automationA,
      );
    });

    test('hover outside track clears cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(fixture.viewModel.hoveredClip, isNull);

      fixture.hover(const Offset(120, -10));

      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test(
      'hover over clip sets hovered clip and keeps canvas cursor as defer',
      () {
        fixture.hover(const Offset(80, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
        expect(fixture.viewModel.hoveredClip, isNull);

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 40, 30),
          metadata: ClipIds.underCursor,
        );

        fixture.hover(const Offset(120, 20));

        expect(fixture.viewModel.mouseCursor, MouseCursor.defer);
        expect(fixture.viewModel.hoverIndicatorPosition, isNull);
        expect(fixture.viewModel.hoveredClip, ClipIds.underCursor);
      },
    );

    test('hover over clip-adjacent divider does not show cursor location', () {
      final trackPosition = fixture.viewModel.trackPositionCalculator
          .getTrackPosition(0);
      final trackHeight = fixture.viewModel.trackPositionCalculator
          .getTrackHeight(0);
      final dividerY = trackPosition + trackHeight - 1;

      fixture.viewModel.visibleClips.add(
        rect: Rect.fromLTRB(110, trackPosition, 150, dividerY),
        metadata: ClipIds.underCursor,
      );

      expect(
        fixture.viewModel.trackPositionCalculator.rowAtPosition(dividerY),
        isNull,
      );
      final borderIncludedHit = fixture.viewModel.trackPositionCalculator
          .rowAtPosition(dividerY, includeBorder: true);
      expect(borderIncludedHit, isNotNull);
      expect(borderIncludedHit!.rowIndex, 0);

      fixture.hover(Offset(120, dividerY - 1));
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, ClipIds.underCursor);

      fixture.hover(Offset(120, dividerY));
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test('hover on first pixel of next row uses next row', () {
      final nextTrackPosition = fixture.viewModel.trackPositionCalculator
          .getTrackPosition(1);

      final borderIncludedHit = fixture.viewModel.trackPositionCalculator
          .rowAtPosition(nextTrackPosition, includeBorder: true);
      expect(borderIncludedHit, isNotNull);
      expect(borderIncludedHit!.rowIndex, 1);

      fixture.hover(Offset(120, nextTrackPosition));

      final cursorLocation = fixture.viewModel.hoverIndicatorPosition;
      expect(cursorLocation, isNotNull);
      expect(
        trackIdForRowId(fixture.viewModel, cursorLocation!.rowId),
        TrackIds.b,
      );
    });

    test('hover over automation clip content shows automation handles', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();

      fixture.hover(const Offset(120, 20));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);

      fixture.hover(const Offset(120, 38));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.hover(const Offset(120, 20));
      expect(fixture.stateMachine.currentState, same(fixture.idleState));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
    });

    test(
      'pressing automation point handle keeps handle hover visual state',
      () {
        final (:clip, :pattern) = addVisibleAutomationClip();
        final point = AutomationPointModel(
          idAllocator: testIdAllocator(() => 900),
          offset: 0,
          value: 0.5,
        );
        pattern.automation.points.add(point);
        fixture.viewModel.visibleAutomationHandles.add(
          rect: const Rect.fromLTWH(112, 30, 16, 16),
          metadata: AutomationHandleAnnotation(
            clipId: clip.id,
            kind: AutomationHandleKind.point,
            pointIndex: 0,
            pointId: point.id,
            center: const Offset(120, 38),
          ),
        );

        fixture.hover(const Offset(120, 38));

        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointId: point.id,
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(120, 38),
          ),
        );

        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointId: point.id,
        );

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
        );

        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointId: point.id,
        );

        fixture.exit(const Offset(-1, -1));

        expect(fixture.viewModel.hoveredAutomationHandle, isNull);
      },
    );

    test(
      'pressing automation tension handle keeps handle hover visual state',
      () {
        final (:clip, :pattern) = addVisibleAutomationClip();
        final previousPoint = AutomationPointModel(
          idAllocator: testIdAllocator(),
          offset: 0,
          value: 0.25,
        );
        final point = AutomationPointModel(
          idAllocator: testIdAllocator(() => 900),
          offset: 96,
          value: 0.75,
        );
        pattern.automation.points.addAll([previousPoint, point]);
        fixture.viewModel.visibleAutomationHandles.add(
          rect: const Rect.fromLTWH(112, 30, 16, 16),
          metadata: AutomationHandleAnnotation(
            clipId: clip.id,
            kind: AutomationHandleKind.tensionHandle,
            pointIndex: 1,
            pointId: point.id,
            center: const Offset(120, 38),
          ),
        );

        fixture.hover(const Offset(120, 38));
        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointId: point.id,
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(120, 38),
          ),
        );

        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointId: point.id,
        );

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
        );

        expectAutomationHandle(
          fixture.viewModel.hoveredAutomationHandle,
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointId: point.id,
        );
      },
    );

    test('clicking automation clip title selects the clip', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 20)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
    });

    test('clicking automation clip content selects the clip', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);
    });

    test('clicking automation point handle preserves clip selection', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final point = AutomationPointModel(
        idAllocator: testIdAllocator(() => 900),
        offset: 0,
        value: 0.5,
      );
      pattern.automation.points.add(point);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointIndex: 0,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      fixture.hover(const Offset(120, 38));
      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({ClipIds.someOtherSelected}),
      );
      expect(fixture.viewModel.selectedClips.contains(clip.id), isFalse);
    });

    test('clicking automation tension handle selects the clip', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 0,
          pointId: 900,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(fixture.viewModel.selectedClips.toSet(), equals({clip.id}));
    });

    test('right-clicking automation tension handle resets tension', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final previousPoint = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final point = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 96,
        value: 0.75,
        tension: 0.4,
      );
      pattern.automation.points.addAll([previousPoint, point]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(openCount, 0);
      expect(point.tension, 0);
      expect(fixture.viewModel.lastInteractedAutomationTension, 0);
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({ClipIds.someOtherSelected}),
      );

      fixture.project.undo();

      expect(point.tension, 0.4);
    });

    test('double-clicking automation tension handle resets tension', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final previousPoint = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final point = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 96,
        value: 0.75,
        tension: 0.4,
      );
      pattern.automation.points.addAll([previousPoint, point]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: 1,
          pointId: point.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(point.tension, 0);
      expect(fixture.viewModel.lastInteractedAutomationTension, 0);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);

      fixture.project.undo();
      expect(point.tension, 0.4);
    });

    test('double-clicking automation point handle deletes the point', () {
      final (:clip, :pattern) = addVisibleAutomationClip();
      final firstPoint = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 0,
        value: 0.25,
      );
      final deletedPoint = AutomationPointModel(
        idAllocator: testIdAllocator(() => 900),
        offset: 48,
        value: 0.5,
        tension: 0.2,
      );
      final lastPoint = AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: 96,
        value: 0.75,
      );
      pattern.automation.points.addAll([firstPoint, deletedPoint, lastPoint]);
      fixture.viewModel.visibleAutomationHandles.add(
        rect: const Rect.fromLTWH(112, 30, 16, 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.point,
          pointIndex: 1,
          pointId: deletedPoint.id,
          center: const Offset(120, 38),
        ),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 38),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(120, 38)),
      );

      expect(pattern.automation.points, [firstPoint, lastPoint]);
      expect(fixture.viewModel.selectedClips, {ClipIds.someOtherSelected});
      expect(fixture.viewModel.hoveredAutomationHandle, isNull);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);

      fixture.project.undo();
      expect(pattern.automation.points, [firstPoint, deletedPoint, lastPoint]);

      fixture.project.redo();
      expect(pattern.automation.points, [firstPoint, lastPoint]);
    });

    test('hover over resize handle updates canvas cursor and hovered clip', () {
      fixture.hover(const Offset(80, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(fixture.viewModel.hoveredClip, isNull);

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 8, 30),
        metadata: (id: ClipIds.underCursor, type: ResizeAreaType.start),
      );

      fixture.hover(const Offset(112, 20));

      expect(fixture.viewModel.mouseCursor, SystemMouseCursors.resizeLeftRight);
      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, ClipIds.underCursor);
    });

    test('state machine identifies automation clip content', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();

      final titleContext = fixture.stateMachine.pointerContextAt(
        const Offset(120, 20),
      );
      expect(titleContext.hitTestResult.clip, isNotNull);
      expect(titleContext.hitTestResult.clip!.annotation.metadata, clip.id);
      expect(titleContext.target.clipId, clip.id);
      expect(titleContext.target.isAutomationClipContent, isFalse);

      final bodyContext = fixture.stateMachine.pointerContextAt(
        const Offset(120, 38),
      );
      expect(bodyContext.hitTestResult.clip, isNotNull);
      expect(bodyContext.hitTestResult.clip!.annotation.metadata, clip.id);
      expect(bodyContext.selectableClipId, clip.id);
      expect(bodyContext.movableClipId, clip.id);
      expect(bodyContext.target.isAutomationClipContent, isTrue);
    });

    test('collapsed automation clip body is not automation content', () {
      final (:clip, pattern: _) = addVisibleAutomationClip(
        rect: const Rect.fromLTWH(
          110,
          15,
          40,
          clipContentRenderHeightThreshold - 1,
        ),
      );

      fixture.hover(const Offset(120, 38));

      expect(fixture.viewModel.hoveredClip, clip.id);
      expect(fixture.viewModel.clipWithAutomationHandles, isNull);

      final bodyContext = fixture.stateMachine.pointerContextAt(
        const Offset(120, 38),
      );
      expect(bodyContext.hitTestResult.clip, isNotNull);
      expect(bodyContext.hitTestResult.clip!.annotation.metadata, clip.id);
      expect(bodyContext.selectableClipId, clip.id);
      expect(bodyContext.movableClipId, clip.id);
      expect(bodyContext.target.isAutomationClipContent, isFalse);
      expect(bodyContext.automationClipContentClipId, isNull);
    });

    test('state machine keeps automation resize handles selectable', () {
      final (:clip, pattern: _) = addVisibleAutomationClip(
        rect: const Rect.fromLTWH(110, 15, 80, 45),
      );
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(184, 31, 14, 29),
        metadata: (id: clip.id, type: ResizeAreaType.end),
      );

      final bodyResizeContext = fixture.stateMachine.pointerContextAt(
        const Offset(188, 38),
      );

      expect(bodyResizeContext.target.isAutomationClipContent, isTrue);
      expect(bodyResizeContext.selectableClipId, clip.id);
      expect(bodyResizeContext.automationClipContentClipId, clip.id);
      expect(bodyResizeContext.resizeHandleTarget?.metadata.id, clip.id);
    });

    test(
      'hover leaving clip restores timeline cursor location and clears hovered clip',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(110, 15, 40, 30),
          metadata: ClipIds.underCursor,
        );

        fixture.hover(const Offset(120, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNull);
        expect(fixture.viewModel.hoveredClip, ClipIds.underCursor);

        fixture.hover(const Offset(200, 20));
        expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
        expect(
          trackIdForRowId(
            fixture.viewModel,
            fixture.viewModel.hoverIndicatorPosition!.rowId,
          ),
          TrackIds.a,
        );
        expect(fixture.viewModel.hoveredClip, isNull);
      },
    );

    test('exit clears hover-derived cursor location and hovered clip', () {
      fixture.enter(const Offset(120, 20));
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(110, 15, 40, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.hover(const Offset(121, 20));
      expect(fixture.viewModel.hoveredClip, ClipIds.underCursor);

      fixture.exit(const Offset(120, 20));

      expect(fixture.viewModel.hoverIndicatorPosition, isNull);
      expect(fixture.viewModel.hoveredClip, isNull);
    });

    test('exit clears automation handles clip', () {
      final (:clip, pattern: _) = addVisibleAutomationClip();

      fixture.hover(const Offset(120, 38));
      expect(fixture.viewModel.clipWithAutomationHandles, clip.id);

      fixture.exit(const Offset(120, 38));

      expect(fixture.viewModel.clipWithAutomationHandles, isNull);
    });

    test('exit clears canvas cursor', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(110, 15, 8, 30),
        metadata: (id: ClipIds.underCursor, type: ResizeAreaType.start),
      );

      fixture.hover(const Offset(112, 20));
      expect(fixture.viewModel.mouseCursor, SystemMouseCursors.resizeLeftRight);

      fixture.exit(const Offset(112, 20));

      expect(fixture.viewModel.mouseCursor, MouseCursor.defer);
    });

    test('alt modifier disables snapping for cursor offset', () {
      const initialPos = Offset(13.25, 20);
      const altTestPos = Offset(17.25, 20);
      const releasedPos = Offset(21.25, 20);
      final rawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: altTestPos.dx,
      );
      final releasedRawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: releasedPos.dx,
      );
      final expectedReleasedSnappedOffset = getSnappedTime(
        rawTime: releasedRawOffset.round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
        round: true,
      ).toDouble();

      fixture.hover(initialPos);
      final snappedOffset = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
      fixture.hover(altTestPos);
      final unsnappedOffset = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.stateMachine.modifierReleased(ArrangerModifierKey.alt);
      fixture.hover(releasedPos);
      final snappedOffsetAgain =
          fixture.viewModel.hoverIndicatorPosition!.offset;

      expect(unsnappedOffset, closeTo(rawOffset, 1e-9));
      expect(unsnappedOffset, isNot(equals(snappedOffset)));
      expect(snappedOffsetAgain, expectedReleasedSnappedOffset);
    });

    test('view transform changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      final before = fixture.viewModel.hoverIndicatorPosition!.offset;

      fixture.controller.onRenderedViewTransformChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
        verticalScrollPosition: fixture.viewModel.verticalScrollPosition,
      );

      final after = fixture.viewModel.hoverIndicatorPosition!.offset;
      expect(after, isNot(equals(before)));
    });

    test('track layout changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(
        trackIdForRowId(
          fixture.viewModel,
          fixture.viewModel.hoverIndicatorPosition!.rowId,
        ),
        TrackIds.a,
      );

      fixture.project.trackOrder
        ..clear()
        ..addAll([TrackIds.b, TrackIds.a]);
      fixture.viewModel.trackPositionCalculator.invalidate(
        ArrangerStateMachineTestFixture.editorHeight,
      );
      fixture.controller.onTrackLayoutChanged();

      expect(fixture.viewModel.hoverIndicatorPosition, isNotNull);
      expect(
        trackIdForRowId(
          fixture.viewModel,
          fixture.viewModel.hoverIndicatorPosition!.rowId,
        ),
        TrackIds.b,
      );
    });

    test('primary pointer down transitions idle to drag', () {
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
    });

    test('primary pointer up transitions back to idle', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(80, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('non-primary pointer down does not enter drag state', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(
        fixture.stateMachine.data.activePointerButton,
        ArrangerPointerButton.secondary,
      );
      expect(
        fixture.stateMachine.data.activePointerDownContext?.position,
        const Offset(80, 20),
      );
    });

    test('right-click over clip opens context menu and selects clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      var openCount = 0;
      Offset? openedPosition;
      MenuDef? openedMenu;
      ArrangerIdleState.openContextMenuFn = (globalPosition, menu) {
        openCount++;
        openedPosition = globalPosition;
        openedMenu = menu;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(260, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(openCount, 1);
      expect(openedPosition, const Offset(260, 20));
      expect(fixture.viewModel.selectedClips, {ClipIds.underCursor});

      final openedItems = openedMenu!.children.whereType<AnthemMenuItem>();
      expect(openedItems.first.text, 'Delete');
      expect(openedItems.first.onSelected, isNotNull);
    });

    test('right-click over selected clip preserves existing selection', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.addAll({
        ClipIds.underCursor,
        ClipIds.someOtherSelected,
      });

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(260, 20),
        ),
      );

      expect(openCount, 1);
      expect(fixture.viewModel.selectedClips, {
        ClipIds.underCursor,
        ClipIds.someOtherSelected,
      });
    });

    test('right-click on empty space does not open clip context menu', () {
      fixture.viewModel.selectedClips.add(ClipIds.selected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(420, 20),
        ),
      );

      expect(openCount, 0);
      expect(fixture.viewModel.selectedClips, {ClipIds.selected});
    });

    test('right-click on resize handle opens context menu for clip', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(240, 10, 16, 30),
        metadata: (id: ClipIds.underResizeHandle, type: ResizeAreaType.end),
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      var openCount = 0;
      ArrangerIdleState.openContextMenuFn = (_, _) {
        openCount++;
      };

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kSecondaryMouseButton,
          position: Offset(245, 20),
        ),
      );

      expect(openCount, 1);
      expect(fixture.viewModel.selectedClips, {ClipIds.underResizeHandle});
    });

    test('second click within threshold arms double click on down', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      expect(fixture.idleState.doubleClickPressed, isFalse);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      expect(fixture.idleState.doubleClickPressed, isTrue);
    });

    test('double click flag clears on pointer up', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      expect(fixture.idleState.doubleClickPressed, isTrue);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('large travel prevents double click classification', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(10, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(60, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(60, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(60, 20),
        ),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
    });

    test('pointer cancel clears click tracking', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      expect(fixture.idleState.doubleClickPressed, isTrue);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.idleState.doubleClickPressed, isFalse);
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
    });

    test('single click over empty space clears selected clips', () {
      fixture.viewModel.selectedClips.addAll({ClipIds.a, ClipIds.b});

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(280, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(280, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test('single click over non-selected clip selects clicked clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(ClipIds.selected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {ClipIds.underCursor});
    });

    test('single click over resize handle selects associated clip', () {
      fixture.viewModel.visibleResizeAreas.add(
        rect: const Rect.fromLTWH(240, 10, 16, 30),
        metadata: (id: ClipIds.underResizeHandle, type: ResizeAreaType.start),
      );
      fixture.viewModel.selectedClips.add(ClipIds.selected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(255, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(255, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {ClipIds.underResizeHandle});
    });

    test('double click over clip opens piano roll and sets active pattern', () {
      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Pattern 1',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: pattern.id,
        trackId: TrackIds.a,
        offset: 0,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: clip.id,
      );

      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.pianoRoll);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, pattern.id);
      expect(fixture.project.sequence.activeTrackID, TrackIds.a);
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test('double click over multi-selected clip keeps selection', () {
      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Pattern 1',
      );
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: pattern.id,
        trackId: TrackIds.a,
        offset: 0,
        timeView: TimeViewModel(start: 0, end: 96),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      fixture.project.sequence.arrangements[arrangementId]!.clips[clip.id] =
          clip;

      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: clip.id,
      );
      fixture.viewModel.selectedClips.addAll({
        clip.id,
        ClipIds.someOtherSelected,
      });

      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.pianoRoll);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, pattern.id);
      expect(fixture.project.sequence.activeTrackID, TrackIds.a);
      expect(fixture.viewModel.selectedClips, {
        clip.id,
        ClipIds.someOtherSelected,
      });
    });

    test('double click over empty space does not change active editor', () {
      fixture.viewModel.tool = EditorTool.select;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(400, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(400, 20)),
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(400, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(400, 20)),
      );

      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
      expect(fixture.project.sequence.activePatternID, isNull);
      expect(fixture.project.sequence.activeTrackID, isNull);
    });

    test('ctrl-click over non-selected clip adds it to selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {
        ClipIds.someOtherSelected,
        ClipIds.underCursor,
      });
    });

    test('ctrl-click over selected clip removes it from selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(240, 10, 80, 30),
        metadata: ClipIds.underCursor,
      );
      fixture.viewModel.selectedClips.addAll({
        ClipIds.underCursor,
        ClipIds.someOtherSelected,
      });

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(260, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(260, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, {ClipIds.someOtherSelected});
    });

    test('ctrl-click on empty space clears selection', () {
      fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      fixture.viewModel.selectedClips.addAll({ClipIds.a, ClipIds.b});

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(420, 20),
        ),
      );
      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips, isEmpty);
    });

    test(
      'ctrl-click on resize handle toggles associated clip in selection',
      () {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(240, 10, 16, 30),
          metadata: (id: ClipIds.underResizeHandle, type: ResizeAreaType.start),
        );
        fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(255, 20),
          ),
        );
        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(255, 20)),
        );

        expect(fixture.viewModel.selectedClips, {
          ClipIds.someOtherSelected,
          ClipIds.underResizeHandle,
        });

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(245, 20),
          ),
        );
        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(245, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.selectedClips, {ClipIds.someOtherSelected});
      },
    );
  });
}
