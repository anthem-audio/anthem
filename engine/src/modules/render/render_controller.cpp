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

#include "render_controller.h"

#include "messages/messages.h"
#include "modules/audio/audio_block_processor.h"
#include "modules/audio/audio_session_controller.h"
#include "modules/core/comms.h"
#include "modules/core/engine.h"
#include "modules/processors/master_output.h"
#include "modules/render/render_tail_detector.h"
#include "modules/sequencer/runtime/sequencer_timing.h"
#include "modules/sequencer/runtime/transport.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <rfl/json.hpp>
#include <utility>

#ifndef __EMSCRIPTEN__
#include <juce_audio_formats/juce_audio_formats.h>
#endif

namespace anthem {

struct RenderController::RenderJob {
  int64_t renderId = 0;
  std::string outputPath;
  RenderAudioFormat format = RenderAudioFormat::wav;
  int64_t activeSequenceId = 0;
  int64_t startTick = 0;
  int64_t endTick = 0;
  bool includeTail = false;
  int64_t sourceSamples = 0;
  int64_t totalSamples = 0;
  int blockSize = 0;
  double sampleRate = 0.0;
  int outputChannelCount = 0;
  uint64_t audioProcessingConfigGeneration = 0;
  std::shared_ptr<MasterOutputProcessor> masterOutputProcessor;
};

namespace {
RenderStartResult renderStartFailure(const std::string& error) {
  return RenderStartResult{
      .success = false,
      .error = error,
  };
}

std::optional<int64_t> getActiveArrangementId() {
  auto& engine = Engine::getInstance();

  if (engine.project == nullptr || engine.project->sequence() == nullptr) {
    return std::nullopt;
  }

  return engine.project->sequence()->activeArrangementID();
}

std::shared_ptr<MasterOutputProcessor> getMasterOutputProcessor() {
  auto& engine = Engine::getInstance();

  if (engine.project == nullptr || engine.project->processingGraph() == nullptr) {
    return nullptr;
  }

  auto& processingGraph = engine.project->processingGraph();
  auto masterOutputNodeId = processingGraph->masterOutputNodeId();

  auto& nodes = *processingGraph->nodes();
  auto masterOutputNodeIter = nodes.find(masterOutputNodeId);
  if (masterOutputNodeIter == nodes.end()) {
    return nullptr;
  }

  auto masterOutputProcessorOpt = masterOutputNodeIter->second->getProcessor();
  if (!masterOutputProcessorOpt.has_value()) {
    return nullptr;
  }

  return std::dynamic_pointer_cast<MasterOutputProcessor>(masterOutputProcessorOpt.value());
}

int64_t getRenderSampleCount(
    int64_t startTick, int64_t endTick, const Transport& transport, double sampleRate) {
  const auto tickDelta = static_cast<double>(endTick - startTick);
  const auto timingParams = sequencer_timing::TimingParams{
      .ticksPerQuarter = transport.config.ticksPerQuarter,
      .beatsPerMinute = transport.config.beatsPerMinute,
      .sampleRate = sampleRate,
  };

  const auto sampleOffset = sequencer_timing::tickDeltaToSampleOffset(tickDelta, timingParams);
  if (sampleOffset <= 0.0) {
    return 0;
  }

  return static_cast<int64_t>(std::ceil(sampleOffset));
}

#ifndef __EMSCRIPTEN__
std::unique_ptr<juce::AudioFormatWriter> createRenderWriter(RenderAudioFormat format,
    const std::string& outputPath,
    double sampleRate,
    int outputChannelCount) {
  auto outputFile = juce::File(outputPath);
  if (outputFile.existsAsFile() && !outputFile.deleteFile()) {
    return nullptr;
  }

  auto parentDirectory = outputFile.getParentDirectory();
  if (!parentDirectory.exists() && !parentDirectory.createDirectory()) {
    return nullptr;
  }

  std::unique_ptr<juce::OutputStream> outputStream = outputFile.createOutputStream();
  if (outputStream == nullptr) {
    return nullptr;
  }

  auto options = juce::AudioFormatWriter::Options{}
                     .withSampleRate(sampleRate)
                     .withNumChannels(outputChannelCount);

  switch (format) {
    case RenderAudioFormat::wav: {
      auto wavFormat = juce::WavAudioFormat();
      return wavFormat.createWriterFor(outputStream,
          options.withBitsPerSample(32).withSampleFormat(
              juce::AudioFormatWriter::Options::SampleFormat::floatingPoint));
    }

    case RenderAudioFormat::aiff: {
      auto aiffFormat = juce::AiffAudioFormat();
      return aiffFormat.createWriterFor(outputStream, options.withBitsPerSample(24));
    }

    case RenderAudioFormat::flac: {
      auto flacFormat = juce::FlacAudioFormat();
      return flacFormat.createWriterFor(
          outputStream, options.withBitsPerSample(24).withQualityOptionIndex(5));
    }

    case RenderAudioFormat::oggVorbis: {
      auto oggFormat = juce::OggVorbisAudioFormat();
      return oggFormat.createWriterFor(
          outputStream, options.withBitsPerSample(32).withQualityOptionIndex(9));
    }
  }

  return nullptr;
}
#endif
} // namespace

class RenderController::RenderThread : public juce::Thread {
private:
  RenderController& renderController;
  RenderJob renderJob;
public:
  RenderThread(RenderController& renderController, RenderJob renderJob)
    : juce::Thread("Anthem Render Thread"), renderController(renderController),
      renderJob(std::move(renderJob)) {}

