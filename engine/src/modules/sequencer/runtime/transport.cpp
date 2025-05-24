/*
  Copyright (C) 2025 Joshua Wade

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

#include "transport.h"

Transport::Transport() : rt_playhead{0.0} {
  // Initialize the transport with default values
  configBufferedValue.set(TransportConfig{});
}

void Transport::play() {
  config.isPlaying = true;
  configBufferedValue.set(config);
}

void Transport::stop() {
  config.isPlaying = false;
  configBufferedValue.set(config);
}

void Transport::rt_prepareForProcessingBlock() {
  // Get the current transport state
  auto newConfig = configBufferedValue.rt_get();

  // Check if the transport state has changed

  // Check for stop
  if (!newConfig.isPlaying && rt_config.isPlaying) {
    rt_playhead = 0.0; // Reset the playhead position

    // TODO: We will need to send a stop notes event for any channels receiving
    // notes
  }

  // Update the real-time transport state
  rt_config = newConfig;
}

void Transport::rt_advancePlayhead(int numSamples) {
  rt_playhead = rt_getPlayheadAfterAdvance(numSamples);
}

double Transport::rt_getPlayheadAfterAdvance(int numSamples) {
  if (rt_config.isPlaying) {
    auto ticksPerQuarter = rt_config.ticksPerQuarter;
    auto beatsPerMinute = rt_config.beatsPerMinute;
    auto ticksPerMinute = ticksPerQuarter * beatsPerMinute;
    auto ticksPerSecond = ticksPerMinute / 60.0;
    auto ticksPerSample = ticksPerSecond / 48000.0; // Assuming a sample rate of 48000 Hz
    auto ticks = static_cast<double>(numSamples * ticksPerSample);
    return rt_playhead + ticks;
  }

  return rt_playhead;
}
