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

#pragma once

#include <algorithm>
#include <cstddef>
#include <juce_core/juce_core.h>

namespace anthem {

class AudioBufferView {
private:
  float* data = nullptr;
  int numChannels = 0;
  int numSamples = 0;
  int channelStride = 0;
public:
  AudioBufferView() = default;

  AudioBufferView(float* data, int numChannels, int numSamples, int channelStride)
    : data(data), numChannels(numChannels), numSamples(numSamples), channelStride(channelStride) {}

  bool isValid() const {
    return data != nullptr && numChannels >= 0 && numSamples >= 0 && channelStride >= numSamples;
  }

  int getNumChannels() const {
    return numChannels;
  }

  int getNumSamples() const {
    return numSamples;
  }

  float* getWritePointer(int channel) const {
    jassert(data != nullptr);
    jassert(channel >= 0);
    jassert(channel < numChannels);

    if (data == nullptr || channel < 0 || channel >= numChannels) {
      return nullptr;
    }

    return data + static_cast<size_t>(channel) * static_cast<size_t>(channelStride);
  }

  const float* getReadPointer(int channel) const {
    return getWritePointer(channel);
  }

  float getSample(int channel, int sample) const {
    jassert(sample >= 0);
    jassert(sample < numSamples);

    const auto* channelData = getReadPointer(channel);
    if (channelData == nullptr || sample < 0 || sample >= numSamples) {
      return 0.0f;
    }

    return channelData[sample];
  }

  void setSample(int channel, int sample, float value) const {
    jassert(sample >= 0);
    jassert(sample < numSamples);

    auto* channelData = getWritePointer(channel);
    if (channelData == nullptr || sample < 0 || sample >= numSamples) {
      return;
    }

    channelData[sample] = value;
  }

  void clear() const {
    for (int channel = 0; channel < numChannels; ++channel) {
      clear(channel, 0, numSamples);
    }
  }

  void clear(int channel, int startSample, int sampleCount) const {
    jassert(startSample >= 0);
    jassert(sampleCount >= 0);
    jassert(startSample + sampleCount <= numSamples);

    auto* channelData = getWritePointer(channel);
    if (channelData == nullptr || startSample < 0 || sampleCount <= 0 ||
        startSample >= numSamples) {
      return;
    }

    const auto clampedSampleCount = std::min(sampleCount, numSamples - startSample);
    std::fill(channelData + startSample, channelData + startSample + clampedSampleCount, 0.0f);
  }

  void copyFrom(int destinationChannel,
      int destinationStartSample,
      const AudioBufferView& source,
      int sourceChannel,
      int sourceStartSample,
      int sampleCount) const {
    jassert(destinationStartSample >= 0);
    jassert(sourceStartSample >= 0);
    jassert(sampleCount >= 0);
    jassert(destinationStartSample + sampleCount <= numSamples);
    jassert(sourceStartSample + sampleCount <= source.getNumSamples());

    auto* destinationData = getWritePointer(destinationChannel);
    const auto* sourceData = source.getReadPointer(sourceChannel);

    if (destinationData == nullptr || sourceData == nullptr || destinationStartSample < 0 ||
        sourceStartSample < 0 || sampleCount <= 0) {
      return;
    }

    const auto clampedSampleCount = std::min({sampleCount,
        numSamples - destinationStartSample,
        source.getNumSamples() - sourceStartSample});
    if (clampedSampleCount <= 0) {
      return;
    }

    std::copy(sourceData + sourceStartSample,
        sourceData + sourceStartSample + clampedSampleCount,
        destinationData + destinationStartSample);
  }
};

} // namespace anthem
