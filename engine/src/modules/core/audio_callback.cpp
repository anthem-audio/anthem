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

#include "modules/audio/audio_block_processor.h"
#include "modules/audio/audio_session_controller.h"
#include "project.h"

#include <algorithm>
#include <stdexcept>
#include <string>

namespace anthem {

AudioCallback::AudioCallback(Project& project,
    AudioBlockProcessor& audioBlockProcessor,
    AudioSessionController& audioSessionController)
  : audioBlockProcessor(audioBlockProcessor), audioSessionController(audioSessionController) {
  juce::Logger::writeToLog("AnthemAudioCallback: constructing...");

  auto& processingGraph = project.processingGraph();
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

  juce::Logger::writeToLog("AnthemAudioCallback: constructed successfully.");
}

void AudioCallback::audioDeviceIOCallbackWithContext(
    [[maybe_unused]] const float* const* inputChannelData,
    [[maybe_unused]] int numInputChannels,
    float* const* outputChannelData,
    int numOutputChannels,
    int numSamples,
    [[maybe_unused]] const juce::AudioIODeviceCallbackContext& context) {
  const auto didProcessGraph = audioBlockProcessor.processAudioBlock(
      numSamples, rt_sampleRate, audioSessionController.getAudioProcessingConfigGeneration());

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

  audioSessionController.requestAudioSessionInvalidation(
      std::string("The audio device restarted while the audio session was running."));
}

void AudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}

} // namespace anthem
