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

#include <cmath>
#include <cstdint>
#include <limits>

namespace sequencer_timing {

struct TimingParams {
  int64_t ticksPerQuarter;
  double beatsPerMinute;
  double sampleRate;
};

inline bool hasValidTimingParams(const TimingParams& params) {
  return params.ticksPerQuarter > 0 &&
    params.beatsPerMinute > 0.0 &&
    params.sampleRate > 0.0;
}

inline double sampleCountToTickDelta(
  double sampleCount,
  const TimingParams& params
) {
  if (!hasValidTimingParams(params)) {
    return 0.0;
  }

  auto ticksPerMinute =
    static_cast<double>(params.ticksPerQuarter) * params.beatsPerMinute;
  auto ticksPerSecond = ticksPerMinute / 60.0;
  auto ticksPerSample = ticksPerSecond / params.sampleRate;

  return sampleCount * ticksPerSample;
}

inline double tickDeltaToSampleOffset(
  double tickDelta,
  const TimingParams& params
) {
  if (!hasValidTimingParams(params)) {
    return 0.0;
  }

  auto ticksPerMinute =
    static_cast<double>(params.ticksPerQuarter) * params.beatsPerMinute;
  auto ticksPerSecond = ticksPerMinute / 60.0;
  auto ticksPerSample = ticksPerSecond / params.sampleRate;

  return tickDelta / ticksPerSample;
}

inline bool hasValidLoopRange(double loopStart, double loopEnd) {
  return std::isfinite(loopStart) &&
    std::isfinite(loopEnd) &&
    loopEnd > loopStart;
}

inline double wrapPlayheadToLoop(
  double playheadPosition,
  double loopStart,
  double loopEnd
) {
  if (!hasValidLoopRange(loopStart, loopEnd)) {
    return playheadPosition;
  }

  auto loopLength = loopEnd - loopStart;
  auto normalizedPosition =
    std::fmod(playheadPosition - loopStart, loopLength);

  if (normalizedPosition < 0.0) {
    normalizedPosition += loopLength;
  }

  return loopStart + normalizedPosition;
}

inline double advancePlayheadByTickDelta(
  double playheadPosition,
  double tickDelta,
  double loopStart,
  double loopEnd
) {
  if (tickDelta <= 0.0) {
    return playheadPosition;
  }

  if (!hasValidLoopRange(loopStart, loopEnd)) {
    return playheadPosition + tickDelta;
  }

  double timePointer = wrapPlayheadToLoop(playheadPosition, loopStart, loopEnd);
  double incrementRemaining = tickDelta;

  while (incrementRemaining > 0.0) {
    double incrementAmount = incrementRemaining;

    if (timePointer + incrementAmount >= loopEnd) {
      incrementAmount = loopEnd - timePointer;
      incrementRemaining -= incrementAmount;
      timePointer = loopStart;
    }
    else {
      timePointer += incrementAmount;
      incrementRemaining = 0.0;
    }
  }

  return timePointer;
}

} // namespace sequencer_timing
