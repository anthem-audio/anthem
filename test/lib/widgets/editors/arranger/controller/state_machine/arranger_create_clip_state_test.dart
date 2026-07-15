import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerCreateClipState', () {
    void startDoubleClickHold({
      Offset firstClickPos = const Offset(100, 20),
      Offset secondClickPos = const Offset(100, 20),
    }) {
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: firstClickPos,
        ),
      );
      fixture.pointerUp(PointerUpEvent(pointer: 1, position: firstClickPos));
      fixture.pointerDown(
        PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: secondClickPos,
        ),
      );
    }

    void enterCreateClipState({
      Offset firstClickPos = const Offset(100, 20),
      Offset secondClickPos = const Offset(100, 20),
      Offset movePos = const Offset(180, 20),
    }) {
      startDoubleClickHold(
        firstClickPos: firstClickPos,
        secondClickPos: secondClickPos,
      );
      fixture.pointerMove(
        PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: movePos,
        ),
      );
    }

    test('single-click drag stays in drag state and does not delegate', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(180, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test('double-click hold delegates to create clip state before drag', () {
      startDoubleClickHold();

      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test('double-click drag delegates to create clip state', () {
      enterCreateClipState();

      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNotNull);
    });

    test('clip create hint is anchored to drag start track', () {
      enterCreateClipState(movePos: const Offset(220, 100));

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(trackIdForRowId(fixture.viewModel, hint!.rowId), TrackIds.a);
    });

    test('clip create hint can target a phantom automation lane', () {
      fixture.showPhantomAutomationLaneForTrack(TrackIds.a);

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(220, 80),
      );

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(
        phantomParentTrackIdForRowId(fixture.viewModel, hint!.rowId),
        TrackIds.a,
      );
    });

    test('clip create hint can target a real automation lane', () {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(220, 80),
      );

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(
        trackIdForRowId(fixture.viewModel, hint!.rowId),
        TrackIds.automationA,
      );
    });

    group('clip create hint color', () {
      test('grayscale track uses hue 161 default-palette override', () {
        fixture.project.tracks[TrackIds.a]!.color = AnthemColor(
          hue: 0,
          palette: AnthemColorPaletteKind.grayscale,
        );

        enterCreateClipState();

        final hint = fixture.viewModel.clipCreateHint;
        expect(hint, isNotNull);

        final expected = AnthemColor(
          hue: 161,
          palette: .normal,
        ).colorShifter.clipBase.toColor().withValues(alpha: 0.5);
        expect(hint!.color, expected);
      });

      test('non-grayscale track uses the track color', () {
        fixture.project.tracks[TrackIds.a]!.color = AnthemColor(
          hue: 60,
          palette: AnthemColorPaletteKind.normal,
        );

        enterCreateClipState();

        final hint = fixture.viewModel.clipCreateHint;
        expect(hint, isNotNull);

        final expected = AnthemColor(
          hue: 60,
          palette: .normal,
        ).colorShifter.clipBase.toColor().withValues(alpha: 0.5);
        expect(hint!.color, expected);
      });
    });

    test('pointer move updates clip create hint end offset', () {
      startDoubleClickHold();
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(420, 20),
        ),
      );

      final firstHint = fixture.viewModel.clipCreateHint!;

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(500, 20),
        ),
      );

      final secondHint = fixture.viewModel.clipCreateHint!;
      expect(secondHint.endOffset, isNot(equals(firstHint.endOffset)));
    });

    test('without drag, pointer up creates auto-sized clip', () {
      final arrangement = fixture.project.sequence.arrangement;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      startDoubleClickHold();
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNull);

      const clickPos = Offset(100, 20);
      final rawStartOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeRange.start,
        timeViewEnd: fixture.viewModel.timeRange.end,
        viewPixelWidth: ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: clickPos.dx,
      );
      final expectedStartOffset = getSnappedTime(
        rawTime: rawStartOffset.round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
        round: true,
      );
      final expectedWidth = getBarLength(
        fixture.project.sequence.ticksPerQuarter,
        fixture.project.sequence.defaultTimeSignature,
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, TrackIds.a);
      expect(newClip.offset, expectedStartOffset);
      expect(newClip.timeView, isNull);
      expect(newClip.width, expectedWidth);
      expect(fixture.projectViewModel.selectedEditor, EditorKind.pianoRoll);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, newClip.patternId);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test(
      'without drag, pointer up creates auto-sized automation lane clip',
      () {
        fixture.showRealAutomationLaneForTrack(TrackIds.a);

        final arrangement = fixture.project.sequence.arrangement;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        startDoubleClickHold(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final newClip = arrangement.clips.values.last;
        expect(newClip.trackId, TrackIds.automationA);
        expect(newClip.timeView, isNull);
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);
      },
    );

    test(
      'without drag, pointer up creates a targeted phantom automation lane clip',
      () async {
        final target = fixture.showTargetedPhantomAutomationLaneForTrack(
          TrackIds.a,
        );
        final parentTrack = fixture.project.tracks[TrackIds.a]!;

        final arrangement = fixture.project.sequence.arrangement;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        startDoubleClickHold(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(parentTrack.automationLanes, hasLength(1));
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final automationLaneId = parentTrack.automationLanes.single;
        final automationLane = fixture.project.tracks[automationLaneId]!;
        final newClip = arrangement.clips.values.last;
        final pattern = fixture.project.sequence.patterns[newClip.patternId]!;

        expect(automationLane.name, 'Volume');
        expect(automationLane.automationTarget, isNotNull);
        expect(automationLane.automationTarget!.nodeId, target.nodeId);
        expect(automationLane.automationTarget!.portId, target.portId);
        expect(newClip.trackId, automationLaneId);
        expect(newClip.timeView, isNull);
        expect(pattern.name, 'Track - Volume');
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);

        await Future<void>.delayed(Duration.zero);
        fixture.project.undo();

        expect(parentTrack.automationLanes, isEmpty);
        expect(fixture.project.tracks.containsKey(automationLaneId), isFalse);
        expect(fixture.project.sequence.patterns.length, patternCountBefore);
        expect(arrangement.clips.length, clipCountBefore);
      },
    );

    test('pointer up with non-zero width creates one pattern and one clip', () {
      final arrangement = fixture.project.sequence.arrangement;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      enterCreateClipState(movePos: const Offset(420, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      final hint = fixture.viewModel.clipCreateHint!;

      final expectedStart = hint.startOffset < hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedEnd = hint.startOffset > hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedWidth = expectedEnd - expectedStart;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, trackIdForRowId(fixture.viewModel, hint.rowId));
      expect(newClip.offset, expectedStart.round());
      expect(newClip.timeView, isNotNull);
      expect(newClip.timeView!.start, 0);
      expect(newClip.timeView!.end, expectedWidth.round());
      expect(fixture.projectViewModel.selectedEditor, EditorKind.pianoRoll);
      expect(fixture.projectViewModel.activePanel, PanelKind.pianoRoll);
      expect(fixture.project.sequence.activePatternID, newClip.patternId);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test('pointer up with non-zero width creates automation lane clip', () {
      fixture.showRealAutomationLaneForTrack(TrackIds.a);

      final arrangement = fixture.project.sequence.arrangement;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;
      fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
      fixture.projectViewModel.activePanel = PanelKind.deviceRack;
      fixture.project.sequence.activePatternID = null;
      fixture.project.sequence.activeTrackID = null;

      enterCreateClipState(
        firstClickPos: const Offset(100, 80),
        secondClickPos: const Offset(100, 80),
        movePos: const Offset(420, 80),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      final hint = fixture.viewModel.clipCreateHint!;

      final expectedStart = hint.startOffset < hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedEnd = hint.startOffset > hint.endOffset
          ? hint.startOffset
          : hint.endOffset;
      final expectedWidth = expectedEnd - expectedStart;

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(420, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore + 1);
      expect(arrangement.clips.length, clipCountBefore + 1);

      final newClip = arrangement.clips.values.last;
      expect(newClip.trackId, TrackIds.automationA);
      expect(newClip.offset, expectedStart.round());
      expect(newClip.timeView, isNotNull);
      expect(newClip.timeView!.start, 0);
      expect(newClip.timeView!.end, expectedWidth.round());
      expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
      expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
      expect(fixture.project.sequence.activePatternID, isNull);
      expect(fixture.project.sequence.activeTrackID, newClip.trackId);
    });

    test(
      'pointer up with non-zero width creates a targeted phantom automation lane clip',
      () {
        fixture.showTargetedPhantomAutomationLaneForTrack(TrackIds.a);
        final parentTrack = fixture.project.tracks[TrackIds.a]!;

        final arrangement = fixture.project.sequence.arrangement;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;
        fixture.projectViewModel.selectedEditor = EditorKind.deviceRack;
        fixture.projectViewModel.activePanel = PanelKind.deviceRack;
        fixture.project.sequence.activePatternID = null;
        fixture.project.sequence.activeTrackID = null;

        enterCreateClipState(
          firstClickPos: const Offset(100, 80),
          secondClickPos: const Offset(100, 80),
          movePos: const Offset(420, 80),
        );
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        final hint = fixture.viewModel.clipCreateHint!;

        final expectedStart = hint.startOffset < hint.endOffset
            ? hint.startOffset
            : hint.endOffset;
        final expectedEnd = hint.startOffset > hint.endOffset
            ? hint.startOffset
            : hint.endOffset;
        final expectedWidth = expectedEnd - expectedStart;

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(420, 80)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.clipCreateHint, isNull);
        expect(parentTrack.automationLanes, hasLength(1));
        expect(
          fixture.project.sequence.patterns.length,
          patternCountBefore + 1,
        );
        expect(arrangement.clips.length, clipCountBefore + 1);

        final automationLaneId = parentTrack.automationLanes.single;
        final newClip = arrangement.clips.values.last;
        expect(newClip.trackId, automationLaneId);
        expect(newClip.offset, expectedStart.round());
        expect(newClip.timeView, isNotNull);
        expect(newClip.timeView!.start, 0);
        expect(newClip.timeView!.end, expectedWidth.round());
        expect(fixture.projectViewModel.selectedEditor, EditorKind.deviceRack);
        expect(fixture.projectViewModel.activePanel, PanelKind.deviceRack);
        expect(fixture.project.sequence.activePatternID, isNull);
        expect(fixture.project.sequence.activeTrackID, newClip.trackId);
      },
    );

    test('pointer up with zero width does not create clip or pattern', () {
      final arrangement = fixture.project.sequence.arrangement;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;

      enterCreateClipState(movePos: const Offset(180, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 20),
        ),
      );

      final hint = fixture.viewModel.clipCreateHint!;
      expect(hint.startOffset, hint.endOffset);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
      expect(fixture.project.sequence.patterns.length, patternCountBefore);
      expect(arrangement.clips.length, clipCountBefore);
    });

    test('leaving create clip state clears clip create hint', () {
      enterCreateClipState(movePos: const Offset(220, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNotNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.clipCreateHint, isNull);
    });

    test(
      'escape cancels create clip and prevents re-entry until pointer release',
      () {
        final arrangement = fixture.project.sequence.arrangement;
        final patternCountBefore = fixture.project.sequence.patterns.length;
        final clipCountBefore = arrangement.clips.length;

        enterCreateClipState(movePos: const Offset(420, 20));
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerCreateClipState>(),
        );
        expect(fixture.viewModel.clipCreateHint, isNotNull);

        fixture.pressEscape();

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(500, 20),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.viewModel.clipCreateHint, isNull);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(500, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.project.sequence.patterns.length, patternCountBefore);
        expect(arrangement.clips.length, clipCountBefore);
      },
    );
  });
}
