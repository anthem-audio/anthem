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
import 'package:anthem/helpers/logging/anthem_logging.dart';
import 'package:anthem/licenses.dart';
import 'package:anthem/logic/service_registry.dart';
import 'package:anthem/model/project.dart';
import 'package:anthem/model/store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../web_init_stub.dart' if (dart.library.js_interop) '../web_init.dart';

final _log = Logger('app');
Future<void>? _initialization;
AnthemApplicationSession? _activeSession;

Future<void> _initializeApplication(String? logRoot) async {
  await AnthemLogManager.instance.initialize(
    rootDirectory: logRoot == null ? null : Directory(logRoot),
  );
  await pointerLock.ensureInitialized();
  addLicenses();

  if (!kIsWeb) {
    await windowManager.ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: true,
      );
    } else {
      await windowManager.setAsFrameless();
    }
  }
  webInit();
}

/// One mounted application and its projects. Native plugins and logging are
/// initialized once per process; project services and transient UI state are
/// released when the session closes. The caller must dispose even after a
/// failed or timed-out start.
class AnthemApplicationSession {
  final ProjectModel project;
  final bool startAudio;
  final bool requireEngine;
  final SharedPreferencesAsync? preferences;
  final String? logRoot;

  /// Optional host wrapper, used by tests to capture the Flutter surface.
  final Widget Function(Widget child)? wrapRoot;

  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
  bool _mounted = false;
  bool _ownsSession = false;
  FlutterExceptionHandler? _previousFlutterError;
  FlutterExceptionHandler? _flutterErrorHandler;
  bool Function(Object, StackTrace)? _previousPlatformError;
  bool Function(Object, StackTrace)? _platformErrorHandler;

  AnthemApplicationSession({
    ProjectModel? initialProject,
    String? engineExecutable,
    this.startAudio = true,
    this.requireEngine = false,
    this.preferences,
    this.logRoot,
    this.wrapRoot,
  }) : project = initialProject ?? ProjectModel.create(engineExecutable) {
    if (initialProject != null && engineExecutable != null) {
      throw ArgumentError(
        'Supply the engine path when constructing initialProject, or supply '
        'engineExecutable with the default project.',
      );
    }
  }

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (_disposeFuture != null) throw StateError('Session is already closed.');
    if (_activeSession != null || AnthemStore.instance.projects.isNotEmpty) {
      throw StateError(
        'Close the current application session before starting another.',
      );
    }
    _activeSession = this;
    _ownsSession = true;
    _installErrorLogging();

    await (_initialization ??= _initializeApplication(logRoot));
    _checkOpen();
    ServiceRegistry.setSessionPreferences(preferences);
    _log.info('Starting Anthem session for project ${project.id}.');
    await ServiceRegistry.mainWindowController.openProject(
      project,
      startAudio: startAudio,
    );
    _checkOpen();
    if (requireEngine && project.engine.engineState != EngineState.running) {
      throw StateError(
        'Engine startup failed for project ${project.id} '
        '(executable: ${project.engine.enginePathOverride ?? "default"}; '
        'state: ${project.engine.engineState.name}). See the engine logs.',
      );
    }
    if (project.engine.engineState == EngineState.running) {
      await project.waitForFirstSync();
    }
    _checkOpen();
    runApp(wrapRoot?.call(const App()) ?? const App());
    _mounted = true;
  }

  void _checkOpen() {
    if (_disposeFuture != null) {
      throw StateError('Session closed during startup.');
    }
  }

  void _installErrorLogging() {
    _previousFlutterError = FlutterError.onError;
    _flutterErrorHandler = (details) {
      _log.severe(
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      // In integration tests this is the binding's failure reporter.
      (_previousFlutterError ?? FlutterError.presentError)(details);
    };
    FlutterError.onError = _flutterErrorHandler;

    _previousPlatformError = PlatformDispatcher.instance.onError;
    _platformErrorHandler = (error, stackTrace) {
      _log.severe('Unhandled platform error', error, stackTrace);
      return _previousPlatformError?.call(error, stackTrace) ?? false;
    };
    PlatformDispatcher.instance.onError = _platformErrorHandler;
  }

  /// Unmount before releasing project services. A harness can supply its own
  /// awaited pumpWidget here; production uses the next rendered frame.
  Future<void> dispose({Future<void> Function()? unmount}) =>
      _disposeFuture ??= _dispose(unmount);

  Future<void> _dispose(Future<void> Function()? unmount) async {
    Object? failure;
    StackTrace? failureStack;
    Future<void> cleanup(FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error, stackTrace) {
        failure ??= error;
        failureStack ??= stackTrace;
      }
    }

    await cleanup(() async {
      if (_mounted) {
        if (unmount != null) {
          await unmount();
        } else {
          runApp(const SizedBox.shrink());
          await WidgetsBinding.instance.endOfFrame;
        }
        _mounted = false;
      }
    });
    // Stop all owned engines even when another cleanup action fails.
    final projects = _ownsSession
        ? AnthemStore.instance.projects.values.toList()
        : <ProjectModel>[];
    await cleanup(project.engine.dispose);
    for (final openProject in projects) {
      await cleanup(openProject.engine.dispose);
      await cleanup(
        () => ServiceRegistry.mainWindowController.closeProjectWithoutSaving(
          openProject.id,
        ),
      );
    }
    if (!projects.contains(project)) await cleanup(project.dispose);
    if (_ownsSession) {
      await cleanup(
        ServiceRegistry.mainWindowController.clearAllCursorOverrides,
      );
      await cleanup(ServiceRegistry.clipboard.clear);
      ServiceRegistry.setSessionPreferences(null);
      _activeSession = null;
    }
    if (identical(FlutterError.onError, _flutterErrorHandler)) {
      FlutterError.onError = _previousFlutterError;
    }
    if (identical(PlatformDispatcher.instance.onError, _platformErrorHandler)) {
      PlatformDispatcher.instance.onError = _previousPlatformError;
    }
    await cleanup(AnthemLogManager.instance.flush);
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }
}
