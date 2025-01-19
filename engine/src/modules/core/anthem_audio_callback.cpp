/*
  Copyright (C) 2024 Joshua Wade

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

  anthem->graphProcessor->process(numSamples);

  auto& outputBuffer = masterOutputProcessor->buffer;
  
  for (int channel = 0; channel < numOutputChannels; ++channel) {
    if (outputChannelData[channel] != nullptr) {
      for (int sample = 0; sample < numSamples; ++sample) {
        auto sampleValue = outputBuffer.getSample(channel, sample);
        outputChannelData[channel][sample] = sampleValue;
      }
    }
  }
}

void AnthemAudioCallback::audioDeviceAboutToStart([[maybe_unused]] juce::AudioIODevice* device) {
  // this->sampleRate = device->getCurrentSampleRate();
  // TODO
}

void AnthemAudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}
