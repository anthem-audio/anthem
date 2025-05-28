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

  rt_playheadJumpEvent = nullptr;

  // Start the cleanup loop, which will clean up memory sent back from the audio
  // thread
  this->startTimer(100);
}

void Transport::rt_prepareForProcessingBlock() {
  // Get the current transport state
  auto newConfig = configBufferedValue.rt_get();

  // Check if the transport state has changed

  // Check for stop
  if (!newConfig.isPlaying && rt_config.isPlaying) {
    rt_playhead = newConfig.playheadStart;

    // Provides a signal that instruments need to stop playing any active voices
    rt_playheadJumpOrPauseOccurred = true;
  }

  // Update the real-time transport state
  rt_config = newConfig;

  // Check if there are any playhead jump events to process
  while (auto event = playheadJumpEventBuffer.read()) {
    if (rt_playheadJumpEvent != nullptr) {
      playheadJumpEventDeleteBuffer.add(rt_playheadJumpEvent);
    }
    rt_playheadJumpEvent = event.value();
  }

  if (rt_playheadJumpEvent != nullptr) {
    rt_playhead = rt_playheadJumpEvent->newPlayheadPosition;
    rt_playheadJumpOrPauseOccurred = true;
  }
}

void Transport::rt_advancePlayhead(int numSamples) {
  rt_playhead = rt_getPlayheadAfterAdvance(numSamples);
  rt_playheadJumpOrPauseOccurred = false;

  // Send the playhead jump event back to the main thread for deletion, if there
  // is one
  if (rt_playheadJumpEvent != nullptr) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEvent);
    rt_playheadJumpEvent = nullptr;
  }
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

void Transport::jumpTo(double playheadPosition) {
  auto* event = new PlayheadJumpEvent();

  event->newPlayheadPosition = playheadPosition;

  // TODO: Get events to play at the new playhead position

  playheadJumpEventBuffer.add(event);
}

void Transport::timerCallback() {
  // Clean up any playhead jump events that have been sent back from the audio
  // thread for deletion
  while (auto event = playheadJumpEventDeleteBuffer.read()) {
    delete event.value();
  }
}