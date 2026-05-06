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

#include "bw_math.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <vector>

namespace anthem {

class DbMeterAccumulator {
private:
  std::vector<float> rt_channelPeakLinear;
  int64_t rt_samplesSinceLastPublish = 0;

  static double rt_peakLinearToDb(float peakLinear) {
    if (peakLinear <= 0.0f) {
      return -600.0;
    }

    return static_cast<double>(bw_lin2dBf(peakLinear));
  }

  template <typename PublishCallback>
  void rt_publishCurrentWindow(
      int channelCount, int64_t sampleTimestamp, PublishCallback& publish) {
    for (size_t channelIndex = 0; channelIndex < static_cast<size_t>(channelCount);
        ++channelIndex) {
      publish(channelIndex, rt_peakLinearToDb(rt_channelPeakLinear[channelIndex]), sampleTimestamp);
    }

    std::fill(rt_channelPeakLinear.begin(), rt_channelPeakLinear.end(), 0.0f);
  }
public:
  void rt_prepare(size_t channelCount) {
    rt_channelPeakLinear.assign(channelCount, 0.0f);
    rt_samplesSinceLastPublish = 0;
  }

  template <typename PublishCallback>
  void rt_processBlock(const juce::AudioBuffer<float>& audioInBuffer,
      int numSamples,
      int64_t blockStartSample,
      int64_t publishEverySamples,
      PublishCallback&& publish) {
    if (numSamples <= 0) {
      return;
    }

    const int channelCount = audioInBuffer.getNumChannels();

    if (channelCount <= 0) {
      return;
    }

    if (rt_channelPeakLinear.size() != static_cast<size_t>(channelCount)) {
      jassertfalse;
      return;
    }

    const int64_t rt_publishEveryClamped = std::max<int64_t>(1, publishEverySamples);

    for (int sampleIndex = 0; sampleIndex < numSamples; ++sampleIndex) {
      for (int channelIndex = 0; channelIndex < channelCount; ++channelIndex) {
        const float absoluteSample = std::abs(audioInBuffer.getSample(channelIndex, sampleIndex));
        rt_channelPeakLinear[static_cast<size_t>(channelIndex)] =
            std::max(rt_channelPeakLinear[static_cast<size_t>(channelIndex)], absoluteSample);
      }

      rt_samplesSinceLastPublish++;

      if (rt_samplesSinceLastPublish >= rt_publishEveryClamped) {
        rt_publishCurrentWindow(
            channelCount, blockStartSample + static_cast<int64_t>(sampleIndex) + 1, publish);
        rt_samplesSinceLastPublish = 0;
      }
    }
  }
};

} // namespace anthem
