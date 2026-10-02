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
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:anthem/app.dart';
import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/helpers/logging/anthem_logging.dart';
import 'package:anthem/logic/application_session.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/widgets/editors/arranger/rendering/content_renderer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_preferences.dart';
import 'waits.dart';

const logicalWindowSize = Size(1280, 800);
const configuredEngine = String.fromEnvironment('ANTHEM_TEST_ENGINE');
const configuredArtifacts = String.fromEnvironment('ANTHEM_TEST_ARTIFACTS');

/// Owns cleanup before any startup work. Files and logs stay in the run's
/// ignored artifact directory; each session gets a fresh settings instance.
class AppTestSession {
  final WidgetTester tester;
  final AnthemApplicationSession app;
  final Directory artifacts;
  final Duration startupTimeout;
  final List<TestGesture> _heldPointers = [];
  final Set<LogicalKeyboardKey> _heldKeys = {};
  Future<void>? _cleanup;

  ProjectModel get project => app.project;
  ServiceRegistry get services => ServiceRegistry.forProject(project.id);

  AppTestSession(
    this.tester, {
    required String name,
    String engineExecutable = configuredEngine,
    ProjectModel? initialProject,
    SharedPreferencesAsync? settings,
    this.startupTimeout = const Duration(seconds: 15),
  }) : artifacts = Directory('$configuredArtifacts/$name'),
       app = AnthemApplicationSession(
         initialProject: initialProject,
         engineExecutable: initialProject == null ? engineExecutable : null,
         startAudio: false,
         requireEngine: true,
         preferences: settings ?? MemoryPreferences(),
         logRoot: '$configuredArtifacts/logs',
       ) {
    addTearDown(dispose);
  }

  /// Current session details for failure messages and JSON debug artifacts.
  /// Rebuilt on access; reading these diagnostics does not check readiness.
  Map<String, Object?> get sessionDiagnostics => {
    'projectId': project.id,
    'engineId': project.engine.id,
    'engineState': project.engine.engineState.name,
    'enginePid': project.engine.processId,
    'engineExitCode': project.engine.processExitCode,
    'appPid': pid,
    'logs': AnthemLogManager.instance.activeSessionDirectoryPath,
  };

  Future<void> start() async {
    if (configuredArtifacts.isEmpty || configuredEngine.isEmpty) {
      throw StateError(
        'Use dart run anthem:cli integration-test to supply '
        'an explicit engine executable and artifact directory.',
      );
    }
    await artifacts.create(recursive: true);
    await tester.binding.setSurfaceSize(logicalWindowSize);
    await waitForFuture(
      tester,
      app.start(),
      conditionDescription:
          'application startup and initial model acknowledgment',
      collectTimeoutDiagnostics: () => sessionDiagnostics,
      timeout: startupTimeout,
    );
    await windowManager.setSize(logicalWindowSize);
    await waitUntil(
      tester,
      conditionDescription: 'main window and arranger canvas layout',
      isReady: () =>
          find.byKey(mainWindowKey).evaluate().length == 1 &&
          find.byType(ArrangerContentRenderer).evaluate().length == 1 &&
          tester.getSize(find.byType(ArrangerContentRenderer)).longestSide > 0,
      collectTimeoutDiagnostics: () => {
        ...sessionDiagnostics,
        'mainWindows': find.byKey(mainWindowKey).evaluate().length,
        'canvases': find.byType(ArrangerContentRenderer).evaluate().length,
      },
      checkHealth: checkEngine,
    );
    expect(tester.getSize(find.byKey(mainWindowKey)), logicalWindowSize);
    final canvas = tester.getRect(find.byType(ArrangerContentRenderer));
    expect(canvas.width, greaterThan(0));
    expect(canvas.height, greaterThan(0));
    expect((Offset.zero & logicalWindowSize).contains(canvas.topLeft), isTrue);
    expect(canvas.right, lessThanOrEqualTo(logicalWindowSize.width));
    expect(canvas.bottom, lessThanOrEqualTo(logicalWindowSize.height));
    await writeSessionDiagnostics(
      'started',
      additionalDiagnostics: {'canvasBounds': canvas.toString()},
    );
  }

  void checkEngine() {
    if (project.engine.engineState != EngineState.running) {
      throw StateError(
        'Engine exited while waiting. Session diagnostics: $sessionDiagnostics',
      );
    }
  }

