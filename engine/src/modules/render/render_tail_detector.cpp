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

#include "render_tail_detector.h"

#include <algorithm>
#include <cmath>

namespace anthem {

RenderTailDetector::RenderTailDetector(int64_t requiredSilentSamples, float silenceThreshold)
  : requiredSilentSamples(requiredSilentSamples), silenceThreshold(silenceThreshold) {
  jassert(requiredSilentSamples > 0);
  jassert(silenceThreshold >= 0.0f);
}

int64_t RenderTailDetector::secondsToSamples(double seconds, double sampleRate) {
  jassert(seconds >= 0.0);
  jassert(sampleRate > 0.0);

  return static_cast<int64_t>(std::ceil(seconds * sampleRate));
}

bool RenderTailDetector::processBlock(
    const juce::AudioSampleBuffer& buffer, int outputChannelCount, int numSamples) {
  jassert(outputChannelCount <= buffer.getNumChannels());
  jassert(numSamples <= buffer.getNumSamples());

  auto blockMagnitude = 0.0f;

  for (int channel = 0; channel < outputChannelCount; ++channel) {
    blockMagnitude = std::max(blockMagnitude, buffer.getMagnitude(channel, 0, numSamples));
  }

  if (blockMagnitude <= silenceThreshold) {
    consecutiveSilentSamples += numSamples;
  } else {
    consecutiveSilentSamples = 0;
  }

  return consecutiveSilentSamples >= requiredSilentSamples;
}

} // namespace anthem
