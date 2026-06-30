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

#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>

namespace anthem {

class RenderTailDetector {
private:
  int64_t requiredSilentSamples = 0;
  float silenceThreshold = 0.0f;
  int64_t consecutiveSilentSamples = 0;
public:
  static constexpr auto defaultSilenceThreshold = 0.0001f;
  static constexpr auto defaultRequiredSilenceSeconds = 1.0;
  static constexpr auto maximumTailSeconds = 5.0 * 60.0;

  RenderTailDetector(
      int64_t requiredSilentSamples, float silenceThreshold = defaultSilenceThreshold);

  static int64_t secondsToSamples(double seconds, double sampleRate);

  bool processBlock(const juce::AudioSampleBuffer& buffer, int outputChannelCount, int numSamples);

  int64_t getConsecutiveSilentSamples() const {
    return consecutiveSilentSamples;
  }
};

} // namespace anthem
