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

part of 'package:anthem/engine_api/engine.dart';

/// Owns audio-session commands, configuration, and invalidation notifications.
///
/// Successful start and stop responses and audio events update the confirmed
/// configuration. Starting or stopping the engine process clears it.
class EngineAudioSession {
  final Engine _engine;
  AudioProcessingConfigDto? _config;
  final StreamController<String?> _invalidationController =
      StreamController.broadcast();

  EngineAudioSession(this._engine);

  /// Whether the engine has confirmed an active audio session.
  bool get isReady => _config != null;

  /// The confirmed configuration, available after engine startup completes.
  AudioProcessingConfigDto? get config => _engine.isRunning ? _config : null;

  /// Reports audio sessions invalidated by the engine, with an optional reason.
  Stream<String?> get invalidatedStream => _invalidationController.stream;

  void _handleEngineStateChanged(EngineState state) {
    if (state != EngineState.running) {
      _config = null;
    }
  }

  void _handleResponse(Response response) {
    switch (response) {
      case StartAudioResponse e when e.success && e.audioConfig != null:
        _config = e.audioConfig;
        return;
      case StartRenderAudioSessionResponse e
          when e.success && e.audioConfig != null:
        _config = e.audioConfig;
        return;
      case StopAudioResponse e when e.success:
        _config = null;
        return;
      default:
        return;
    }
  }

  bool _handleEvent(IpcEvent event) {
    switch (event) {
      case AudioReadyEvent e:
        _config = e.audioConfig;
        return true;
      case AudioSessionInvalidatedEvent e:
        _config = null;
        if (!_invalidationController.isClosed) {
          _invalidationController.add(e.reason);
        }
        return true;
      default:
        return false;
    }
  }

  /// Starts realtime audio, reusing the current session when already active.
  Future<AudioProcessingConfigDto> start({
    bool bypassRenderRequestHold = false,
  }) async {
    if (!_engine.isRunning) {
      throw StateError('Engine must be running to start audio.');
    }

    if (_config != null) {
      return _config!;
    }

    return _start(
      startupBehavior: StartupSendBehavior.requireRunning,
      bypassRenderRequestHold: bypassRenderRequestHold,
    );
  }

  Future<AudioProcessingConfigDto> _start({
    required StartupSendBehavior startupBehavior,
    bool bypassRenderRequestHold = false,
  }) async {
    final audioStartReply = await _engine._request(
      StartAudioRequest(id: _engine._getRequestId()),
      startupBehavior: startupBehavior,
      bypassRenderRequestHold: bypassRenderRequestHold,
      // Audio device initialization can block behind OS permission
      // prompts, such as the first-run microphone access prompt on
      // macOS.
      timeout: null,
    ) as StartAudioResponse;
    if (!audioStartReply.success) {
      throw StateError(
        'Engine audio startup failed: ${audioStartReply.error ?? 'Unknown error.'}',
      );
    }
    if (audioStartReply.audioConfig == null) {
      throw StateError(
        'Engine audio startup failed: audio config was not provided.',
      );
    }

    return audioStartReply.audioConfig!;
  }

  /// Starts an offline audio session with the requested configuration.
  Future<AudioProcessingConfigDto> startForRender({
    required double sampleRate,
    required int blockSize,
    required int outputChannelCount,
  }) async {
    final response = await _engine._request(
      StartRenderAudioSessionRequest(
        id: _engine._getRequestId(),
        sampleRate: sampleRate,
        blockSize: blockSize,
        outputChannelCount: outputChannelCount,
      ),
      startupBehavior: StartupSendBehavior.requireRunning,
      bypassRenderRequestHold: true,
    ) as StartRenderAudioSessionResponse;

    if (!response.success) {
      throw StateError(
        'Engine render audio session startup failed: ${response.error ?? 'Unknown error.'}',
      );
    }

    if (response.audioConfig == null) {
      throw StateError(
        'Engine render audio session startup failed: audio config was not provided.',
      );
    }

    return response.audioConfig!;
  }

  /// Stops the audio session without stopping the engine process.
  Future<void> stop({bool bypassRenderRequestHold = false}) async {
    if (!_engine.isRunning) {
      return;
    }

    final stopAudioReply = await _engine._request(
      StopAudioRequest(id: _engine._getRequestId()),
      bypassRenderRequestHold: bypassRenderRequestHold,
    ) as StopAudioResponse;

    if (!stopAudioReply.success) {
      throw StateError(
        'Engine audio shutdown failed: ${stopAudioReply.error ?? 'Unknown error.'}',
      );
    }
  }

  void _dispose() {
    _config = null;
    _invalidationController.close();
  }
}
