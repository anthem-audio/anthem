import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerAutomationTensionChangeState', () {
    const clipRect = Rect.fromLTWH(100, 0, 240, 60);
    const handleCenter = Offset(180, 38);

    AutomationPointModel makePoint({
      required int offset,
      required double value,
      double tension = 0,
    }) {
      return AutomationPointModel(
        idAllocator: testIdAllocator(),
        offset: offset,
        value: value,
        tension: tension,
      );
    }

    ({ClipModel clip, PatternModel pattern}) addAutomationClip({
      required List<AutomationPointModel> points,
    }) {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      final pattern = PatternModel(
        idAllocator: testIdAllocator(),
        name: 'Automation',
      );
      pattern.automation.points.addAll(points);
      fixture.project.sequence.patterns[pattern.id] = pattern;

      final clip = ClipModel(
        idAllocator: testIdAllocator(),
        patternId: pattern.id,
        trackId: TrackIds.automationA,
        offset: 100,
        timeView: TimeViewModel(start: 0, end: 240),
      );

      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      arrangement.clips[clip.id] = clip;
      fixture.viewModel.visibleClips.add(rect: clipRect, metadata: clip.id);

      return (clip: clip, pattern: pattern);
    }

    void addTensionHandleAnnotation({
      required ClipModel clip,
      required PatternModel pattern,
      required int pointIndex,
    }) {
      final point = pattern.automation.points[pointIndex];
      fixture.viewModel.visibleAutomationHandles.add(
        rect: Rect.fromCenter(center: handleCenter, width: 16, height: 16),
        metadata: AutomationHandleAnnotation(
          clipId: clip.id,
          kind: AutomationHandleKind.tensionHandle,
          pointIndex: pointIndex,
          pointId: point.id,
          center: handleCenter,
        ),
      );
    }

    test('dragging tension handle changes tension and commits undo step', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.75),
          makePoint(offset: 96, value: 0.25, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(point.tension, 0.2);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationTensionChangeState>(),
      );
      expect(point.tension, closeTo(0.7, 1e-9));

      fixture.pointerUp(const PointerUpEvent(pointer: 1, position: movePos));

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(point.tension, closeTo(0.7, 1e-9));
      expect(
        fixture.viewModel.lastInteractedAutomationTension,
        closeTo(0.7, 1e-9),
      );

      fixture.project.undo();
      expect(point.tension, 0.2);

      fixture.project.redo();
      expect(point.tension, closeTo(0.7, 1e-9));
    });

    test('tension drag inverts for rising segments', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.25),
          makePoint(offset: 96, value: 0.75, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerAutomationTensionChangeState>(),
      );
      expect(point.tension, closeTo(-0.3, 1e-9));
    });

    test('canceling tension drag restores transient edit', () {
      final (:clip, :pattern) = addAutomationClip(
        points: [
          makePoint(offset: 0, value: 0.75),
          makePoint(offset: 96, value: 0.25, tension: 0.2),
        ],
      );
      addTensionHandleAnnotation(clip: clip, pattern: pattern, pointIndex: 1);
      final point = pattern.automation.points[1];
      const movePos = Offset(180, -87);

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: handleCenter,
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
      expect(point.tension, isNot(0.2));

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: movePos),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(point.tension, 0.2);

      fixture.project.undo();
      expect(point.tension, 0.2);
    });
  });
}
