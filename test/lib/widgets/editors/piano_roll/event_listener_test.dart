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

import 'package:anthem/model/pattern/note.dart';
import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/sequencer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/piano_roll_controller.dart';
import 'package:anthem/widgets/editors/piano_roll/controller/state_machine/piano_roll_state_machine.dart';
import 'package:anthem/widgets/editors/piano_roll/event_listener.dart';
import 'package:anthem/widgets/editors/piano_roll/helpers.dart';
import 'package:anthem/widgets/editors/piano_roll/view_model.dart';
import 'package:anthem/widgets/editors/shared/helpers/time_helpers.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _PianoRollEventListenerTestFixture {
  static const childKey = Key('piano-roll-event-listener-child');

  final ProjectModel project;
  final PatternModel pattern;
  final PianoRollViewModel viewModel;
  final PianoRollController controller;
  final KeyboardModifiers keyboardModifiers = KeyboardModifiers();

  _PianoRollEventListenerTestFixture._({
    required this.project,
    required this.pattern,
    required this.viewModel,
    required this.controller,
  });

  factory _PianoRollEventListenerTestFixture.create() {
    final project = ProjectModel()
      ..isHydrated = true
      ..sequence = SequencerModel.create();
    final pattern = PatternModel.create(name: 'Pattern 1');
    project.sequence.patterns[pattern.id] = pattern;
    project.sequence.setActivePattern(pattern.id);

    final viewModel = PianoRollViewModel(
      keyHeight: 14,
      keyValueAtTop: 63.95,
      timeView: TimeRange(0, 3072),
    );
    final controller = PianoRollController(
      project: project,
      viewModel: viewModel,
    );

    return _PianoRollEventListenerTestFixture._(
      project: project,
      pattern: pattern,
      viewModel: viewModel,
      controller: controller,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required Size viewSize,
    required double timeViewStart,
    required double timeViewEnd,
    required double keyHeight,
    required double keyValueAtTop,
  }) async {
    viewModel.timeView = TimeRange(timeViewStart, timeViewEnd);
    viewModel.keyHeight = keyHeight;
    viewModel.keyValueAtTop = keyValueAtTop;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PianoRollViewModel>.value(value: viewModel),
          Provider<PianoRollController>.value(value: controller),
          ChangeNotifierProvider<KeyboardModifiers>.value(
            value: keyboardModifiers,
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: PianoRollEventListener(
              viewSize: viewSize,
              renderedTimeViewStart: timeViewStart,
              renderedTimeViewEnd: timeViewEnd,
              renderedKeyHeight: keyHeight,
              renderedKeyValueAtTop: keyValueAtTop,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(
                  key: childKey,
                  width: viewSize.width,
                  height: viewSize.height,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset globalPositionForLocal(WidgetTester tester, Offset localPosition) {
    return tester.getTopLeft(find.byKey(childKey)) + localPosition;
  }

  PianoRollPointerSessionState get pointerSessionState =>
      controller.stateMachine.states[PianoRollPointerSessionState]!
          as PianoRollPointerSessionState;

  PianoRollCreateNoteState get createNoteState =>
      controller.stateMachine.states[PianoRollCreateNoteState]!
          as PianoRollCreateNoteState;

  List<NoteModel> get notes => pattern.notes.toList(growable: false);

  void dispose() {
    controller.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _PianoRollEventListenerTestFixture fixture;

  setUp(() {
    fixture = _PianoRollEventListenerTestFixture.create();
  });

  tearDown(() {
    fixture.dispose();
  });

  testWidgets('syncs rendered view metrics before forwarding pointer down', (
    tester,
  ) async {
    const viewSize = Size(300, 120);
    await fixture.pump(
      tester,
      viewSize: viewSize,
      timeViewStart: 480,
      timeViewEnd: 960,
      keyHeight: 20,
      keyValueAtTop: 72,
    );

    const localPosition = Offset(150, 40);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(fixture.globalPositionForLocal(tester, localPosition));
    await tester.pump();

    final startContext = fixture.pointerSessionState.startPointerContext;
    expect(startContext, isNotNull);
    expect(
      startContext!.offset,
      closeTo(
        pixelsToTime(
          timeViewStart: 480,
          timeViewEnd: 960,
          viewPixelWidth: viewSize.width,
          pixelOffsetFromLeft: localPosition.dx,
        ),
        0.0001,
      ),
    );
    expect(
      startContext.key,
      closeTo(
        pixelsToKeyValue(
          keyHeight: 20,
          keyValueAtTop: 72,
          pixelOffsetFromTop: localPosition.dy,
        ),
        0.0001,
      ),
    );
    expect(
      fixture.controller.stateMachine.currentState,
      same(fixture.createNoteState),
    );
  });

  testWidgets(
    'ignores middle-button presses before they reach the controller',
    (tester) async {
      await fixture.pump(
        tester,
        viewSize: const Size(300, 120),
        timeViewStart: 0,
        timeViewEnd: 480,
        keyHeight: 16,
        keyValueAtTop: 72,
      );

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.down(
        fixture.globalPositionForLocal(tester, const Offset(100, 40)),
      );
      await tester.pump();

      expect(fixture.controller.activeInteractionFamily, isNull);
      expect(
        fixture.controller.stateMachine.currentState,
        same(
          fixture.controller.stateMachine.states[PianoRollIdleState]
              as PianoRollIdleState,
        ),
      );
      expect(fixture.notes, isEmpty);
      expect(fixture.viewModel.transientNotes, isEmpty);
    },
  );

  testWidgets(
    'pointer cancel is forwarded as pointer up and finalizes the session',
    (tester) async {
      fixture.keyboardModifiers.setAlt(true);
      await fixture.pump(
        tester,
        viewSize: const Size(320, 120),
        timeViewStart: 0,
        timeViewEnd: 320,
        keyHeight: 16,
        keyValueAtTop: 72,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(
        fixture.globalPositionForLocal(tester, const Offset(100, 40)),
      );
      await tester.pump();
      await gesture.moveTo(
        fixture.globalPositionForLocal(tester, const Offset(180, 24)),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(fixture.notes, hasLength(1));
      final note = fixture.notes.single;
      expect(note.offset, equals(180));
      expect(note.key, equals(70));
      expect(fixture.controller.activeInteractionFamily, isNull);
      expect(fixture.viewModel.transientNotes, isEmpty);
    },
  );
}