  void run() override {
    renderController.runRender(renderJob, *this);
  }
};

RenderController::RenderController(AudioSessionController& audioSessionController,
    AudioBlockProcessor& audioBlockProcessor,
    Transport& transport,
    Comms& comms)
  : audioSessionController(audioSessionController), audioBlockProcessor(audioBlockProcessor),
    transport(transport), comms(comms) {}

RenderController::~RenderController() {
  stopRenderThread();
}

void RenderController::sendRenderStartedEvent(int64_t renderId, int64_t totalSamples) {
  Response response = RenderStartedEvent{
      .renderId = renderId, .totalSamples = totalSamples, .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderProgressEvent(
    int64_t renderId, int64_t renderedSamples, int64_t totalSamples) {
  auto progress = 0.0;
  if (totalSamples > 0) {
    progress = std::clamp(
        static_cast<double>(renderedSamples) / static_cast<double>(totalSamples), 0.0, 1.0);
  }

  Response response = RenderProgressEvent{.renderId = renderId,
      .progress = progress,
      .renderedSamples = renderedSamples,
      .totalSamples = totalSamples,
      .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderCompletedEvent(
    int64_t renderId, int64_t renderedSamples, int64_t totalSamples) {
  Response response = RenderCompletedEvent{.renderId = renderId,
      .renderedSamples = renderedSamples,
      .totalSamples = totalSamples,
      .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderFailedEvent(
    int64_t renderId, const std::string& error, int64_t renderedSamples, int64_t totalSamples) {
  Response response = RenderFailedEvent{.renderId = renderId,
      .error = error,
      .renderedSamples = renderedSamples,
      .totalSamples = totalSamples,
      .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

RenderStartResult RenderController::startRender(int64_t renderId,
    const std::string& outputPath,
    RenderAudioFormat format,
    int64_t startTick,
    int64_t endTick,
    bool includeTail) {
  if (isRenderingFlag.exchange(true, std::memory_order_acq_rel)) {
    return renderStartFailure("Render is already running.");
  }

  if (!audioSessionController.isRenderAudioSessionRunning()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Render audio session is not active.");
  }

  if (outputPath.empty()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Render output path must not be empty.");
  }

#ifdef __EMSCRIPTEN__
  isRenderingFlag.store(false, std::memory_order_release);
  return renderStartFailure("File render is not available on web yet.");
#endif

  if (startTick < 0 || endTick <= startTick) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure(
        "Render tick range must have a non-negative start and positive length.");
  }

  auto audioProcessingConfig = audioSessionController.getCurrentAudioProcessingConfigSnapshot();
  if (!audioProcessingConfig.has_value()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("No audio processing config is active.");
  }

  const auto activeArrangementId = getActiveArrangementId();
  if (!activeArrangementId.has_value()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("No active arrangement is selected for render.");
  }

  auto masterOutputProcessor = getMasterOutputProcessor();
  if (masterOutputProcessor == nullptr) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Master output processor is not available for render.");
  }

  const auto sourceSamples =
      getRenderSampleCount(startTick, endTick, transport, audioProcessingConfig->config.sampleRate);
  if (sourceSamples <= 0) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Render sample count must be greater than zero.");
  }

  const auto maximumTailSamples =
      includeTail ? RenderTailDetector::secondsToSamples(RenderTailDetector::maximumTailSeconds,
                        audioProcessingConfig->config.sampleRate)
                  : 0;
  const auto totalSamples = sourceSamples + maximumTailSamples;

  auto renderJob = RenderJob{.renderId = renderId,
      .outputPath = outputPath,
      .format = format,
      .activeSequenceId = activeArrangementId.value(),
      .startTick = startTick,
      .endTick = endTick,
      .includeTail = includeTail,
      .sourceSamples = sourceSamples,
      .totalSamples = totalSamples,
      .blockSize = audioProcessingConfig->config.blockSize,
      .sampleRate = audioProcessingConfig->config.sampleRate,
      .outputChannelCount = audioProcessingConfig->config.outputChannelCount,
      .audioProcessingConfigGeneration = audioProcessingConfig->generation,
      .masterOutputProcessor = std::move(masterOutputProcessor)};

  {
    juce::ScopedLock lock(renderThreadMutex);

    if (renderThread != nullptr) {
      if (renderThread->isThreadRunning()) {
        isRenderingFlag.store(false, std::memory_order_release);
        return renderStartFailure("Render thread is already running.");
      }

      renderThread.reset();
    }

    renderThread = std::make_unique<RenderThread>(*this, renderJob);

    if (!renderThread->startThread()) {
      renderThread.reset();
      isRenderingFlag.store(false, std::memory_order_release);
      return renderStartFailure("Failed to start render thread.");
    }
  }

  return RenderStartResult{
      .success = true,
      .error = std::nullopt,
  };
}

void RenderController::stopRenderThread() {
  std::unique_ptr<RenderThread> threadToStop;

  {
    juce::ScopedLock lock(renderThreadMutex);
    threadToStop = std::move(renderThread);
  }

  if (threadToStop == nullptr) {
    isRenderingFlag.store(false, std::memory_order_release);
    return;
  }

  threadToStop->signalThreadShouldExit();

  if (!threadToStop->waitForThreadToExit(-1)) {
    jassertfalse;
  }

  isRenderingFlag.store(false, std::memory_order_release);
}

void RenderController::finishRenderThreadState() {
  transport.setIsPlaying(false);
  transport.endRenderPlayback();
}

void RenderController::runRender(const RenderJob& renderJob, RenderThread& thread) {
#ifdef __EMSCRIPTEN__
  sendRenderFailedEvent(
      renderJob.renderId, "File render is not available on web yet.", 0, renderJob.totalSamples);
  isRenderingFlag.store(false, std::memory_order_release);
  return;
#else
  auto writer = createRenderWriter(
      renderJob.format, renderJob.outputPath, renderJob.sampleRate, renderJob.outputChannelCount);
  if (writer == nullptr) {
    sendRenderFailedEvent(
        renderJob.renderId, "Failed to create render output file.", 0, renderJob.totalSamples);
    isRenderingFlag.store(false, std::memory_order_release);
    return;
  }

  transport.beginRenderPlayback(
      renderJob.activeSequenceId, static_cast<double>(renderJob.startTick));
  sendRenderStartedEvent(renderJob.renderId, renderJob.totalSamples);

  auto tailDetector = RenderTailDetector(RenderTailDetector::secondsToSamples(
      RenderTailDetector::defaultRequiredSilenceSeconds, renderJob.sampleRate));
  auto hasStoppedPlaybackForTail = false;

  int64_t renderedSamples = 0;
  int64_t lastProgressPercent = -1;
  auto lastProgressUpdateTime = std::chrono::steady_clock::now();

  while (renderedSamples < renderJob.totalSamples) {
    if (renderJob.includeTail && !hasStoppedPlaybackForTail &&
        renderedSamples >= renderJob.sourceSamples) {
      transport.stopRenderPlaybackForTail(static_cast<double>(renderJob.endTick));
      hasStoppedPlaybackForTail = true;
    }

    if (thread.threadShouldExit()) {
      finishRenderThreadState();
      sendRenderFailedEvent(
          renderJob.renderId, "Render was stopped.", renderedSamples, renderJob.totalSamples);
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    const auto blockEndSample = renderJob.includeTail && !hasStoppedPlaybackForTail
                                    ? renderJob.sourceSamples
                                    : renderJob.totalSamples;
    const auto remainingSamples = blockEndSample - renderedSamples;
    const auto samplesThisBlock =
        static_cast<int>(std::min<int64_t>(renderJob.blockSize, remainingSamples));

    const auto didProcessGraph = audioBlockProcessor.processAudioBlock(
        samplesThisBlock, renderJob.sampleRate, renderJob.audioProcessingConfigGeneration);
    if (!didProcessGraph) {
      finishRenderThreadState();
      sendRenderFailedEvent(renderJob.renderId,
          "No processing graph is active for render.",
          renderedSamples,
          renderJob.totalSamples);
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    auto& outputBuffer = renderJob.masterOutputProcessor->buffer;
    jassert(outputBuffer.getNumChannels() >= renderJob.outputChannelCount);
    jassert(outputBuffer.getNumSamples() >= samplesThisBlock);

    if (!writer->writeFromAudioSampleBuffer(outputBuffer, 0, samplesThisBlock)) {
      finishRenderThreadState();
      sendRenderFailedEvent(renderJob.renderId,
          "Failed to write render output file.",
          renderedSamples,
          renderJob.totalSamples);
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    renderedSamples += samplesThisBlock;

    const auto tailIsComplete =
        hasStoppedPlaybackForTail &&
        tailDetector.processBlock(outputBuffer, renderJob.outputChannelCount, samplesThisBlock);

    const auto progressPercent = (renderedSamples * 100) / renderJob.totalSamples;
    const auto now = std::chrono::steady_clock::now();
    const auto millisecondsSinceLastUpdate =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - lastProgressUpdateTime).count();

    if (progressPercent != lastProgressPercent || millisecondsSinceLastUpdate >= 50 ||
        renderedSamples == renderJob.totalSamples) {
      sendRenderProgressEvent(renderJob.renderId, renderedSamples, renderJob.totalSamples);
      lastProgressPercent = progressPercent;
      lastProgressUpdateTime = now;
    }

    if (tailIsComplete) {
      break;
    }
  }

  finishRenderThreadState();
  writer.reset();
  sendRenderCompletedEvent(renderJob.renderId, renderedSamples, renderJob.totalSamples);
  isRenderingFlag.store(false, std::memory_order_release);
#endif
}

} // namespace anthem
