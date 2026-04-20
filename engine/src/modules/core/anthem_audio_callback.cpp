/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

#include "anthem_audio_callback.h"

#include "modules/core/anthem.h"

#include <stdexcept>

namespace anthem {

AudioCallback::AudioCallback(Engine* engine) {
  this->engine = engine;

  juce::Logger::writeToLog("AnthemAudioCallback: constructing...");

  if (Engine::getInstance().project == nullptr) {
    throw std::runtime_error("project model is null");
  }

  auto& processingGraph = Engine::getInstance().project->processingGraph();
  auto masterOutputNodeId = processingGraph->masterOutputNodeId();

  juce::Logger::writeToLog(
      "AnthemAudioCallback: master output node id = " + juce::String(masterOutputNodeId));

  auto& nodes = *processingGraph->nodes();
  auto masterOutputNodeIter = nodes.find(masterOutputNodeId);
  if (masterOutputNodeIter == nodes.end()) {
    throw std::runtime_error("master output node not found in processing graph");
  }

  auto masterOutputNodeSharedPtr = masterOutputNodeIter->second;
  auto masterOutputProcessorOpt = masterOutputNodeSharedPtr->getProcessor();
  if (!masterOutputProcessorOpt.has_value()) {
    throw std::runtime_error("master output node does not have a processor");
  }

  masterOutputProcessorSharedPtr =
      std::dynamic_pointer_cast<MasterOutputProcessor>(masterOutputProcessorOpt.value());
  if (masterOutputProcessorSharedPtr == nullptr) {
    throw std::runtime_error("master output processor is not a MasterOutputProcessor");
  }

  masterOutputProcessor = masterOutputProcessorSharedPtr.get();

  cpuBurdenProvider = Engine::getInstance().globalVisualizationSources->cpuBurdenProvider.get();
  playheadPositionProvider =
      Engine::getInstance().globalVisualizationSources->playheadPositionProvider.get();
  playheadSequenceIdProvider =
      Engine::getInstance().globalVisualizationSources->playheadSequenceIdProvider.get();

  juce::Logger::writeToLog("AnthemAudioCallback: constructed successfully.");
}

void AudioCallback::audioDeviceIOCallbackWithContext(
    [[maybe_unused]] const float* const* inputChannelData,
    [[maybe_unused]] int numInputChannels,
    float* const* outputChannelData,
    int numOutputChannels,
    int numSamples,
    [[maybe_unused]] const juce::AudioIODeviceCallbackContext& context) {
  auto startTime = std::chrono::high_resolution_clock::now();

  auto transport = engine->transport.get();

  // Set up the transport for this processing block
  transport->rt_prepareForProcessingBlock();
  const auto blockStartSample = transport->rt_sampleCounter;

  // Tell the sequence store to pick up any sequence updates.
  engine->sequenceStore->rt_processSequenceChanges(numSamples);

  engine->graphProcessor->process(numSamples);

  auto& outputBuffer = masterOutputProcessor->buffer;

  bool badValue = false;
  float lastBadValue = 0.0f;

  // The master output node may have an empty buffer if it hasn't been initialized yet
  if (outputBuffer.getNumChannels() > 0 && outputBuffer.getNumSamples() > 0) {
    for (int channel = 0; channel < numOutputChannels; ++channel) {
      if (outputChannelData[channel] == nullptr) {
        continue;
      }

      for (int sample = 0; sample < numSamples; ++sample) {
        auto sampleValue = outputBuffer.getSample(channel, sample);
        if (std::isnan(sampleValue) || std::isinf(sampleValue) || sampleValue > 100.0f ||
            sampleValue < -100.0f) {
          badValue = true;
          lastBadValue = sampleValue;
          sampleValue = 0.0f;
        }
        outputChannelData[channel][sample] = sampleValue;
      }
    }
  }

  // Get ms since epoch
  auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::system_clock::now().time_since_epoch())
                 .count();

  if (now - lastDebugOutputTime > 2000) {
    if (badValue) {
      juce::Logger::writeToLog(
          "Bad value detected in audio callback. Last bad value: " + juce::String(lastBadValue));
    }
    lastDebugOutputTime = now;
  }

  auto endTime = std::chrono::high_resolution_clock::now();

  auto duration =
      std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
  auto durationInSeconds = static_cast<double>(duration) / 1e6;
  auto cpuBurden = durationInSeconds * this->sampleRate /
                   static_cast<double>(numSamples); // actual time / total buffer time
  cpuBurdenProvider->rt_updateCpuBurden(cpuBurden, blockStartSample, numSamples, this->sampleRate);

  playheadPositionProvider->rt_updatePlayheadPosition(
      *transport, blockStartSample, numSamples, this->sampleRate);

  auto& activeSequenceId = transport->rt_config->activeSequenceId;
  if (activeSequenceId.has_value()) {
    playheadSequenceIdProvider->rt_updatePlayheadSequenceId(*activeSequenceId, blockStartSample);
  }

  transport->rt_advancePlayhead(numSamples);
  engine->sequenceStore->rt_cleanupAfterBlock();
}

void AudioCallback::audioDeviceAboutToStart([[maybe_unused]] juce::AudioIODevice* device) {
  // According to this:
  //    https://forum.juce.com/t/which-thread-calls-audiodeviceabouttostart-stopped/6594
  // -- we don't have any guarantees about which thread this will be called on, so we
  // schedule this update to run on the message thread.

  if (device == nullptr) {
    juce::Logger::writeToLog("audioDeviceAboutToStart() received a null device.");
    return;
  }

  const auto deviceName = device->getName();
  const auto deviceSampleRate = device->getCurrentSampleRate();
  const auto bufferSize = device->getCurrentBufferSizeSamples();

  juce::Logger::writeToLog("audioDeviceAboutToStart(): device=" + deviceName +
                           ", sampleRate=" + juce::String(deviceSampleRate) +
                           ", bufferSize=" + juce::String(bufferSize));

  this->sampleRate = deviceSampleRate;

  juce::MessageManager::callAsync([deviceName, deviceSampleRate, this]() {
    auto& engine = Engine::getInstance();

    engine.transport->prepareToProcess();
    juce::Logger::writeToLog(
        "audioDeviceAboutToStart(): transport prepared for device " + deviceName);

    auto audioConfig = engine.getCurrentAudioConfig();
    if (audioConfig == nullptr) {
      juce::Logger::writeToLog(
          "audioDeviceAboutToStart(): Failed to build audio config for current device.");
      return;
    }

    // This notifies the UI that the engine has started
    Response response = AudioReadyEvent{
        .audioConfig = audioConfig,
        .responseBase = ResponseBase{.id = -1},
    };

    auto responseText = rfl::json::write(response);
    Engine::getInstance().comms.send(responseText);
    juce::Logger::writeToLog("audioDeviceAboutToStart(): AudioReadyEvent sent to UI.");
  });
}

void AudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}

} // namespace anthem
