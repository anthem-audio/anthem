import 'arranger_state_machine_test_helpers.dart';

void main() {
  late ArrangerStateMachineTestFixture fixture;
  setUpArrangerStateMachineTestFixture((value) => fixture = value);
  group('ArrangerSelectionBoxState', () {
    void enterSelectionBoxState({
      Offset downPos = const Offset(100, 30),
      Offset movePos = const Offset(160, 80),
      bool useCtrlModifier = false,
      bool useShiftModifier = false,
      bool useSelectTool = true,
    }) {
      fixture.viewModel.tool = useSelectTool
          ? EditorTool.select
          : EditorTool.pencil;

      if (useCtrlModifier) {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.ctrl);
      }
      if (useShiftModifier) {
        fixture.stateMachine.modifierPressed(ArrangerModifierKey.shift);
      }

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

    void addVisibleClip({required Id id, required Rect rect}) {
      fixture.viewModel.visibleClips.add(rect: rect, metadata: id);
    }

    test('select tool drag delegates to selection box state', () {
      enterSelectionBoxState(useSelectTool: true);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('ctrl drag with pencil tool delegates to selection box state', () {
      enterSelectionBoxState(useCtrlModifier: true, useSelectTool: false);

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('selection box uses raw view-space pointer coordinates', () {
      const downPos = Offset(100, 30);
      const movePos = Offset(160, 80);
      enterSelectionBoxState(downPos: downPos, movePos: movePos);

      final selectionBox = fixture.viewModel.selectionBox;
      expect(selectionBox, isNotNull);
      expect(selectionBox!.left, equals(downPos.dx));
      expect(selectionBox.top, equals(downPos.dy));
      expect(selectionBox.width, equals(movePos.dx - downPos.dx));
      expect(selectionBox.height, equals(movePos.dy - downPos.dy));
    });

    test('selection box is normalized for reverse drags', () {
      const downPos = Offset(150, 90);
      const movePos = Offset(100, 30);
      enterSelectionBoxState(downPos: downPos, movePos: movePos);

      final selectionBox = fixture.viewModel.selectionBox;
      expect(selectionBox, isNotNull);
      expect(selectionBox!.left, equals(movePos.dx));
      expect(selectionBox.top, equals(movePos.dy));
      expect(selectionBox.width, equals(downPos.dx - movePos.dx));
      expect(selectionBox.height, equals(downPos.dy - movePos.dy));
    });

    test('pointer up clears selection box', () {
      enterSelectionBoxState();
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(160, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test('pointer cancel clears selection box', () {
      enterSelectionBoxState();
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pointerUp(
        const PointerCancelEvent(pointer: 1, position: Offset(160, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test(
      'releasing ctrl does not exit selection box while pointer is down',
      () {
        enterSelectionBoxState(useCtrlModifier: true, useSelectTool: false);
        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.viewModel.selectionBox, isNotNull);

        fixture.stateMachine.modifierReleased(ArrangerModifierKey.ctrl);

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.viewModel.selectionBox, isNotNull);
      },
    );

    test('escape exits selection box and clears it', () {
      enterSelectionBoxState();
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);

      fixture.pressEscape();

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);
    });

    test('escape prevents selection box re-entry until pointer release', () {
      enterSelectionBoxState();
      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );

      fixture.pressEscape();
      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(220, 140),
        ),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());
      expect(fixture.viewModel.selectionBox, isNull);

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(220, 140)),
      );
      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());

      fixture.pointerDown(
        const PointerDownEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(100, 30),
        ),
      );
      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(180, 110),
        ),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.viewModel.selectionBox, isNotNull);
    });

    test('view transform updates do not remap selection box coordinates', () {
      enterSelectionBoxState();
      final before = fixture.viewModel.selectionBox!;

      fixture.controller.onRenderedViewTransformChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
        verticalScrollPosition: 48,
      );

      final after = fixture.viewModel.selectionBox!;
      expect(after.left, equals(before.left));
      expect(after.top, equals(before.top));
      expect(after.width, equals(before.width));
      expect(after.height, equals(before.height));
    });

    test(
      'starting drag over selected clip does not latch subtractive mode without shift',
      () {
        const downPos = Offset(100, 30);
        const clipId = ClipIds.selected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(clipId);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
      },
    );

    test(
      'starting drag over selected clip latches subtractive selection mode with shift',
      () {
        const downPos = Offset(100, 30);
        const clipId = ClipIds.selected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(clipId);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
          useShiftModifier: true,
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isTrue);
      },
    );

    test(
      'starting drag over non-selected clip does not latch subtractive mode',
      () {
        const downPos = Offset(100, 30);
        const clipId = ClipIds.notSelected;

        fixture.viewModel.visibleClips.add(
          rect: const Rect.fromLTWH(90, 20, 40, 30),
          metadata: clipId,
        );
        fixture.viewModel.selectedClips.add(ClipIds.someOtherSelected);

        enterSelectionBoxState(
          downPos: downPos,
          movePos: const Offset(160, 80),
          useShiftModifier: true,
        );

        expect(
          fixture.stateMachine.currentState,
          isA<ArrangerSelectionBoxState>(),
        );
        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
      },
    );

    test('starting drag over empty space does not latch subtractive mode', () {
      fixture.viewModel.selectedClips.add(ClipIds.selected);

      enterSelectionBoxState(
        downPos: const Offset(100, 30),
        movePos: const Offset(160, 80),
      );

      expect(
        fixture.stateMachine.currentState,
        isA<ArrangerSelectionBoxState>(),
      );
      expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isFalse);
    });

    test(
      'without shift selection box clears existing selection and selects clips in box',
      () {
        addVisibleClip(
          id: ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
        );

        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));
      },
    );

    test('with shift additive mode selects clips under selection box', () {
      addVisibleClip(id: ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
        useShiftModifier: true,
      );

      expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isFalse);
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({ClipIds.a, ClipIds.b}),
      );
    });

    test(
      'without shift drag over selected clip is additive from an empty snapshot',
      () {
        addVisibleClip(
          id: ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 30, 30),
        );
        fixture.viewModel.selectedClips.addAll({ClipIds.a, ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(80, 80),
        );

        expect(
          fixture.selectionBoxState.isSubtractiveSelectionLatched,
          isFalse,
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.a}));
      },
    );

    test(
      'with shift subtractive mode deselects selected clips under selection box',
      () {
        addVisibleClip(
          id: ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 30, 30),
        );
        fixture.viewModel.selectedClips.addAll({ClipIds.a, ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(80, 80),
          useShiftModifier: true,
        );

        expect(fixture.selectionBoxState.isSubtractiveSelectionLatched, isTrue);
        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));
      },
    );

    test(
      'without shift additive mode reverts to empty selection when box shrinks',
      () {
        addVisibleClip(
          id: ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
        );
        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(10, 10),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), isEmpty);
      },
    );

    test(
      'with shift additive mode reverts clip to original selection when box shrinks',
      () {
        addVisibleClip(
          id: ClipIds.b,
          rect: const Rect.fromLTWH(40, 40, 20, 20),
        );
        fixture.viewModel.selectedClips.add(ClipIds.a);

        enterSelectionBoxState(
          downPos: const Offset(0, 0),
          movePos: const Offset(80, 80),
          useShiftModifier: true,
        );
        expect(
          fixture.viewModel.selectedClips.toSet(),
          equals({ClipIds.a, ClipIds.b}),
        );

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(10, 10),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.a}));
      },
    );

    test(
      'with shift subtractive mode reverts clip to original selection when box shrinks',
      () {
        addVisibleClip(
          id: ClipIds.a,
          rect: const Rect.fromLTWH(20, 20, 20, 20),
        );
        addVisibleClip(
          id: ClipIds.b,
          rect: const Rect.fromLTWH(90, 20, 20, 20),
        );
        fixture.viewModel.selectedClips.addAll({ClipIds.a, ClipIds.b});

        enterSelectionBoxState(
          downPos: const Offset(25, 25),
          movePos: const Offset(130, 60),
          useShiftModifier: true,
        );
        expect(fixture.viewModel.selectedClips.toSet(), isEmpty);

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(60, 60),
          ),
        );

        expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));
      },
    );

    test('without shift cancel restores selected clips to empty snapshot', () {
      addVisibleClip(id: ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
      );
      expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));

      fixture.pressEscape();

      expect(fixture.viewModel.selectedClips.toSet(), isEmpty);
    });

    test('with shift cancel restores selected clips to selection snapshot', () {
      addVisibleClip(id: ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));
      fixture.viewModel.selectedClips.add(ClipIds.a);

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
        useShiftModifier: true,
      );
      expect(
        fixture.viewModel.selectedClips.toSet(),
        equals({ClipIds.a, ClipIds.b}),
      );

      fixture.pressEscape();

      expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.a}));
    });

    test('pointer up keeps selection result from selection box', () {
      addVisibleClip(id: ClipIds.b, rect: const Rect.fromLTWH(40, 40, 20, 20));

      enterSelectionBoxState(
        downPos: const Offset(0, 0),
        movePos: const Offset(80, 80),
      );
      expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));

      fixture.pointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(80, 80)),
      );

      expect(fixture.stateMachine.currentState, isA<ArrangerIdleState>());
      expect(fixture.viewModel.selectedClips.toSet(), equals({ClipIds.b}));
    });
  });
}
