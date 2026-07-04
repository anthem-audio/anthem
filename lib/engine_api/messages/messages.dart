/*
  Copyright (C) 2023 - 2026 Joshua Wade

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

// ignore_for_file: non_constant_identifier_names

import 'package:anthem/helpers/id.dart';
import 'package:anthem_codegen/include.dart';

part 'model_sync.dart';
part 'processing_graph.dart';
part 'sequencer.dart';
part 'visualization.dart';

part 'messages.g.dart';

@AnthemModel(serializable: true, generateCpp: true)
class AudioProcessingConfigDto extends _AudioProcessingConfigDto
    with _$AudioProcessingConfigDtoAnthemModelMixin {
  AudioProcessingConfigDto.uninitialized()
    : super(
        sampleRate: 0.0,
        blockSize: 0,
        inputChannelCount: 0,
        outputChannelCount: 0,
      );

  AudioProcessingConfigDto({
    required super.sampleRate,
    required super.blockSize,
    required super.inputChannelCount,
    required super.outputChannelCount,
  });

  factory AudioProcessingConfigDto.fromJson(Map<String, dynamic> json) =>
      _$AudioProcessingConfigDtoAnthemModelMixin.fromJson(json);
}

abstract class _AudioProcessingConfigDto {
  double sampleRate;
  int blockSize;
  int inputChannelCount;
  int outputChannelCount;

  _AudioProcessingConfigDto({
    required this.sampleRate,
    required this.blockSize,
    required this.inputChannelCount,
    required this.outputChannelCount,
  });
}

@AnthemEnum()
enum RenderAudioFormat { wav, aiff, flac, oggVorbis }

@AnthemEnum()
enum RenderAudioSampleFormat { integer, floatingPoint }

class Exit extends Request {
  Exit.uninitialized();

  Exit({required int id}) {
    super.id = id;
  }
}

class ExitReply extends Response {
  ExitReply.uninitialized();

  ExitReply({required int id}) {
    super.id = id;
  }
}

class Heartbeat extends Request {
  Heartbeat.uninitialized();

  Heartbeat({required int id}) {
    super.id = id;
  }
}

class HeartbeatReply extends Response {
  HeartbeatReply.uninitialized();

  HeartbeatReply({required int id}) {
    super.id = id;
  }
}

class EngineReadyCheckRequest extends Request {
  EngineReadyCheckRequest.uninitialized();

  EngineReadyCheckRequest({required int id}) {
    super.id = id;
  }
}

class StartAudioRequest extends Request {
  StartAudioRequest.uninitialized();

  StartAudioRequest({required int id}) {
    super.id = id;
  }
}

class StartRenderAudioSessionRequest extends Request {
  late double sampleRate;
  late int blockSize;
  late int outputChannelCount;

  StartRenderAudioSessionRequest.uninitialized();

  StartRenderAudioSessionRequest({
    required int id,
    required this.sampleRate,
    required this.blockSize,
    required this.outputChannelCount,
  }) {
    super.id = id;
  }
}

class StopAudioRequest extends Request {
  StopAudioRequest.uninitialized();

  StopAudioRequest({required int id}) {
    super.id = id;
  }
}

class EngineReadyCheckResponse extends Response {
  bool success = false;
  String? error;

  EngineReadyCheckResponse.uninitialized();

  EngineReadyCheckResponse({
    required int id,
    required this.success,
    this.error,
  }) {
    super.id = id;
  }
}

class StartAudioResponse extends Response {
  bool success = false;
  String? error;
  AudioProcessingConfigDto? audioConfig;

  StartAudioResponse.uninitialized();

  StartAudioResponse({
    required int id,
    required this.success,
    this.error,
    this.audioConfig,
  }) {
    super.id = id;
  }
}

class StartRenderAudioSessionResponse extends Response {
  bool success = false;
  String? error;
  AudioProcessingConfigDto? audioConfig;

  StartRenderAudioSessionResponse.uninitialized();

  StartRenderAudioSessionResponse({
    required int id,
    required this.success,
    this.error,
    this.audioConfig,
  }) {
    super.id = id;
  }
}

class StopAudioResponse extends Response {
  bool success = false;
  String? error;

  StopAudioResponse.uninitialized();

  StopAudioResponse({required int id, required this.success, this.error}) {
    super.id = id;
  }
}

class RenderAudioRequest extends Request {
  late int renderId;
  late String outputPath;
  late RenderAudioFormat format;
  late int startTick;
  late int endTick;
  late bool includeTail;
  late int bitDepth;
  late int qualityOptionIndex;
  late RenderAudioSampleFormat sampleFormat;

  RenderAudioRequest.uninitialized();

  RenderAudioRequest({
    required int id,
    required this.renderId,
    required this.outputPath,
    required this.format,
    required this.startTick,
    required this.endTick,
    required this.includeTail,
    required this.bitDepth,
    required this.qualityOptionIndex,
    required this.sampleFormat,
  }) {
    super.id = id;
  }
}

class RenderAudioResponse extends Response {
  bool success = false;
  String? error;
  late int renderId;

  RenderAudioResponse.uninitialized();

  RenderAudioResponse({
    required int id,
    required this.success,
    this.error,
    required this.renderId,
  }) {
    super.id = id;
  }
}

class RenderStartedEvent extends Response {
  late int renderId;
  late int totalSamples;

  RenderStartedEvent.uninitialized();

  RenderStartedEvent({
    required int id,
    required this.renderId,
    required this.totalSamples,
  }) {
    super.id = id;
  }
}

class RenderProgressEvent extends Response {
  late int renderId;
  late double progress;
  late int renderedSamples;
  late int totalSamples;

  RenderProgressEvent.uninitialized();

  RenderProgressEvent({
    required int id,
    required this.renderId,
    required this.progress,
    required this.renderedSamples,
    required this.totalSamples,
  }) {
    super.id = id;
  }
}

class RenderCompletedEvent extends Response {
  late int renderId;
  late int renderedSamples;
  late int totalSamples;

  RenderCompletedEvent.uninitialized();

  RenderCompletedEvent({
    required int id,
    required this.renderId,
    required this.renderedSamples,
    required this.totalSamples,
  }) {
    super.id = id;
  }
}

class RenderFailedEvent extends Response {
  late int renderId;
  late String error;
  late int renderedSamples;
  late int totalSamples;

  RenderFailedEvent.uninitialized();

  RenderFailedEvent({
    required int id,
    required this.renderId,
    required this.error,
    required this.renderedSamples,
    required this.totalSamples,
  }) {
    super.id = id;
  }
}

class TestSampleGainCurveRequest extends Request {
  late List<double> parameterValues;

  TestSampleGainCurveRequest.uninitialized();

  TestSampleGainCurveRequest({required int id, required this.parameterValues}) {
    super.id = id;
  }
}

class TestSampleGainCurveResponse extends Response {
  late List<double> dbValues;
  late List<bool> isNegativeInfinity;

  TestSampleGainCurveResponse.uninitialized();

  TestSampleGainCurveResponse({
    required int id,
    required this.dbValues,
    required this.isNegativeInfinity,
  }) {
    super.id = id;
  }
}

/// Unsolicited response that is sent back one time, when the audio device has
/// initialized.
class AudioReadyEvent extends Response {
  late AudioProcessingConfigDto audioConfig;

  AudioReadyEvent.uninitialized();

  AudioReadyEvent({required int id, required this.audioConfig}) {
    super.id = id;
  }
}

/// Unsolicited response sent when the engine detects that the current audio
/// session can no longer be used.
class AudioSessionInvalidatedEvent extends Response {
  String? reason;

  AudioSessionInvalidatedEvent.uninitialized();

  AudioSessionInvalidatedEvent({required int id, this.reason}) {
    super.id = id;
  }
}

@AnthemModel.ipc()
sealed class Request extends _Request with _$RequestAnthemModelMixin {
  Request();

  factory Request.fromJson(Map<String, dynamic> json) =>
      _$RequestAnthemModelMixin.fromJson(json);
}

class _Request {
  late int id;
}

@AnthemModel.ipc()
sealed class Response extends _Response with _$ResponseAnthemModelMixin {
  Response();

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseAnthemModelMixin.fromJson(json);
}

class _Response {
  late int id;
}
