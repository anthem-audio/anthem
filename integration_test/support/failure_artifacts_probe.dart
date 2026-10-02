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

import 'dart:async';
import 'dart:io';

import 'package:anthem/model/pattern/pattern.dart';
import 'package:anthem/widgets/editors/shared/helpers/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_session.dart';
import 'piano_roll_test_driver.dart';

/// Explicitly selected by --test-failure-handling. Every case must fail.
/// This file is excluded from normal *_test.dart discovery.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testAppScenario('assertion failure retains the edited frame', (tester) async {
    final session = AppTestSession(tester, name: 'assertion-probe');
    await session.start();
    final pattern = PatternModel(
      idAllocator: session.project.idAllocator,
      name: 'Failure fixture',
    );
    session.project.sequence.patterns[pattern.id] = pattern;
    session.services.trackController.setActiveTrack(
      session.project.trackOrder.first,
    );
    final pianoRoll = PianoRollTestDriver(session);
    await pianoRoll.configureFixture(
      patternId: pattern.id,
      timeStart: 0,
      timeEnd: 384,
      pitchAtTop: 64,
      keyHeight: 16,
      tool: EditorTool.pencil,
      noteLength: 96,
      noteVelocity: 0.625,
      notePan: -0.25,
      expectedSnapTicks: 24,
    );
    await pianoRoll.drawNote(rawTick: 52, pitch: 60, moveToTick: 80);
    session.registerFailureDiagnostics(
      'brokenCollector',
      () => throw StateError('Intentional collector failure'),
    );
    await session.holdKey(LogicalKeyboardKey.shiftLeft);
    await session.holdPointer(
      pianoRoll.emptyCanvasPoint(rawTick: 240, pitch: 58),
    );
    // Empty-canvas input clears selection. Establish this diagnostic fixture
    // afterward, while leaving the pointer and modifier held for cleanup.
    session.services.pianoRollViewModel.selectedNotes.add(
      pattern.notes.keys.single,
    );
    await tester.pump();
    expect(pattern.notes, isEmpty, reason: 'Intentional assertion probe');
  });
  testAppScenario('framework error retains its original failure', (
    tester,
  ) async {
    final session = AppTestSession(tester, name: 'framework-probe');
    await session.start();
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('Intentional framework probe')),
    );
    // Capture must also handle a surface awaiting paint at the time of failure.
    tester.renderObject(find.byType(RepaintBoundary).first).markNeedsPaint();
  });
  testAppScenario('unawaited error is captured during teardown', (
    tester,
  ) async {
    final session = AppTestSession(tester, name: 'unawaited-probe');
    await session.start();
    unawaited(
      Future<void>(() => throw StateError('Intentional unawaited probe')),
    );
    // The binding must fail and run teardown even if the body never completes.
    await Completer<void>().future;
  });
  testAppScenario('unresponsive engine cannot block failure evidence', (
    tester,
  ) async {
    final session = AppTestSession(tester, name: 'unresponsive-engine-probe');
    await session.start();
    final childPid = session.project.engine.processId!;
    addTearDown(() {
      // Resume before the session's teardown so normal graceful exit still works.
      Process.killPid(childPid, ProcessSignal.sigcont);
    });
    if (!Process.killPid(childPid, ProcessSignal.sigstop)) {
      throw StateError('Could not pause the probe engine.');
    }
    throw StateError('Intentional unresponsive engine probe');
  });
  testAppScenario('startup failure records the absence of a frame', (
    tester,
  ) async {
    final session = AppTestSession(
      tester,
      name: 'startup-failure-probe',
      engineExecutable: '$configuredEngine.missing-probe',
    );
    await session.start();
  });
}