  /// Each poll asks the real engine again. This observes its model only; it
  /// does not establish audio-thread adoption or audible output.
  Future<Map<String, dynamic>> waitForEngineModel({
    required String conditionDescription,
    required bool Function(Map<String, dynamic>) matches,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final clock = Stopwatch()..start();
    Map<String, dynamic>? lastModel;
    while (clock.elapsed < timeout) {
      checkEngine();
      final remaining = timeout - clock.elapsed;
      final json = await waitForFuture(
        tester,
        project.engine.modelSyncApi.debugGetEngineJson(
          timeout: remaining < const Duration(seconds: 2)
              ? remaining
              : const Duration(seconds: 2),
        ),
        conditionDescription: 'engine model query for $conditionDescription',
        collectTimeoutDiagnostics: () => sessionDiagnostics,
        timeout: remaining,
        checkHealth: checkEngine,
      );
      lastModel = jsonDecode(json) as Map<String, dynamic>;
      if (matches(lastModel)) {
        await File('${artifacts.path}/engine-model.json').writeAsString(json);
        return lastModel;
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    throw TimeoutException(
      'Waiting for $conditionDescription. Last engine model: $lastModel; '
      'session diagnostics: $sessionDiagnostics',
      timeout,
    );
  }

  Future<void> holdKey(LogicalKeyboardKey key) async {
    _heldKeys.add(key);
    await tester.sendKeyDownEvent(key);
  }

  Future<TestGesture> holdPointer(Offset location) async {
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    _heldPointers.add(pointer);
    await pointer.down(location);
    return pointer;
  }

  /// Holds physical keys for one action, releasing them even if it fails.
  /// Session teardown also owns them until their release succeeds.
  Future<void> withKeysHeld(
    List<LogicalKeyboardKey> keys,
    Future<void> Function() action,
  ) async {
    if (keys.toSet().length != keys.length ||
        keys.any(HardwareKeyboard.instance.logicalKeysPressed.contains)) {
      throw ArgumentError(
        'Shortcut keys must be distinct and not already held.',
      );
    }
    final pressed = <LogicalKeyboardKey>[];
    try {
      for (final key in keys) {
        pressed.add(key);
        await holdKey(key);
      }
      await action();
    } finally {
      for (final key in pressed.reversed) {
        await tester.sendKeyUpEvent(key);
        _heldKeys.remove(key);
      }
    }
  }

  /// Sends mouse down, the action's moves, and mouse up. A failed action sends
  /// cancel instead, so the app receives a complete pointer event sequence.
  Future<void> withMouseGesture({
    required Offset start,
    required Future<void> Function(TestGesture) action,
  }) async {
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    _heldPointers.add(pointer);
    var released = false;
    try {
      await pointer.down(start);
      await action(pointer);
      await pointer.up();
      released = true;
    } finally {
      if (!released) await pointer.cancel();
      _heldPointers.remove(pointer);
    }
  }

  /// Changes both the Flutter test surface and the native desktop window.
  /// Callers must then wait for their editor's rendered layout to match.
  Future<void> resizeWindow(Size size) async {
    await tester.binding.setSurfaceSize(size);
    await windowManager.setSize(size);
    await tester.pump();
  }

  /// Writes the current session diagnostics to `<lifecyclePhase>.json`.
  Future<void> writeSessionDiagnostics(
    String lifecyclePhase, {
    Map<String, Object?> additionalDiagnostics = const {},
  }) async {
    await artifacts.create(recursive: true);
    await File('${artifacts.path}/$lifecyclePhase.json').writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({...sessionDiagnostics, ...additionalDiagnostics}),
      flush: true,
    );
  }

  Future<void> dispose() => _cleanup ??= _dispose();

  Future<void> _dispose() async {
    try {
      for (final pointer in _heldPointers) {
        await pointer.cancel();
      }
      for (final key in _heldKeys) {
        await tester.sendKeyUpEvent(key);
      }
    } finally {
      try {
        // Guarded widget APIs finish before the polling helper starts pumping.
        await tester.pumpWidget(const SizedBox.shrink());
        await waitForFuture(
          tester,
          app.dispose(unmount: () async {}),
          conditionDescription: 'session cleanup and child process exit',
          checkFrameworkErrors: false,
          collectTimeoutDiagnostics: () => sessionDiagnostics,
          timeout: const Duration(seconds: 20),
        );
      } finally {
        await writeSessionDiagnostics('stopped');
        await tester.binding.setSurfaceSize(null);
      }
    }
    expect(project.engine.engineState, EngineState.stopped);
    if (project.engine.processId != null) {
      expect(
        project.engine.processExitCode,
        isNotNull,
        reason: 'Cleanup must await actual child process exit.',
      );
    }
  }
}
