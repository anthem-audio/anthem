/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

AnthemAudioCallback::AnthemAudioCallback(Anthem* anthem) {
  this->anthem = anthem;

  auto masterOutputNodeSharedPtr = Anthem::getInstance().project->processingGraph()->nodes()->at(
    Anthem::getInstance().project->processingGraph()->masterOutputNodeId()
  );
  masterOutputProcessorSharedPtr = std::static_pointer_cast<MasterOutputProcessor>(masterOutputNodeSharedPtr->getProcessor().value());
  masterOutputProcessor = masterOutputProcessorSharedPtr.get();

  cpuBurdenProvider = Anthem::getInstance().globalVisualizationSources->cpuBurdenProvider.get();
  playheadPositionProvider = Anthem::getInstance().globalVisualizationSources->playheadPositionProvider.get();
  playheadSequenceIdProvider = Anthem::getInstance().globalVisualizationSources->playheadSequenceIdProvider.get();
}

void AnthemAudioCallback::audioDeviceIOCallbackWithContext(
  [[maybe_unused]] const float* const* inputChannelData,
  [[maybe_unused]] int numInputChannels,
  float* const* outputChannelData,
  int numOutputChannels,
  int numSamples,
  [[maybe_unused]] const juce::AudioIODeviceCallbackContext& context
) {
  jassert(numSamples <= MAX_AUDIO_BUFFER_SIZE);
  auto startTime = std::chrono::high_resolution_clock::now();
  
  auto transport = anthem->transport.get();

  // Set up the transport for this processing block
  transport->rt_prepareForProcessingBlock();

  // Tell the sequence store to pick up any sequence updates.
  anthem->sequenceStore->rt_processSequenceChanges(numSamples);

  anthem->graphProcessor->process(numSamples);

  auto& outputBuffer = masterOutputProcessor->buffer;

  bool badValue = false;
  float lastBadValue = 0.0f;
  
  for (int channel = 0; channel < numOutputChannels; ++channel) {
    if (outputChannelData[channel] == nullptr) {
      continue;
    }

    for (int sample = 0; sample < numSamples; ++sample) {
      auto sampleValue = outputBuffer.getSample(channel, sample);
      if (std::isnan(sampleValue) || std::isinf(sampleValue) || sampleValue > 100.0f || sampleValue < -100.0f) {
        badValue = true;
        lastBadValue = sampleValue;
        sampleValue = 0.0f;
      }
      outputChannelData[channel][sample] = sampleValue;
    }
  }

  // Get ms since epoch
  auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
    std::chrono::system_clock::now().time_since_epoch()
  ).count();

  if (now - lastDebugOutputTime > 2000) {
    if (badValue) {
      std::cout << "Bad value detected in audio callback. Last bad value: " << lastBadValue << std::endl;
    }
    lastDebugOutputTime = now;
  }

  auto endTime = std::chrono::high_resolution_clock::now();

  auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime).count();
  auto durationInSeconds = static_cast<double>(duration) / 1e6;
  auto sampleRate = 48000.0f; // TODO: Get sample rate from device
  auto cpuBurden = durationInSeconds * sampleRate / static_cast<double>(numSamples); // actual time / total buffer time
  cpuBurdenProvider->rt_updateCpuBurden(cpuBurden);

  playheadPositionProvider->rt_updatePlayheadPosition(transport->rt_playhead);

  if (transport->rt_config.activeSequenceId.has_value()) {
    // This is a pass-by-reference and the function reads out the byte data to a
    // pre-allocated array, making it real-time safe.
    playheadSequenceIdProvider->rt_updatePlayheadSequenceId(transport->rt_config.activeSequenceId.value());
  }

  transport->rt_advancePlayhead(numSamples);
  anthem->sequenceStore->rt_cleanupAfterBlock();
}

void AnthemAudioCallback::audioDeviceAboutToStart([[maybe_unused]] juce::AudioIODevice* device) {
  // this->sampleRate = device->getCurrentSampleRate();
  // TODO
}

void AnthemAudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}
