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

#include "audio_callback.h"

#include "modules/core/engine.h"

#include <algorithm>
#include <chrono>
#include <stdexcept>
#include <string>

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

  cpuBurdenProvider =
      Engine::getInstance().globalVisualizationSources->cpuBurdenProvider.rt_getProvider();
  playheadPositionProvider =
      Engine::getInstance().globalVisualizationSources->playheadPositionProvider.rt_getProvider();
  playheadSequenceIdProvider =
      Engine::getInstance().globalVisualizationSources->playheadSequenceIdProvider.rt_getProvider();

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
  engine->automationSequenceStore->rt_processSequenceChanges(numSamples);

  const auto didProcessGraph =
      engine->graphProcessor->rt_process(numSamples, engine->getAudioProcessingConfigGeneration());

  auto& outputBuffer = masterOutputProcessor->buffer;

  // A processed graph must provide a master output buffer that matches the
  // callback block shape.
  if (didProcessGraph) {
    jassert(outputBuffer.getNumChannels() >= numOutputChannels);
    jassert(outputBuffer.getNumSamples() >= numSamples);

    for (int channel = 0; channel < numOutputChannels; ++channel) {
      if (outputChannelData[channel] == nullptr) {
        continue;
      }

      for (int sample = 0; sample < numSamples; ++sample) {
        outputChannelData[channel][sample] = outputBuffer.getSample(channel, sample);
      }
    }
  } else {
    for (int channel = 0; channel < numOutputChannels; ++channel) {
      if (outputChannelData[channel] != nullptr) {
        std::fill_n(outputChannelData[channel], numSamples, 0.0f);
      }
    }
  }

  auto endTime = std::chrono::high_resolution_clock::now();

  auto duration =
      std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
  auto durationInSeconds = static_cast<double>(duration) / 1e6;
  jassert(rt_sampleRate >= 0.0);
  const auto sampleRate = rt_sampleRate;
  auto cpuBurden = durationInSeconds * sampleRate /
                   static_cast<double>(numSamples); // actual time / total buffer time
  cpuBurdenProvider->rt_updateCpuBurden(cpuBurden, blockStartSample, numSamples, sampleRate);

  playheadPositionProvider->rt_updatePlayheadPosition(
      *transport, blockStartSample, numSamples, sampleRate);

  auto& activeSequenceId = transport->rt_config->activeSequenceId;
  if (activeSequenceId.has_value()) {
    playheadSequenceIdProvider->rt_updatePlayheadSequenceId(*activeSequenceId, blockStartSample);
  }

  transport->rt_advancePlayhead(numSamples);
  engine->sequenceStore->rt_cleanupAfterBlock();
}

void AudioCallback::audioDeviceAboutToStart([[maybe_unused]] juce::AudioIODevice* device) {
  // JUCE does not guarantee which thread calls this. During initial startup,
  // engine preparation has already happened on the message thread before the
  // callback is registered. During a runtime device restart, keep this path
  // minimal and request an invalidation so the UI can perform a normal
  // stop/start cycle.

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

  rt_sampleRate = deviceSampleRate;

  engine->requestAudioSessionInvalidation(
      std::string("The audio device restarted while the audio session was running."));
}

void AudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}

} // namespace anthem
