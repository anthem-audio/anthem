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
part 'test_messages.dart';

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
enum RenderAudioFormat { wav, aiff, flac, oggVorbis, mp3 }

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

class RenderStartedEvent extends IpcEvent {
  late int renderId;

  RenderStartedEvent.uninitialized();

  RenderStartedEvent({required this.renderId});
}

class RenderProgressEvent extends IpcEvent {
  late int renderId;
  late double progress;

  RenderProgressEvent.uninitialized();

  RenderProgressEvent({required this.renderId, required this.progress});
}

class RenderCompletedEvent extends IpcEvent {
  late int renderId;

  RenderCompletedEvent.uninitialized();

  RenderCompletedEvent({required this.renderId});
}

class RenderFailedEvent extends IpcEvent {
  late int renderId;
  late String error;

  RenderFailedEvent.uninitialized();

  RenderFailedEvent({required this.renderId, required this.error});
}

class TestSampleGainCurveRequest extends Request {
  late List<double> parameterValues;

  TestSampleGainCurveRequest.uninitialized();

  TestSampleGainCurveRequest({required int id, required this.parameterValues}) {
    super.id = id;
  }
}

/// Publishes the fixed visualization wire fixture through the engine's ring.
/// Used by integration tests without requiring an audio device or project.
class TestPublishVisualizationRecordRequest extends Request {
  TestPublishVisualizationRecordRequest.uninitialized();

  TestPublishVisualizationRecordRequest({required int id}) {
    super.id = id;
  }
}

class TestPublishVisualizationRecordResponse extends Response {
  late bool success;

  TestPublishVisualizationRecordResponse.uninitialized();

  TestPublishVisualizationRecordResponse({
    required int id,
    required this.success,
  }) {
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

/// Sent once when the audio device has initialized.
class AudioReadyEvent extends IpcEvent {
  late AudioProcessingConfigDto audioConfig;

  AudioReadyEvent.uninitialized();

  AudioReadyEvent({required this.audioConfig});
}

/// Sent when the engine detects that the current audio
/// session can no longer be used.
class AudioSessionInvalidatedEvent extends IpcEvent {
  String? reason;

  AudioSessionInvalidatedEvent.uninitialized();

  AudioSessionInvalidatedEvent({this.reason});
}

@AnthemEnum()
enum RequestErrorCode { unsupported, failed }

/// Reports a failure to handle a [Request].
class RequestErrorResponse extends Response {
  late RequestErrorCode code;
  late String message;

  RequestErrorResponse.uninitialized();

  RequestErrorResponse({
    required int id,
    required this.code,
    required this.message,
  }) {
    super.id = id;
  }
}

/// A message exchanged between the UI and engine.
///
/// Either side can send a [Request], [Response], or [IpcEvent]. The receiving
/// side dispatches requests to its handlers and matches responses to requests
/// it initiated. Events are delivered separately from request completion.
@AnthemModel.ipc()
sealed class IpcMessage extends _IpcMessage with _$IpcMessageAnthemModelMixin {
  IpcMessage();

  factory IpcMessage.fromJson(Map<String, dynamic> json) =>
      _$IpcMessageAnthemModelMixin.fromJson(json);
}

abstract class _IpcMessage {}

/// Requests an operation on the receiving side of the connection.
///
/// Each sender allocates its own [id]. A response uses the same ID as its
/// request. Requests that do not need a response can be sent without waiting.
@AnthemModel.ipc()
sealed class Request extends _Request with _$RequestAnthemModelMixin {
  Request();

  factory Request.fromJson(Map<String, dynamic> json) =>
      _$RequestAnthemModelMixin.fromJson(json);
}

abstract class _Request extends IpcMessage {
  late int id;
}

/// Replies to a request initiated by the receiving side.
///
/// The [id] must match the corresponding [Request.id].
@AnthemModel.ipc()
sealed class Response extends _Response with _$ResponseAnthemModelMixin {
  Response();

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseAnthemModelMixin.fromJson(json);
}

abstract class _Response extends IpcMessage {
  late int id;
}

/// Reports an event without completing a request.
///
/// Events have no request ID. Any identifiers they carry refer to the operation
/// or resource described by the event, such as a render session or graph node.
@AnthemModel.ipc()
sealed class IpcEvent extends _IpcEvent with _$IpcEventAnthemModelMixin {
  IpcEvent();

  factory IpcEvent.fromJson(Map<String, dynamic> json) =>
      _$IpcEventAnthemModelMixin.fromJson(json);
}

abstract class _IpcEvent extends IpcMessage {}
