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

class RenderAudioResult {
  final int renderedSamples;

  RenderAudioResult({required this.renderedSamples});
}

class RenderAudioStartResult {
  final int renderId;

  RenderAudioStartResult({required this.renderId});
}

class RenderApi {
  final Engine _engine;

  RenderApi(this._engine);

  Future<AudioProcessingConfigDto> startRenderAudioSession({
    required double sampleRate,
    required int blockSize,
    required int outputChannelCount,
  }) async {
    final response =
        await _engine._request(
              StartRenderAudioSessionRequest(
                id: _engine._getRequestId(),
                sampleRate: sampleRate,
                blockSize: blockSize,
                outputChannelCount: outputChannelCount,
              ),
              startupBehavior: StartupSendBehavior.requireRunning,
            )
            as StartRenderAudioSessionResponse;

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

    final audioConfig = response.audioConfig!;
    _engine._setAudioReady(audioConfig);
    return audioConfig;
  }

  Future<RenderAudioStartResult> renderAudio({
    required int renderId,
    required String outputPath,
    required RenderAudioFormat format,
    required int startTick,
    required int endTick,
    required bool includeTail,
  }) async {
    final didOpenRenderQueue = !_engine._isRenderingAudio;
    if (didOpenRenderQueue) {
      _engine._beginRenderingAudio(renderId);
    }

    RenderAudioResponse response;
    try {
      response =
          await _engine._request(
                RenderAudioRequest(
                  id: _engine._getRequestId(),
                  renderId: renderId,
                  outputPath: outputPath,
                  format: format,
                  startTick: startTick,
                  endTick: endTick,
                  includeTail: includeTail,
                ),
                startupBehavior: StartupSendBehavior.requireRunning,
                renderBehavior: _RenderSendBehavior.bypassRenderQueue,
              )
              as RenderAudioResponse;
    } catch (_) {
      if (didOpenRenderQueue) {
        _engine._finishRenderingAudio(renderId: renderId);
      }
      rethrow;
    }

    if (!response.success) {
      if (didOpenRenderQueue) {
        _engine._finishRenderingAudio(renderId: renderId);
      }
      throw StateError(
        'Engine render failed: ${response.error ?? 'Unknown error.'}',
      );
    }

    return RenderAudioStartResult(renderId: response.renderId);
  }
}
