import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerDragState', () {
    test('primary down initializes drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.dragState.activePointerId, 1);
      expect(fixture.dragState.dragStartPosition, isNotNull);
      expect(fixture.dragState.dragCurrentPosition, isNotNull);
      expect(fixture.dragState.dragStartPosition!.x, 80);
      expect(fixture.dragState.dragStartPosition!.y, 20);
      expect(fixture.dragState.dragCurrentPosition!.x, 80);
      expect(fixture.dragState.dragCurrentPosition!.y, 20);
      expect(
        fixture.stateMachine.data.activePointerButton,
        ArrangerPointerButton.primary,
      );
      expect(
        fixture.stateMachine.data.activePointerContext?.position,
        const Offset(80, 20),
      );
      expect(
        fixture.dragState.dragStartContext,
        same(fixture.stateMachine.data.activePointerDownContext),
      );
      expect(
        fixture.dragState.dragCurrentContext,
        same(fixture.stateMachine.data.activePointerContext),
      );
      expect(fixture.dragState.dragCurrentContext?.target.isEmpty, isTrue);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });

    test('pointer down over clip sets pressed clip immediately', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
      expect(fixture.viewModel.pressedClip, ClipIds.underCursor);
    });

    test(
      'pointer down over resize handle sets pressed clip immediately even without clip hit',
      () {
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(96, 10, 14, 40),
          metadata: (id: ClipIds.underResizeHandle, type: ResizeAreaType.start),
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(100, 20),
          ),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
        expect(fixture.viewModel.pressedClip, ClipIds.underResizeHandle);
      },
    );

    test(
      'pointer up clears pressed clip without crossing activation distance',
      () {
        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(100, 10, 80, 40),
          metadata: ClipIds.underCursor,
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(120, 20),
          ),
        );
        expect(fixture.viewModel.pressedClip, ClipIds.underCursor);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(120, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.pressedClip, isNull);
      },
    );

    test(
      'pointer up clears pressed clip from resize-handle press without crossing activation distance',
      () {
        fixture.viewModel.visibleResizeAreas.add(
          rect: const Rect.fromLTWH(96, 10, 14, 40),
          metadata: (id: ClipIds.underResizeHandle, type: ResizeAreaType.start),
        );

        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(100, 20),
          ),
        );
        expect(fixture.viewModel.pressedClip, ClipIds.underResizeHandle);

        fixture.pointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(100, 20)),
        );

        expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
        expect(fixture.viewModel.pressedClip, isNull);
      },
    );

    test('pointer cancel clears pressed clip', () {
      fixture.viewModel.visibleClips.add(
        rect: const Rect.fromLTWH(100, 10, 80, 40),
        metadata: ClipIds.underCursor,
      );

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(120, 20),
        ),
      );
      expect(fixture.viewModel.pressedClip, ClipIds.underCursor);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(120, 20)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.pressedClip, isNull);
    });

    test('selection-mode presses do not set pressed clip', () {
      final testCases = [
        (
          description: 'select tool over resize handle',
          useCtrlModifier: false,
          tool: EditorTool.select,
          useResizeHandle: true,
        ),
        (
          description: 'ctrl modifier over resize handle',
          useCtrlModifier: true,
          tool: EditorTool.pencil,
          useResizeHandle: true,
        ),
        (
          description: 'select tool over clip',
          useCtrlModifier: false,
          tool: EditorTool.select,
          useResizeHandle: false,
        ),
        (
          description: 'ctrl modifier over clip',
          useCtrlModifier: true,
          tool: EditorTool.pencil,
          useResizeHandle: false,
        ),
      ];

      for (final testCase in testCases) {
        fixture.viewModel.tool = testCase.tool;
        if (testCase.useCtrlModifier) {
          fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
        }
        if (testCase.useResizeHandle) {
          fixture.viewModel.visibleResizeAreas.add(
            rect: const Rect.fromLTWH(96, 10, 14, 40),
            metadata: (
              id: ClipIds.underResizeHandle,
              type: ResizeAreaType.start,
            ),
          );
        } else {
          fixture.viewModel.visibleClips.add(
            rect: const Rect.fromLTWH(100, 10, 80, 40),
            metadata: ClipIds.underCursor,
          );
        }

        fixture.pointerDown(
          PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: testCase.useResizeHandle
                ? const Offset(100, 20)
                : const Offset(120, 20),
          ),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerDragState>(),
          reason: testCase.description,
        );
        expect(
          fixture.viewModel.pressedClip,
          isNull,
          reason: testCase.description,
        );

        fixture.pointerUp(
          PointerCancelEvent(
            pointer: 1,
            position: testCase.useResizeHandle
                ? const Offset(100, 20)
                : const Offset(120, 20),
          ),
        );
        fixture.stateMachine.modifierReleased(ArrangerModifierKey.ctrl);
        fixture.viewModel.visibleClips.clear();
        fixture.viewModel.visibleResizeAreas.clear();
      }
    });

    test(
      'activation distance remains false below threshold and true above',
      () {
        fixture.pointerDown(
          const PointerDownEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(80, 20),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(82, 22),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
        expect(
          fixture.stateMachine.data.activePointerContext?.position,
          const Offset(82, 22),
        );
        expect(
          fixture.dragState.dragCurrentContext,
          same(fixture.stateMachine.data.activePointerContext),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(86, 22),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isTrue);
        expect(
          fixture.dragState.dragCurrentContext?.position,
          const Offset(86, 22),
        );
        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      },
    );

    test('pointer up exits drag and clears drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(90, 22),
        ),
      );

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(90, 22)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.dragState.activePointerId, isNull);
      expect(fixture.dragState.dragStartPosition, isNull);
      expect(fixture.dragState.dragCurrentPosition, isNull);
      expect(fixture.dragState.dragStartContext, isNull);
      expect(fixture.dragState.dragCurrentContext, isNull);
      expect(fixture.stateMachine.data.activePointerButton, isNull);
      expect(fixture.stateMachine.data.activePointerDownContext, isNull);
      expect(fixture.stateMachine.data.activePointerContext, isNull);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });

    test('pointer cancel exits drag and clears drag parameters', () {
      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(80, 20),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(90, 22),
        ),
      );

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(90, 22)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.dragState.activePointerId, isNull);
      expect(fixture.dragState.dragStartPosition, isNull);
      expect(fixture.dragState.dragCurrentPosition, isNull);
      expect(fixture.dragState.dragStartContext, isNull);
      expect(fixture.dragState.dragCurrentContext, isNull);
      expect(fixture.stateMachine.data.activePointerButton, isNull);
      expect(fixture.stateMachine.data.activePointerDownContext, isNull);
      expect(fixture.stateMachine.data.activePointerContext, isNull);
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });
  });
}
