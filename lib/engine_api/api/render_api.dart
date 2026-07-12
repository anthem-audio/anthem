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
              bypassRenderRequestHold: true,
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

    return response.audioConfig!;
  }

  Future<RenderAudioStartResult> renderAudio({
    required int renderId,
    required String outputPath,
    required RenderAudioFormat format,
    required int startTick,
    required int endTick,
    required bool includeTail,
    required int bitDepth,
    required int qualityOptionIndex,
    required RenderAudioSampleFormat sampleFormat,
  }) async {
    final response =
        await _engine._request(
              RenderAudioRequest(
                id: _engine._getRequestId(),
                renderId: renderId,
                outputPath: outputPath,
                format: format,
                startTick: startTick,
                endTick: endTick,
                includeTail: includeTail,
                bitDepth: bitDepth,
                qualityOptionIndex: qualityOptionIndex,
                sampleFormat: sampleFormat,
              ),
              startupBehavior: StartupSendBehavior.requireRunning,
              bypassRenderRequestHold: true,
            )
            as RenderAudioResponse;

    if (!response.success) {
      throw StateError(
        'Engine render failed: ${response.error ?? 'Unknown error.'}',
      );
    }

    return RenderAudioStartResult(renderId: response.renderId);
  }
}
