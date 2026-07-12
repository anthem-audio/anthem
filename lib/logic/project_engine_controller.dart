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

import 'package:anthem/engine_api/engine.dart';
import 'package:anthem/logic/disposable_service.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/model/project.dart';
import 'package:logging/logging.dart';

final _log = Logger('project_engine_controller');

class ProjectEngineController implements DisposableService {
  final ProjectModel project;
  final ProjectController projectController;

  late final StreamSubscription<EngineState> _engineStateSubscription;
  late final StreamSubscription<String?> _audioSessionInvalidatedSubscription;

  Future<void>? _processStartFuture;
  Future<void>? _processStopFuture;
  Future<void>? _audioStartFuture;
  Future<void>? _audioStopFuture;
  Future<void>? _audioSessionInvalidationFuture;

  bool _didFinishStartupForCurrentProcess = false;

  ProjectEngineController(this.project, this.projectController) {
    _engineStateSubscription = project.engine.engineStateStream.listen((state) {
      if (state == EngineState.stopped) {
        _handleProcessStopped();
      }
    });

    _audioSessionInvalidatedSubscription = project
        .engine
        .audioSessionInvalidatedStream
        .listen(_handleAudioSessionInvalidated);
  }

  Future<void> start({bool startAudio = true}) async {
    final existingStart = _processStartFuture;
    if (existingStart != null) {
      await existingStart;
    } else {
      final startFuture = _startProcess();
      _processStartFuture = startFuture;

      try {
        await startFuture;
      } finally {
        if (identical(_processStartFuture, startFuture)) {
          _processStartFuture = null;
        }
      }
    }

    if (startAudio) {
      try {
        await this.startAudio();
        await projectController.publishProcessingGraph();
      } catch (error, stackTrace) {
        _log.warning(
          'Could not start audio session for project ${project.id} during engine startup.',
          error,
          stackTrace,
        );
      }
    }
  }

  Future<void> _startProcess() async {
    if (project.engine.engineState != EngineState.running) {
      await project.engine.start(initializeAudio: false);
    }

    if (project.engine.engineState != EngineState.running) {
      return;
    }

    _finishStartupForCurrentProcess();
  }

  Future<void> stop() async {
    final existingStop = _processStopFuture;
    if (existingStop != null) {
      return existingStop;
    }

    final stopFuture = _stopProcess();
    _processStopFuture = stopFuture;

    try {
      await stopFuture;
    } finally {
      if (identical(_processStopFuture, stopFuture)) {
        _processStopFuture = null;
      }
    }
  }

  Future<void> _stopProcess() async {
    project.sequence.isPlaying = false;
    await project.engine.stop();
    _handleProcessStopped();
  }

  Future<void> startAudio() async {
    final existingStart = _audioStartFuture;
    if (existingStart != null) {
      return existingStart;
    }

    final startFuture = _startAudio();
    _audioStartFuture = startFuture;

    try {
      await startFuture;
    } finally {
      if (identical(_audioStartFuture, startFuture)) {
        _audioStartFuture = null;
      }
    }
  }

  Future<void> _startAudio() async {
    if (project.engine.engineState != EngineState.running) {
      await start(startAudio: false);
    }

    if (project.engine.engineState != EngineState.running) {
      return;
    }

    _finishStartupForCurrentProcess();

    if (project.engine.audioConfig == null) {
      await project.engine.startAudio();
    }
  }

  Future<void> stopAudio() async {
    final existingStop = _audioStopFuture;
    if (existingStop != null) {
      return existingStop;
    }

    final stopFuture = _stopAudio();
    _audioStopFuture = stopFuture;

    try {
      await stopFuture;
    } finally {
      if (identical(_audioStopFuture, stopFuture)) {
        _audioStopFuture = null;
      }
    }
  }

  Future<void> _stopAudio() async {
    project.sequence.isPlaying = false;
    await project.engine.stopAudio();
  }

  void _handleAudioSessionInvalidated(String? reason) {
    if (_audioSessionInvalidationFuture != null) {
      return;
    }

    final restartFuture = _restartAudioSessionAfterInvalidation(reason);
    _audioSessionInvalidationFuture = restartFuture;

    unawaited(
      restartFuture.whenComplete(() {
        if (identical(_audioSessionInvalidationFuture, restartFuture)) {
          _audioSessionInvalidationFuture = null;
        }
      }),
    );
  }

  Future<void> _restartAudioSessionAfterInvalidation(String? reason) async {
    if (project.engine.engineState != EngineState.running) {
      return;
    }

    project.sequence.isPlaying = false;

    try {
      await stopAudio();
      await startAudio();
      await projectController.publishProcessingGraph();
    } catch (error, stackTrace) {
      _log.warning(
        'Could not restart audio session for project ${project.id}'
        '${reason == null ? '' : ' after invalidation: $reason'}.',
        error,
        stackTrace,
      );
    }
  }

  void _finishStartupForCurrentProcess() {
    if (_didFinishStartupForCurrentProcess) {
      return;
    }

    project.completeFirstEngineSync();

    for (final arrangement in project.sequence.arrangements.values) {
      project.engine.sequencerApi.compileArrangement(arrangement.id);
    }

    for (final pattern in project.sequence.patterns.values) {
      project.engine.sequencerApi.compilePattern(pattern.id);
    }

    _didFinishStartupForCurrentProcess = true;
  }

  void _handleProcessStopped() {
    _didFinishStartupForCurrentProcess = false;
    project.handleEngineStopped();
  }

  @override
  void dispose() {
    _engineStateSubscription.cancel();
    _audioSessionInvalidatedSubscription.cancel();
  }
}
