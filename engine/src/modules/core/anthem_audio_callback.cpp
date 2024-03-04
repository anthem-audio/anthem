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

void AnthemAudioCallback::audioDeviceIOCallbackWithContext(
  const float* const* inputChannelData,
  int numInputChannels,
  float* const* outputChannelData,
  int numOutputChannels,
  int numSamples,
  const juce::AudioIODeviceCallbackContext& context
) {
  // // Generate a sine wave
  // for (int sample = 0; sample < numSamples; ++sample) {
  //   const float value = amplitude * std::sin(
  //     2.0 * juce::MathConstants<float>::pi * frequency * currentSample / sampleRate
  //   );

  //   for (int channel = 0; channel < numOutputChannels; ++channel) {
  //     if (outputChannelData[channel] != nullptr) {
  //       outputChannelData[channel][sample] = value;
  //     }
  //   }

  //   currentSample++;
  // }

  jassert(numSamples <= MAX_AUDIO_BUFFER_SIZE);

  processingGraph->getProcessor().process(numSamples);
  auto& outputNode = static_cast<MasterOutputNode&>(*masterOutputNode->processor);
  auto& outputBuffer = outputNode.buffer;
  
  for (int channel = 0; channel < numOutputChannels; ++channel) {
    if (outputChannelData[channel] != nullptr) {
      for (int sample = 0; sample < numSamples; ++sample) {
        outputChannelData[channel][sample] = outputBuffer.getSample(channel, sample);
      }
    }
  }
}

void AnthemAudioCallback::audioDeviceAboutToStart(juce::AudioIODevice* device) {
  // this->sampleRate = device->getCurrentSampleRate();
  // TODO
}

void AnthemAudioCallback::audioDeviceStopped() {
  // this->currentSample = 0;
}
