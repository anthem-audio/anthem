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

import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/state_machine/timeline_state_machine.dart';
import 'package:anthem/widgets/editors/shared/timeline/controller/timeline_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _TimelineControllerTestFixture {
  final ProjectModel project;
  final PatternModel pattern;
  final TimelineController controller;

  _TimelineControllerTestFixture._({
    required this.project,
    required this.pattern,
    required this.controller,
  });

  factory _TimelineControllerTestFixture.create() {
    final project = ProjectModel.create();
    final pattern = PatternModel.create(name: 'Pattern 1');
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
    );
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
      'pending loop-handle press syncs into pointer session and clears on cancel',
      () {
        final controller = fixture.controller;

        controller.pointerDown(
          const PointerDownEvent(
            pointer: 7,
            position: Offset(32, 5),
            buttons: kPrimaryButton,
          ),
        );
        controller.registerPendingLoopHandlePress(
          pointerId: 7,
          handle: TimelineLoopHandle.end,
        );

        final pointerSessionState =
            controller.stateMachine.currentState as TimelinePointerSessionState;
        expect(pointerSessionState.pressedLoopHandle, TimelineLoopHandle.end);
        expect(
          controller.stateMachine.data.pendingLoopHandlePress?.pointerId,
          7,
        );

        controller.pointerCancel(
          const PointerCancelEvent(pointer: 7, position: Offset(32, 5)),
        );

        expect(controller.stateMachine.currentState, isA<TimelineIdleState>());
        expect(controller.stateMachine.data.pendingLoopHandlePress, isNull);
        expect(controller.stateMachine.data.activePointerId, isNull);
      },
    );
  });
}
