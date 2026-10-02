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

import 'package:anthem/app.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/commands/sequence_commands.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/store.dart';
import 'package:anthem/widgets/basic/overlay/screen_overlay_view_model.dart';
import 'package:anthem/widgets/basic/shortcuts/shortcut_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'support/app_test_session.dart';
import 'support/waits.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testAppScenario(
    'startup, shutdown, and a fresh session in the same process',
    (tester) async {
      final first = AppTestSession(tester, name: 'first');
      await first.start();
      final firstPid = first.project.engine.processId;
      expect(firstPid, isNotNull);
      expect(first.project.engine.isAudioReady, isFalse);
      expect(AnthemStore.instance.activeProjectId, first.project.id);
      final initialTempo = first.project.sequence.beatsPerMinuteRaw;
      final trackId = first.project.trackOrder.first;
      await first.waitForEngineModel(
        conditionDescription: 'initial tempo and track in engine model',
        matches: (model) =>
            (model['sequence'] as Map)['beatsPerMinuteRaw'] == initialTempo &&
            (model['tracks'] as Map)['$trackId']['name'] == 'Track 1',
      );

      // Leave meaningful state behind to prove it belongs to this session.
      first.project.execute(
        SetTempoCommand(newRawTempo: 19900, oldRawTempo: initialTempo),
      );
      first.services.arrangerViewModel.selectedTracks.add(trackId);
      first.services.pianoRollViewModel.selectedNotes.add(999);
      await ServiceRegistry.preferences.setString('session-marker', 'first');
      final firstOverlay = ServiceRegistry.screenOverlayController;
      var overlayClosed = false;
      firstOverlay.show(
        ScreenOverlayEntry(
          builder: (_) => const Positioned(
            left: 0,
            top: 0,
            child: SizedBox(width: 10, height: 10),
          ),
          onClose: () => overlayClosed = true,
        ),
      );
      ServiceRegistry.mainWindowController.pushCursorOverride(
        SystemMouseCursors.grabbing,
      );
      ServiceRegistry.dialogController.showDialog(
        content: const SizedBox(width: 20, height: 20),
        title: 'Session dialog',
      );
      await first.holdKey(LogicalKeyboardKey.controlLeft);
      final modifiers = Provider.of<KeyboardModifiers>(
        mainWindowKey.currentContext!,
        listen: false,
      );
      expect(modifiers.control, isTrue);
      await first.holdPointer(const Offset(640, 400));
      await first.dispose();
      await first.dispose();
      expect(overlayClosed, isTrue);
      expect(firstOverlay.viewModel.entries, isEmpty);
      expect(first.project.engine.processExitCode, isNotNull);
      expect(AnthemStore.instance.projects, isEmpty);
      expect(AnthemStore.instance.projectOrder, isEmpty);
      expect(AnthemStore.instance.activeProjectId, isEmpty);
      expect(ServiceRegistry.maybeForProject(first.project.id), isNull);
      expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);

      final second = AppTestSession(tester, name: 'second');
      await second.start();
      expect(second.project.id, isNot(first.project.id));
      expect(second.project.engine.id, isNot(first.project.engine.id));
      expect(second.project.engine.processId, isNot(firstPid));
      expect(second.project.engine.isAudioReady, isFalse);
      expect(second.services.arrangerViewModel.selectedTracks, isEmpty);
      expect(second.services.arrangerViewModel.selectedClips, isEmpty);
      expect(second.services.pianoRollViewModel.selectedNotes, isEmpty);
      expect(
        second.services.projectViewModel.topPanelOverlayContentBuilder,
        isNull,
      );
      expect(
        ServiceRegistry.screenOverlayController,
        isNot(same(firstOverlay)),
      );
      expect(
        ServiceRegistry.screenOverlayController.viewModel.entries,
        isEmpty,
      );
      expect(
        ServiceRegistry.mainWindowViewModel.globalCursor,
        MouseCursor.defer,
      );
      expect(ServiceRegistry.clipboard.hasData, isFalse);
      expect(
        await ServiceRegistry.preferences.getString('session-marker'),
        isNull,
      );
      final secondModifiers = Provider.of<KeyboardModifiers>(
        mainWindowKey.currentContext!,
        listen: false,
      );
      expect(
        secondModifiers.control ||
            secondModifiers.shift ||
            secondModifiers.alt ||
            secondModifiers.meta,
        isFalse,
      );
      expect(find.text('Session dialog'), findsNothing);
      second.project.undo();
      second.project.redo();
      expect(
        second.project.isDirty,
        isFalse,
        reason: 'Fresh history has no commands to undo or redo.',
      );
      expect(second.project.sequence.beatsPerMinuteRaw, initialTempo);
      await second.waitForEngineModel(
        conditionDescription: 'fresh tempo in second engine model',
        matches: (model) =>
            (model['sequence'] as Map)['beatsPerMinuteRaw'] == initialTempo,
      );
      await second.dispose();
    },
  );

  testAppScenario(
    'missing engine fails clearly and partial startup can close',
    (tester) async {
      final session = AppTestSession(
        tester,
        name: 'missing-engine',
        engineExecutable: '$configuredArtifacts/missing-engine',
      );
      await expectLater(
        session.start(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Engine startup failed'),
          ),
        ),
      );
      await session.dispose();
      await session.dispose();
      expect(session.project.engine.processId, isNull);
      expect(AnthemStore.instance.projects, isEmpty);
      expect(ServiceRegistry.maybeForProject(session.project.id), isNull);
    },
  );

  testAppScenario('startup timeout kills and reaps an unconnected child', (
    tester,
  ) async {
    final executable = File('$configuredArtifacts/unconnected-engine.sh');
    await executable.parent.create(recursive: true);
    // exec preserves the PID: this child never opens the IPC socket.
    await executable.writeAsString('#!/bin/sh\nexec sleep 60\n');
    final chmod = await Process.run('chmod', ['+x', executable.path]);
    expect(chmod.exitCode, 0);
    final session = AppTestSession(
      tester,
      name: 'startup-timeout',
      engineExecutable: executable.path,
      startupTimeout: const Duration(seconds: 10),
    );
    await expectLater(
      session.start(),
      throwsA(
        isA<TimeoutException>().having(
          (error) => error.message,
          'message',
          contains('initial model acknowledgment'),
        ),
      ),
    );
    expect(session.project.engine.processId, isNotNull);
    expect(session.project.engine.engineState, EngineState.starting);
    await session.dispose();
    expect(session.project.engine.processExitCode, isNotNull);
    expect(AnthemStore.instance.projects, isEmpty);

    // An aborted startup must also release the global session ownership.
    final recovery = AppTestSession(tester, name: 'after-timeout');
    await recovery.start();
    await recovery.dispose();
  });

  testAppScenario(
    'readiness timeout reports the condition and timeout diagnostics',
    (tester) async {
      await expectLater(
        () => waitUntil(
          tester,
          conditionDescription: 'example missing condition',
          isReady: () => false,
          collectTimeoutDiagnostics: () => 'example debug details',
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('example missing condition'),
              contains('Timeout diagnostics: example debug details'),
            ),
          ),
        ),
      );
      final error = StateError('example operation failed');
      await expectLater(
        () => waitForFuture<void>(
          tester,
          Future<void>.error(error),
          conditionDescription: 'example operation',
          collectTimeoutDiagnostics: () => 'pending',
        ),
        throwsA(same(error)),
      );
    },
  );
}
