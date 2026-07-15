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
#include "modules/core/visualization/visualization_broker.h"
#include "modules/processors/master_output.h"
#include "modules/render/render_tail_detector.h"
#include "modules/sequencer/runtime/transport.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <initializer_list>
#include <juce_events/juce_events.h>
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
  int bitDepth = 32;
  int qualityOptionIndex = 0;
  RenderAudioSampleFormat sampleFormat = RenderAudioSampleFormat::floatingPoint;
  int64_t maximumTailSamples = 0;
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

std::optional<int64_t> getArrangementId() {
  auto& engine = Engine::getInstance();

  if (engine.project == nullptr || engine.project->sequence() == nullptr) {
    return std::nullopt;
  }

  auto arrangement = engine.project->sequence()->arrangement();
  return arrangement == nullptr ? std::nullopt : std::make_optional(arrangement->id());
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

bool containsInt(std::initializer_list<int64_t> values, int64_t value) {
  return std::find(values.begin(), values.end(), value) != values.end();
}

std::optional<std::string> validateRenderExportOptions(
    RenderAudioFormat format, int64_t bitDepth, int64_t qualityOptionIndex) {
  switch (format) {
    case RenderAudioFormat::wav:
      if (!containsInt({8, 16, 24, 32}, bitDepth)) {
        return "WAV render bit depth must be 8, 16, 24, or 32.";
      }
      return std::nullopt;

    case RenderAudioFormat::aiff:
      if (!containsInt({8, 16, 24}, bitDepth)) {
        return "AIFF render bit depth must be 8, 16, or 24.";
      }
      return std::nullopt;

    case RenderAudioFormat::flac:
      if (!containsInt({16, 24}, bitDepth)) {
        return "FLAC render bit depth must be 16 or 24.";
      }
      if (qualityOptionIndex < 0 || qualityOptionIndex > 8) {
        return "FLAC render compression level must be between 0 and 8.";
      }
      return std::nullopt;

    case RenderAudioFormat::oggVorbis:
      if (bitDepth != 32) {
        return "Ogg Vorbis render bit depth must be 32.";
      }
      if (qualityOptionIndex < 0 || qualityOptionIndex > 10) {
        return "Ogg Vorbis render bitrate option must be between 0 and 10.";
      }
      return std::nullopt;

    case RenderAudioFormat::mp3:
      if (bitDepth != 16) {
        return "MP3 render bit depth must be 16.";
      }
      if (qualityOptionIndex < 10 || qualityOptionIndex > 23) {
        return "MP3 render bitrate option must be between 10 and 23.";
      }
      return std::nullopt;
  }

  return "Unsupported render audio format.";
}

#ifndef __EMSCRIPTEN__
juce::AudioFormatWriter::Options::SampleFormat toJuceWavSampleFormat(
    RenderAudioSampleFormat sampleFormat) {
  switch (sampleFormat) {
    case RenderAudioSampleFormat::integer:
      return juce::AudioFormatWriter::Options::SampleFormat::integral;

    case RenderAudioSampleFormat::floatingPoint:
      return juce::AudioFormatWriter::Options::SampleFormat::floatingPoint;
  }

  return juce::AudioFormatWriter::Options::SampleFormat::floatingPoint;
}

juce::File getBundledLameExecutable() {
  auto engineExecutable = juce::File::getSpecialLocation(juce::File::currentExecutableFile);

#if JUCE_WINDOWS
  return engineExecutable.getSiblingFile("lame.exe");
#else
  return engineExecutable.getSiblingFile("lame");
#endif
}

juce::File resolveLameExecutable() {
#ifndef NDEBUG
  if (const auto* lamePathOverride = std::getenv("ANTHEM_LAME_PATH");
      lamePathOverride != nullptr && lamePathOverride[0] != '\0') {
    return juce::File(lamePathOverride);
  }
#endif

  return getBundledLameExecutable();
}

std::unique_ptr<juce::AudioFormatWriter> createRenderWriter(RenderAudioFormat format,
    const std::string& outputPath,
    double sampleRate,
    int outputChannelCount,
    int bitDepth,
    int qualityOptionIndex,
    RenderAudioSampleFormat sampleFormat) {
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
      auto wavOptions = options.withBitsPerSample(bitDepth);

      if (bitDepth == 32) {
        wavOptions = wavOptions.withSampleFormat(toJuceWavSampleFormat(sampleFormat));
      }

      return wavFormat.createWriterFor(outputStream, wavOptions);
    }

    case RenderAudioFormat::aiff: {
      auto aiffFormat = juce::AiffAudioFormat();
      return aiffFormat.createWriterFor(outputStream, options.withBitsPerSample(bitDepth));
    }

    case RenderAudioFormat::flac: {
      auto flacFormat = juce::FlacAudioFormat();
      return flacFormat.createWriterFor(outputStream,
          options.withBitsPerSample(bitDepth).withQualityOptionIndex(qualityOptionIndex));
    }

    case RenderAudioFormat::oggVorbis: {
      auto oggFormat = juce::OggVorbisAudioFormat();
      return oggFormat.createWriterFor(outputStream,
          options.withBitsPerSample(bitDepth).withQualityOptionIndex(qualityOptionIndex));
    }

    case RenderAudioFormat::mp3: {
      auto mp3Format = juce::LAMEEncoderAudioFormat(resolveLameExecutable());
      return mp3Format.createWriterFor(outputStream,
          options.withBitsPerSample(bitDepth).withQualityOptionIndex(qualityOptionIndex));
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

void RenderController::sendRenderStartedEvent(int64_t renderId) {
  Response response =
      RenderStartedEvent{.renderId = renderId, .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderProgressEvent(int64_t renderId, double progress) {
  Response response = RenderProgressEvent{.renderId = renderId,
      .progress = std::clamp(progress, 0.0, 1.0),
      .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderCompletedEvent(int64_t renderId) {
  Response response =
      RenderCompletedEvent{.renderId = renderId, .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

void RenderController::sendRenderFailedEvent(int64_t renderId, const std::string& error) {
  Response response = RenderFailedEvent{
      .renderId = renderId, .error = error, .responseBase = ResponseBase{.id = -1}};

  auto responseText = rfl::json::write(response);
  comms.send(responseText);
}

RenderStartResult RenderController::startRender(const RenderStartOptions& options) {
  if (isRenderingFlag.exchange(true, std::memory_order_acq_rel)) {
    return renderStartFailure("Render is already running.");
  }

  if (!audioSessionController.isRenderAudioSessionRunning()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Render audio session is not active.");
  }

  if (options.outputPath.empty()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Render output path must not be empty.");
  }

  const auto exportOptionsError =
      validateRenderExportOptions(options.format, options.bitDepth, options.qualityOptionIndex);
  if (exportOptionsError.has_value()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure(exportOptionsError.value());
  }

#ifdef __EMSCRIPTEN__
  isRenderingFlag.store(false, std::memory_order_release);
  return renderStartFailure("File render is not available on web yet.");
#else
  if (options.format == RenderAudioFormat::mp3) {
    const auto lameExecutable = resolveLameExecutable();
    if (!lameExecutable.existsAsFile()) {
      isRenderingFlag.store(false, std::memory_order_release);
      return renderStartFailure("LAME executable was not found at " +
                                lameExecutable.getFullPathName().toStdString() + ".");
    }
  }
#endif

  if (options.startTick < 0 || options.endTick <= options.startTick) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure(
        "Render tick range must have a non-negative start and positive length.");
  }

  auto audioProcessingConfig = audioSessionController.getCurrentAudioProcessingConfigSnapshot();
  if (!audioProcessingConfig.has_value()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("No audio processing config is active.");
  }

  const auto arrangementId = getArrangementId();
  if (!arrangementId.has_value()) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("The project arrangement is not available for render.");
  }

  auto masterOutputProcessor = getMasterOutputProcessor();
  if (masterOutputProcessor == nullptr) {
    isRenderingFlag.store(false, std::memory_order_release);
    return renderStartFailure("Master output processor is not available for render.");
  }

  const auto maximumTailSamples =
      options.includeTail
          ? RenderTailDetector::secondsToSamples(
                RenderTailDetector::maximumTailSeconds, audioProcessingConfig->config.sampleRate)
          : 0;
  auto renderJob = RenderJob{.renderId = options.renderId,
      .outputPath = options.outputPath,
      .format = options.format,
      .activeSequenceId = arrangementId.value(),
      .startTick = options.startTick,
      .endTick = options.endTick,
      .includeTail = options.includeTail,
      .bitDepth = static_cast<int>(options.bitDepth),
      .qualityOptionIndex = static_cast<int>(options.qualityOptionIndex),
      .sampleFormat = options.sampleFormat,
      .maximumTailSamples = maximumTailSamples,
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
    VisualizationBroker::getInstance().suppressOutboundUpdates();

    if (!renderThread->startThread()) {
      renderThread.reset();
      VisualizationBroker::getInstance().discardPendingUpdatesThenResume();
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
  juce::MessageManager::callAsync(
      []() { VisualizationBroker::getInstance().discardPendingUpdatesThenResume(); });
}

void RenderController::runRender(const RenderJob& renderJob, RenderThread& thread) {
#ifdef __EMSCRIPTEN__
  sendRenderFailedEvent(renderJob.renderId, "File render is not available on web yet.");
  isRenderingFlag.store(false, std::memory_order_release);
  return;
#else
  auto writer = createRenderWriter(renderJob.format,
      renderJob.outputPath,
      renderJob.sampleRate,
      renderJob.outputChannelCount,
      renderJob.bitDepth,
      renderJob.qualityOptionIndex,
      renderJob.sampleFormat);
  if (writer == nullptr) {
    juce::MessageManager::callAsync(
        []() { VisualizationBroker::getInstance().discardPendingUpdatesThenResume(); });
    sendRenderFailedEvent(renderJob.renderId, "Failed to create render output file.");
    isRenderingFlag.store(false, std::memory_order_release);
    return;
  }

  transport.beginRenderPlayback(renderJob.activeSequenceId,
      static_cast<double>(renderJob.startTick),
      static_cast<double>(renderJob.endTick));
  sendRenderStartedEvent(renderJob.renderId);

  auto tailDetector = RenderTailDetector(RenderTailDetector::secondsToSamples(
      RenderTailDetector::defaultRequiredSilenceSeconds, renderJob.sampleRate));

  int64_t tailRenderedSamples = 0;
  int64_t lastProgressPercent = -1;
  auto lastProgressUpdateTime = std::chrono::steady_clock::now();

  auto getSourceProgress = [&]() {
    const auto tickRange = static_cast<double>(renderJob.endTick - renderJob.startTick);
    if (tickRange <= 0.0) {
      return 0.0;
    }

    return std::clamp(
        (transport.rt_playhead - static_cast<double>(renderJob.startTick)) / tickRange, 0.0, 1.0);
  };

  auto sendProgressIfNeeded = [&](bool force) {
    const auto progress = getSourceProgress();
    const auto progressPercent = static_cast<int64_t>(std::floor(progress * 100.0));
    const auto now = std::chrono::steady_clock::now();
    const auto millisecondsSinceLastUpdate =
        std::chrono::duration_cast<std::chrono::milliseconds>(now - lastProgressUpdateTime).count();

    if (force || progressPercent != lastProgressPercent || millisecondsSinceLastUpdate >= 50) {
      sendRenderProgressEvent(renderJob.renderId, progress);
      lastProgressPercent = progressPercent;
      lastProgressUpdateTime = now;
    }
  };

  auto sourceComplete = false;
  while (!sourceComplete) {
    if (thread.threadShouldExit()) {
      finishRenderThreadState();
      sendRenderFailedEvent(renderJob.renderId, "Render was stopped.");
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    const auto processResult = audioBlockProcessor.processAudioBlock(
        renderJob.blockSize, renderJob.sampleRate, renderJob.audioProcessingConfigGeneration);
    if (!processResult.didProcessGraph) {
      finishRenderThreadState();
      sendRenderFailedEvent(renderJob.renderId, "No processing graph is active for render.");
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    const auto samplesThisBlock = processResult.processedSamples;
    if (samplesThisBlock > 0) {
      auto& outputBuffer = renderJob.masterOutputProcessor->buffer;
      jassert(outputBuffer.getNumChannels() >= renderJob.outputChannelCount);
      jassert(outputBuffer.getNumSamples() >= samplesThisBlock);

      if (!writer->writeFromAudioSampleBuffer(outputBuffer, 0, samplesThisBlock)) {
        finishRenderThreadState();
        sendRenderFailedEvent(renderJob.renderId, "Failed to write render output file.");
        isRenderingFlag.store(false, std::memory_order_release);
        return;
      }

    } else if (!processResult.didReachScheduledStop) {
      finishRenderThreadState();
      sendRenderFailedEvent(renderJob.renderId, "Render did not make progress.");
      isRenderingFlag.store(false, std::memory_order_release);
      return;
    }

    sendProgressIfNeeded(processResult.didReachScheduledStop);
    sourceComplete = processResult.didReachScheduledStop;
  }

  if (renderJob.includeTail) {
    while (tailRenderedSamples < renderJob.maximumTailSamples) {
      if (thread.threadShouldExit()) {
        finishRenderThreadState();
        sendRenderFailedEvent(renderJob.renderId, "Render was stopped.");
        isRenderingFlag.store(false, std::memory_order_release);
        return;
      }

      const auto remainingTailSamples = renderJob.maximumTailSamples - tailRenderedSamples;
      const auto requestedTailSamples =
          static_cast<int>(std::min<int64_t>(renderJob.blockSize, remainingTailSamples));
      const auto processResult = audioBlockProcessor.processAudioBlock(
          requestedTailSamples, renderJob.sampleRate, renderJob.audioProcessingConfigGeneration);
      if (!processResult.didProcessGraph) {
        finishRenderThreadState();
        sendRenderFailedEvent(renderJob.renderId, "No processing graph is active for render.");
        isRenderingFlag.store(false, std::memory_order_release);
        return;
      }

      const auto samplesThisBlock = processResult.processedSamples;
      if (samplesThisBlock <= 0) {
        finishRenderThreadState();
        sendRenderFailedEvent(renderJob.renderId, "Render tail did not make progress.");
        isRenderingFlag.store(false, std::memory_order_release);
        return;
      }

      auto& outputBuffer = renderJob.masterOutputProcessor->buffer;
      jassert(outputBuffer.getNumChannels() >= renderJob.outputChannelCount);
      jassert(outputBuffer.getNumSamples() >= samplesThisBlock);

      if (!writer->writeFromAudioSampleBuffer(outputBuffer, 0, samplesThisBlock)) {
        finishRenderThreadState();
        sendRenderFailedEvent(renderJob.renderId, "Failed to write render output file.");
        isRenderingFlag.store(false, std::memory_order_release);
        return;
      }

      tailRenderedSamples += samplesThisBlock;

      const auto tailIsComplete =
          tailDetector.processBlock(outputBuffer, renderJob.outputChannelCount, samplesThisBlock);

      sendProgressIfNeeded(false);

      if (tailIsComplete) {
        break;
      }
    }
  }

  finishRenderThreadState();
  writer.reset();

  const auto outputFile = juce::File(renderJob.outputPath);
  if (!outputFile.existsAsFile() || outputFile.getSize() <= 0) {
    sendRenderFailedEvent(renderJob.renderId, "Render output file was not created.");
    isRenderingFlag.store(false, std::memory_order_release);
    return;
  }

  sendRenderCompletedEvent(renderJob.renderId);
  isRenderingFlag.store(false, std::memory_order_release);
#endif
}

} // namespace anthem
