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
import 'package:anthem/engine_api/messages/messages.dart';
import 'package:anthem/helpers/id.dart';
import 'package:anthem/logic/project_controller.dart';
import 'package:anthem/logic/render/render_range.dart';
import 'package:anthem/model/project.dart';
import 'package:logging/logging.dart';

final _log = Logger('project_render_controller');

const _defaultRenderBlockSize = 512;
const _defaultRenderOutputChannelCount = 2;

class ProjectRenderRequest {
  final String outputPath;
  final RenderAudioFormat format;
  final RenderTickRange range;
  final bool includeTail;
  final int sampleRate;
  final int bitDepth;
  final int qualityOptionIndex;
  final RenderAudioSampleFormat sampleFormat;

  const ProjectRenderRequest({
    required this.outputPath,
    required this.format,
    required this.range,
    required this.includeTail,
    required this.sampleRate,
    required this.bitDepth,
    required this.qualityOptionIndex,
    required this.sampleFormat,
  });
}

class ProjectRenderResult {
  final int renderedSamples;

  const ProjectRenderResult({required this.renderedSamples});
}

class ProjectRenderProgress {
  final double progress;
  final String statusText;

  const ProjectRenderProgress({
    required this.progress,
    required this.statusText,
  });
}

class ProjectRenderTask {
  final int renderId;
  final Stream<ProjectRenderProgress> progressStream;
  final Future<ProjectRenderResult> result;

  const ProjectRenderTask({
    required this.renderId,
    required this.progressStream,
    required this.result,
  });
}

class ProjectRenderController {
  final ProjectModel project;
  final ProjectController projectController;

  Future<ProjectRenderResult>? _activeRenderFuture;

  ProjectRenderController(this.project, this.projectController);

  ProjectRenderTask startRender(ProjectRenderRequest request) {
    if (_activeRenderFuture != null) {
      throw StateError('A render is already active.');
    }

    final renderId = getId();
    final progressController =
        StreamController<ProjectRenderProgress>.broadcast();

    late final Future<ProjectRenderResult> resultFuture;
    resultFuture =
        _runRender(
          renderId: renderId,
          request: request,
          progressController: progressController,
        ).whenComplete(() async {
          if (identical(_activeRenderFuture, resultFuture)) {
            _activeRenderFuture = null;
          }

          await progressController.close();
        });

    _activeRenderFuture = resultFuture;

    return ProjectRenderTask(
      renderId: renderId,
      progressStream: progressController.stream,
      result: resultFuture,
    );
  }

  Future<ProjectRenderResult> _runRender({
    required int renderId,
    required ProjectRenderRequest request,
    required StreamController<ProjectRenderProgress> progressController,
  }) async {
    if (project.engine.engineState != EngineState.running) {
      throw StateError('Engine must be running to render audio.');
    }

    final shouldRestoreRealtimeAudio = project.engine.isAudioReady;
    final realtimeAudioConfig = project.engine.audioConfig;
    final blockSize = realtimeAudioConfig?.blockSize ?? _defaultRenderBlockSize;
    final outputChannelCount =
        realtimeAudioConfig?.outputChannelCount ??
        _defaultRenderOutputChannelCount;
    project.engine.holdRequestsForRender();

    StreamSubscription<Response>? renderEventSubscription;
    final renderCompletion = Completer<Response>();

    void emitProgress(ProjectRenderProgress progress) {
      if (!progressController.isClosed) {
        progressController.add(progress);
      }
    }

    emitProgress(
      const ProjectRenderProgress(
        progress: 0,
        statusText: 'Preparing render...',
      ),
    );

    try {
      renderEventSubscription = project.engine.renderEventStream.listen((
        event,
      ) {
        _handleRenderEvent(
          event: event,
          renderId: renderId,
          renderCompletion: renderCompletion,
          emitProgress: emitProgress,
        );
      });

      await project.engine.stopAudioForRender();
      await project.engine.renderApi.startRenderAudioSession(
        sampleRate: request.sampleRate.toDouble(),
        blockSize: blockSize,
        outputChannelCount: outputChannelCount,
      );
      await projectController.publishProcessingGraphForRender();

      final startResult = await project.engine.renderApi.renderAudio(
        renderId: renderId,
        outputPath: request.outputPath,
        format: request.format,
        startTick: request.range.startTick,
        endTick: request.range.endTick,
        includeTail: request.includeTail,
        bitDepth: request.bitDepth,
        qualityOptionIndex: request.qualityOptionIndex,
        sampleFormat: request.sampleFormat,
      );

      if (startResult.renderId != renderId) {
        throw StateError(
          'Engine accepted render with unexpected render ID ${startResult.renderId}.',
        );
      }

      final completionEvent = await renderCompletion.future;
      switch (completionEvent) {
        case RenderCompletedEvent e:
          return ProjectRenderResult(renderedSamples: e.renderedSamples);
        case RenderFailedEvent e:
          throw StateError('Engine render failed: ${e.error}');
        default:
          throw StateError(
            'Engine render completed with unexpected event ${completionEvent.runtimeType}.',
          );
      }
    } finally {
      await renderEventSubscription?.cancel();

      try {
        await project.engine.stopAudioForRender();
      } catch (error, stackTrace) {
        _log.warning(
          'Could not stop render audio session for project ${project.id}.',
          error,
          stackTrace,
        );
      }

      if (shouldRestoreRealtimeAudio) {
        try {
          await project.engine.startAudioForRender();
          await projectController.publishProcessingGraphForRender();
        } catch (error, stackTrace) {
          _log.warning(
            'Could not restore realtime audio for project ${project.id} after render.',
            error,
            stackTrace,
          );
        }
      }

      project.engine.releaseRequestsHeldForRender();
    }
  }

  void _handleRenderEvent({
    required Response event,
    required int renderId,
    required Completer<Response> renderCompletion,
    required void Function(ProjectRenderProgress progress) emitProgress,
  }) {
    switch (event) {
      case RenderStartedEvent e when e.renderId == renderId:
        emitProgress(
          ProjectRenderProgress(
            progress: 0,
            statusText: e.totalSamples > 0
                ? 'Rendering 0 of ${e.totalSamples} samples...'
                : 'Rendering...',
          ),
        );
      case RenderProgressEvent e when e.renderId == renderId:
        emitProgress(
          ProjectRenderProgress(
            progress: _sanitizeProgress(e.progress),
            statusText:
                'Rendering ${e.renderedSamples} of ${e.totalSamples} samples...',
          ),
        );
      case RenderCompletedEvent e when e.renderId == renderId:
        emitProgress(
          ProjectRenderProgress(
            progress: 1,
            statusText: 'Rendered ${e.renderedSamples} samples.',
          ),
        );
        if (!renderCompletion.isCompleted) {
          renderCompletion.complete(e);
        }
      case RenderFailedEvent e when e.renderId == renderId:
        emitProgress(
          ProjectRenderProgress(
            progress: _sanitizeProgress(
              e.totalSamples == 0 ? 0 : e.renderedSamples / e.totalSamples,
            ),
            statusText: 'Render failed: ${e.error}',
          ),
        );
        if (!renderCompletion.isCompleted) {
          renderCompletion.complete(e);
        }
      default:
        break;
    }
  }
}

double _sanitizeProgress(double progress) {
  if (!progress.isFinite) {
    return 0;
  }

  return progress.clamp(0.0, 1.0).toDouble();
}
