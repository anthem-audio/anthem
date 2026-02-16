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

import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/model/shared/anthem_color.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/model/track.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_controller.dart';
import 'package:anthem/widgets/editors/arranger/controller/arranger_state_machine.dart';
import 'package:anthem/widgets/editors/arranger/events.dart';
import 'package:anthem/widgets/editors/arranger/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem_codegen/include.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackIds {
  static const a = 'a';
  static const b = 'b';
  static const master = 'master';
}

TrackModel _makeTrack(Id id, String name, TrackType type) {
  return TrackModel(name: name, color: AnthemColor.randomHue(), type: type)
    ..id = id;
}

class _ArrangerStateMachineTestFixture {
  static const viewSize = Size(960, 240);
  static const editorHeight = 240.0;

  final ProjectModel project;
  final ArrangerViewModel viewModel;
  final ProjectViewModel projectViewModel;
  final ArrangerController controller;

  _ArrangerStateMachineTestFixture._({
    required this.project,
    required this.viewModel,
    required this.projectViewModel,
    required this.controller,
  });

  factory _ArrangerStateMachineTestFixture.create() {
    final project = ProjectModel();
    project.isHydrated = true;
    project.sequence = SequencerModel.create();

    project.tracks = AnthemObservableMap.of({
      _TrackIds.a: _makeTrack(_TrackIds.a, 'A', TrackType.instrument),
      _TrackIds.b: _makeTrack(_TrackIds.b, 'B', TrackType.instrument),
      _TrackIds.master: _makeTrack(
        _TrackIds.master,
        'Master',
        TrackType.instrument,
      ),
    });
    project.trackOrder = AnthemObservableList.of([_TrackIds.a, _TrackIds.b]);
    project.sendTrackOrder = AnthemObservableList.of([_TrackIds.master]);

    final viewModel = ArrangerViewModel(
      project: project,
      baseTrackHeight: 60,
      timeView: TimeRange(0, 960),
    );
    final projectViewModel = ProjectViewModel()
      ..activePanel = PanelKind.arranger;

    AnthemStore.instance.projects[project.id] = project;
    ServiceRegistry.forProject(
      project.id,
    ).register<ProjectViewModel>(projectViewModel);

    final controller = ArrangerController(
      viewModel: viewModel,
      project: project,
    );
    controller.onViewSizeChanged(viewSize);
    viewModel.trackPositionCalculator.invalidate(editorHeight);

    return _ArrangerStateMachineTestFixture._(
      project: project,
      viewModel: viewModel,
      projectViewModel: projectViewModel,
      controller: controller,
    );
  }

  ArrangerStateMachine get stateMachine => controller.stateMachine;

  ArrangerIdleState get idleState =>
      stateMachine.states[ArrangerIdleState]! as ArrangerIdleState;

  ArrangerDragState get dragState =>
      stateMachine.states[ArrangerDragState]! as ArrangerDragState;

  ArrangerCreateClipState get createClipState =>
      stateMachine.states[ArrangerCreateClipState]! as ArrangerCreateClipState;

