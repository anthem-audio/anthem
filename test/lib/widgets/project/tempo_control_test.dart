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

import 'package:anthem/logic/commands/sequence_commands.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/theme.dart';
import 'package:anthem/widgets/basic/button.dart';
import 'package:anthem/widgets/basic/controls/digit_control.dart';
import 'package:anthem/widgets/basic/digit_display.dart';
import 'package:anthem/widgets/basic/icon.dart' as anthem;
import 'package:anthem/widgets/basic/hint/hint_store.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_consumer.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:anthem/widgets/project/project_header.dart';
import 'package:anthem/widgets/project/project_view_model.dart';
import 'package:anthem/widgets/project/tempo_control.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late ProjectModel project;
  late ProjectController controller;

  setUp(() {
    project = ProjectModel.create()..isDirty = false;
    controller = ProjectController(project, ProjectViewModel());
    AnthemStore.instance.projects[project.id] = project;
    AnthemStore.instance.activeProjectId = project.id;
  });

  tearDown(() {
    AnthemStore.instance.projects.remove(project.id);
    AnthemStore.instance.activeProjectId = '';
    project.dispose();
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? outsideAction}) async {
    await tester.pumpWidget(
      material.MaterialApp(
        home: material.Scaffold(
          body: ScreenOverlay(
            child: MultiProvider(
              providers: [
                Provider.value(value: project),
                Provider.value(value: controller),
                ChangeNotifierProvider(create: (_) => KeyboardModifiers()),
              ],
              child: ShortcutProvider(
                child: ShortcutConsumer(
                  id: 'project',
                  global: true,
                  shortcutHandler: controller.onShortcut,
                  child: Column(
                    children: [
                      const ProjectHeader(),
                      GestureDetector(
                        key: const ValueKey('outside'),
                        behavior: HitTestBehavior.opaque,
                        onTap: outsideAction ?? () {},
                        child: const SizedBox(width: 200, height: 100),
                      ),
                      const material.TextField(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('menu starts pulsing with Tap... and preserves the layout', (
    tester,
  ) async {
    await pump(tester);
    final size = tester.getSize(find.byType(TempoControl));
    await _enterTapMode(tester);
    expect(find.text('Tap...'), findsOneWidget);
    expect(tester.getSize(find.byType(TempoControl)), size);
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    await tester.pump(const Duration(milliseconds: 300));
    final border = _display(tester).borderColor;
    expect(border, isNot(AnthemTheme.control.border));
    await tester.pump(const Duration(milliseconds: 350));
    expect(_display(tester).borderColor, isNot(border));
    await _escape(tester);
  });

  testWidgets('first tap pulses once and cannot time out', (tester) async {
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    expect(_display(tester).borderColor, AnthemTheme.primary.main);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Tap...'), findsOneWidget);
    expect(_display(tester).borderColor, AnthemTheme.control.border);
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    expect(project.isDirty, isFalse);
    await _escape(tester);
  });

  testWidgets(
    'updates each tap, resets the deadline, and commits one undo action',
    (tester) async {
      project.sequence.beatsPerMinuteRaw = 12837;
      await pump(tester);
      await _enterTapMode(tester);
      await _tapAt(tester, Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));
      await _tapAt(tester, const Duration(microseconds: 499500));
      expect(project.sequence.beatsPerMinuteRaw, 12000);
      expect(find.text('120.00'), findsOneWidget);
      expect(project.isDirty, isFalse);
      await tester.pump(const Duration(milliseconds: 250));
      await _tapAt(tester, const Duration(microseconds: 749500));
      expect(project.sequence.beatsPerMinuteRaw, 16000);
      expect(find.text('160.00'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(
        find.descendant(
          of: find.byType(TempoControl),
          matching: find.byType(DigitControl),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.descendant(
          of: find.byType(TempoControl),
          matching: find.byType(DigitControl),
        ),
        findsOneWidget,
      );
      expect(project.isDirty, isTrue);
      controller.undo();
      expect(project.sequence.beatsPerMinuteRaw, 12837);
      controller.undo(); // There must be no second tempo edit to undo.
      expect(project.sequence.beatsPerMinuteRaw, 12837);
      controller.redo();
      expect(project.sequence.beatsPerMinuteRaw, 16000);
      await tester.pump();
    },
  );

  testWidgets(
    'Escape restores tempo without disturbing existing redo history',
    (tester) async {
      project.execute(SetTempoCommand(oldRawTempo: 12800, newRawTempo: 14000));
      controller.undo();
      project.isDirty = false;
      await pump(tester);
      await _enterTapMode(tester);
      await _tapAt(tester, Duration.zero);
      await _tapAt(tester, const Duration(milliseconds: 500));
      await _escape(tester);
      expect(project.sequence.beatsPerMinuteRaw, 12800);
      expect(project.isDirty, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(project.sequence.beatsPerMinuteRaw, 12800);
      controller.redo();
      expect(project.sequence.beatsPerMinuteRaw, 14000);
      await tester.pump();
    },
  );

  testWidgets(
    'outside click reverts before its action runs and still reaches it',
    (tester) async {
      int? tempoWhenClicked;
      await pump(
        tester,
        outsideAction: () {
          tempoWhenClicked = project.sequence.beatsPerMinuteRaw;
        },
      );
      await _enterTapMode(tester);
      await _tapAt(tester, Duration.zero);
      await _tapAt(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('outside')));
      await tester.pump();
      expect(tempoWhenClicked, 12800);
      expect(controller.cancelTempoTap, isNull);
    },
  );

  for (final entry in {
    'Undo': anthem.Icons.undo,
    'Redo': anthem.Icons.redo,
  }.entries) {
    final icon = entry.value;
    testWidgets(
      '${entry.key} button cancels tapping without changing older history',
      (tester) async {
        project.execute(
          SetTempoCommand(oldRawTempo: 12800, newRawTempo: 14000),
        );
        if (icon == anthem.Icons.redo) controller.undo();
        final original = project.sequence.beatsPerMinuteRaw;
        await pump(tester);
        await _enterTapMode(tester);
        await _tapAt(tester, Duration.zero);
        await _tapAt(tester, const Duration(milliseconds: 500));
        final button = find.byWidgetPredicate(
          (w) => w is Button && w.icon == icon,
        );
        await tester.tap(button);
        await tester.pump();
        expect(project.sequence.beatsPerMinuteRaw, original);
        if (icon == anthem.Icons.undo) {
          controller.undo();
          expect(project.sequence.beatsPerMinuteRaw, 12800);
        } else {
          controller.redo();
          expect(project.sequence.beatsPerMinuteRaw, 14000);
        }
        await tester.pump();
      },
    );
  }

  testWidgets('keyboard Undo cancels tapping', (tester) async {
    project.execute(SetTempoCommand(oldRawTempo: 12800, newRawTempo: 14000));
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(project.sequence.beatsPerMinuteRaw, 14000);
    expect(controller.cancelTempoTap, isNull);
    controller.undo();
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    await tester.pump();
  });

  testWidgets('unchanged estimate creates no undo entry', (tester) async {
    project.execute(SetTempoCommand(oldRawTempo: 12800, newRawTempo: 12000));
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    controller.undo();
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    await tester.pump();
  });

  testWidgets('switching projects cancels the pending timer', (tester) async {
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    AnthemStore.instance.activeProjectId = 'another-project';
    await tester.pump(const Duration(seconds: 3));
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    expect(project.isDirty, isFalse);
    expect(controller.cancelTempoTap, isNull);
  });

  testWidgets('removing the widget restores tempo and releases the session', (
    tester,
  ) async {
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    expect(controller.cancelTempoTap, isNull);
    expect(project.isDirty, isFalse);
  });

  testWidgets('tap mode takes focus from a text field so Escape still works', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byType(material.TextField));
    await tester.pump();
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    await _escape(tester);
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    expect(controller.cancelTempoTap, isNull);
  });

  testWidgets('closing a project cancels while its widget is still mounted', (
    tester,
  ) async {
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    project.dispose();
    AnthemStore.instance.projects.remove(project.id);
    await tester.pump(const Duration(seconds: 3));
    expect(project.sequence.beatsPerMinuteRaw, 12800);
    expect(controller.cancelTempoTap, isNull);
    expect(project.isDirty, isFalse);
  });

  testWidgets('a reused tempo widget binds to its replacement project', (
    tester,
  ) async {
    await pump(tester);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    final previousProject = project;
    final previousController = controller;
    addTearDown(() {
      AnthemStore.instance.projects.remove(previousProject.id);
      previousProject.dispose();
    });
    project = ProjectModel.create();
    project.sequence.beatsPerMinuteRaw = 9600;
    controller = ProjectController(project, ProjectViewModel());
    AnthemStore.instance.projects[project.id] = project;
    AnthemStore.instance.activeProjectId = project.id;
    await pump(tester);
    // Project construction defers a hydration check with a zero-delay timer.
    await tester.pump(Duration.zero);
    expect(previousProject.sequence.beatsPerMinuteRaw, 12800);
    expect(previousController.cancelTempoTap, isNull);
    final normal = tester.widget<DigitControl>(
      find.descendant(
        of: find.byType(TempoControl),
        matching: find.byType(DigitControl),
      ),
    );
    expect(normal.value, 96);
    await _enterTapMode(tester);
    await _tapAt(tester, Duration.zero);
    await _tapAt(tester, const Duration(milliseconds: 500));
    await _escape(tester);
    expect(project.sequence.beatsPerMinuteRaw, 9600);
    expect(previousProject.sequence.beatsPerMinuteRaw, 12800);
  });

  testWidgets('removes the tap hint when cancelling under the mouse', (
    tester,
  ) async {
    await pump(tester);
    await _enterTapMode(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(TempoControl)),
    );
    await tester.pump();
    expect(
      HintStore.instance.getActiveHint()!.any(
        (section) => section.action == 'Esc',
      ),
      isTrue,
    );
    await _escape(tester);
    expect(
      HintStore.instance.getActiveHint()?.any(
            (section) => section.action == 'Esc',
          ) ??
          false,
      isFalse,
    );
    await mouse.removePointer();
  });
}

Future<void> _enterTapMode(WidgetTester tester) async {
  await tester.tap(find.byType(TempoControl), buttons: kSecondaryButton);
  await tester.pump();
  expect(find.text('Tap for BPM...'), findsOneWidget);
  await tester.tap(find.text('Tap for BPM...'));
  await tester.pump();
}

Future<void> _tapAt(WidgetTester tester, Duration timestamp) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(
    tester.getCenter(find.byType(TempoControl)),
    timeStamp: timestamp,
  );
  await gesture.up(timeStamp: timestamp);
  await tester.pump();
}

DigitDisplay _display(WidgetTester tester) => tester.widget<DigitDisplay>(
  find.descendant(
    of: find.byType(TempoControl),
    matching: find.byType(DigitDisplay),
  ),
);

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
}