  KeyboardModifiers _keyboardModifiers({
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    final modifiers = KeyboardModifiers();
    if (ctrl) modifiers.setCtrl(true);
    if (alt) modifiers.setAlt(true);
    if (shift) modifiers.setShift(true);
    return modifiers;
  }

  ArrangerPointerEvent _toArrangerPointerEvent(
    PointerEvent pointerEvent, {
    KeyboardModifiers? keyboardModifiers,
  }) {
    return ArrangerPointerEvent(
      offset: pixelsToTime(
        timeViewStart: viewModel.timeView.start,
        timeViewEnd: viewModel.timeView.end,
        viewPixelWidth: viewSize.width,
        pixelOffsetFromLeft: pointerEvent.localPosition.dx,
      ),
      track: viewModel.trackPositionCalculator.getTrackIndexFromPosition(
        pointerEvent.localPosition.dy,
      ),
      pointerEvent: pointerEvent,
      arrangerSize: viewSize,
      keyboardModifiers: keyboardModifiers ?? _keyboardModifiers(),
      contentUnderCursor: const ArrangerContentUnderCursor(),
    );
  }

  void pointerDown(
    PointerDownEvent pointerEvent, {
    KeyboardModifiers? keyboardModifiers,
  }) {
    controller.pointerDown(
      _toArrangerPointerEvent(
        pointerEvent,
        keyboardModifiers: keyboardModifiers,
      ),
    );
  }

  void pointerMove(
    PointerMoveEvent pointerEvent, {
    KeyboardModifiers? keyboardModifiers,
  }) {
    controller.pointerMove(
      _toArrangerPointerEvent(
        pointerEvent,
        keyboardModifiers: keyboardModifiers,
      ),
    );
  }

  void pointerUp(
    PointerEvent pointerEvent, {
    KeyboardModifiers? keyboardModifiers,
  }) {
    controller.pointerUp(
      _toArrangerPointerEvent(
        pointerEvent,
        keyboardModifiers: keyboardModifiers,
      ),
    );
  }

  void hover(Offset pos) {
    controller.onHover(PointerHoverEvent(position: pos));
  }

  void enter(Offset pos) {
    controller.onEnter(PointerEnterEvent(position: pos));
  }

  void exit(Offset pos) {
    controller.onExit(PointerExitEvent(position: pos));
  }

  void pressEscape() {
    controller.onRawKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
      ),
    );
  }

  void dispose() {
    controller.dispose();
    AnthemStore.instance.projects.remove(project.id);
    ServiceRegistry.removeProject(project.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ArrangerStateMachineTestFixture fixture;

  setUp(() {
    fixture = _ArrangerStateMachineTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  group('ArrangerIdleState', () {
    test('hover over track updates cursor location', () {
      fixture.hover(const Offset(120, 20));

      final cursorLocation = fixture.viewModel.cursorLocation;
      expect(cursorLocation, isNotNull);
      expect(cursorLocation!.$2, _TrackIds.a);
    });

    test('hover outside track clears cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.cursorLocation, isNotNull);

      fixture.hover(const Offset(120, -10));

      expect(fixture.viewModel.cursorLocation, isNull);
    });

    test('exit clears hover-derived cursor location', () {
      fixture.enter(const Offset(120, 20));
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.cursorLocation, isNotNull);

      fixture.exit(const Offset(120, 20));

      expect(fixture.viewModel.cursorLocation, isNull);
    });

    test('alt modifier disables snapping for cursor offset', () {
      const initialPos = Offset(13.25, 20);
      const altTestPos = Offset(17.25, 20);
      const releasedPos = Offset(21.25, 20);
      final rawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: altTestPos.dx,
      );
      final releasedRawOffset = pixelsToTime(
        timeViewStart: fixture.viewModel.timeView.start,
        timeViewEnd: fixture.viewModel.timeView.end,
        viewPixelWidth: _ArrangerStateMachineTestFixture.viewSize.width,
        pixelOffsetFromLeft: releasedPos.dx,
      );
      final expectedReleasedSnappedOffset = getSnappedTime(
        rawTime: releasedRawOffset.round(),
        divisionChanges: fixture.stateMachine.divisionChanges(),
        round: true,
      ).toDouble();

      fixture.hover(initialPos);
      final snappedOffset = fixture.viewModel.cursorLocation!.$1;

      fixture.stateMachine.modifierPressed(ArrangerModifierKey.alt);
      fixture.hover(altTestPos);
      final unsnappedOffset = fixture.viewModel.cursorLocation!.$1;

      fixture.stateMachine.modifierReleased(ArrangerModifierKey.alt);
      fixture.hover(releasedPos);
      final snappedOffsetAgain = fixture.viewModel.cursorLocation!.$1;

      expect(unsnappedOffset, closeTo(rawOffset, 1e-9));
      expect(unsnappedOffset, isNot(equals(snappedOffset)));
      expect(snappedOffsetAgain, expectedReleasedSnappedOffset);
    });

    test('view transform changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      final before = fixture.viewModel.cursorLocation!.$1;

      fixture.controller.onRenderedViewTransformChanged(
        timeViewStart: 120,
        timeViewEnd: 1080,
        verticalScrollPosition: fixture.viewModel.verticalScrollPosition,
      );

      final after = fixture.viewModel.cursorLocation!.$1;
      expect(after, isNot(equals(before)));
    });

    test('track layout changed recomputes cursor location', () {
      fixture.hover(const Offset(120, 20));
      expect(fixture.viewModel.cursorLocation!.$2, _TrackIds.a);

      fixture.project.trackOrder
        ..clear()
        ..addAll([_TrackIds.b, _TrackIds.a]);
      fixture.viewModel.trackPositionCalculator.invalidate(
        _ArrangerStateMachineTestFixture.editorHeight,
      );
      fixture.controller.onTrackLayoutChanged();

      expect(fixture.viewModel.cursorLocation, isNotNull);
      expect(fixture.viewModel.cursorLocation!.$2, _TrackIds.b);
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
  });

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
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
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
        expect(fixture.stateMachine.currentState, isA<ArrangerDragState>());

        fixture.pointerMove(
          const PointerMoveEvent(
            pointer: 1,
            buttons: kPrimaryMouseButton,
            position: Offset(86, 22),
          ),
        );
        expect(fixture.dragState.hasCrossedActivationDistance, isTrue);
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
      expect(fixture.dragState.hasCrossedActivationDistance, isFalse);
    });
  });

  group('ArrangerCreateClipState', () {
    void enterCreateClipState({
      Offset firstClickPos = const Offset(100, 20),
      Offset secondClickPos = const Offset(100, 20),
      Offset movePos = const Offset(180, 20),
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

    test('double-click drag delegates to create clip state', () {
      enterCreateClipState();

      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());
      expect(fixture.viewModel.clipCreateHint, isNotNull);
    });

    test('clip create hint is anchored to drag start track', () {
      enterCreateClipState(movePos: const Offset(220, 100));

      final hint = fixture.viewModel.clipCreateHint;
      expect(hint, isNotNull);
      expect(hint!.trackId, _TrackIds.a);
    });

    test('pointer move updates clip create hint end offset', () {
      enterCreateClipState(movePos: const Offset(180, 20));
      expect(fixture.stateMachine.currentState, isA<ArrangerCreateClipState>());

      final firstHint = fixture.viewModel.clipCreateHint!;

      fixture.pointerMove(
        const PointerMoveEvent(
          pointer: 1,
          buttons: kPrimaryMouseButton,
          position: Offset(420, 20),
        ),
      );

      final secondHint = fixture.viewModel.clipCreateHint!;
      expect(secondHint.endOffset, isNot(equals(firstHint.endOffset)));
    });

    test('pointer up with non-zero width creates one pattern and one clip', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
      final patternCountBefore = fixture.project.sequence.patterns.length;
      final clipCountBefore = arrangement.clips.length;

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
      expect(newClip.trackId, hint.trackId);
      expect(newClip.offset, expectedStart.round());
      expect(newClip.timeView, isNotNull);
      expect(newClip.timeView!.start, 0);
      expect(newClip.timeView!.end, expectedWidth.round());
    });

    test('pointer up with zero width does not create clip or pattern', () {
      final arrangementId = fixture.project.sequence.activeArrangementID!;
      final arrangement = fixture.project.sequence.arrangements[arrangementId]!;
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
        final arrangementId = fixture.project.sequence.activeArrangementID!;
        final arrangement =
            fixture.project.sequence.arrangements[arrangementId]!;
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
