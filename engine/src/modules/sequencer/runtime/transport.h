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

#pragma once

#include <atomic>
#include <cstdint>
#include <optional>
#include <unordered_map>
#include <vector>

#include "juce_events/juce_events.h"

#include "modules/util/double_buffered_value.h"
#include "modules/util/ring_buffer.h"
#include "modules/sequencer/events/event.h"

class TransportConfig {
public:
  std::optional<std::string> activeSequenceId;
  int64_t ticksPerQuarter = 96;
  double beatsPerMinute = 120.0;
  bool isPlaying = false;
  double playheadStart = 0.0;
};

// Represents the playhead jumping to a new location for the current sequence.
//
// There is a map included that contains the events that should be played at the
// new playhead position. For example, if we jump into the middle of a note, we
// want to start playing that note.
class PlayheadJumpEvent {
public:
  double newPlayheadPosition = 0.0;
  std::unordered_map<std::string, std::vector<AnthemLiveEvent>> eventsToPlayAtJump;
};

class Transport : private juce::Timer {
private:
  // The audio thread reads the transport state from here
  DoubleBufferedValue<TransportConfig> configBufferedValue;

  // Playhead jump events are sent to the audio thread through this buffer.
  RingBuffer<PlayheadJumpEvent*, 64> playheadJumpEventBuffer;

  // PLayhead jump events are sent back to the main thread for deletion through
  // this buffer.
  RingBuffer<PlayheadJumpEvent*, 64> playheadJumpEventDeleteBuffer;

  void timerCallback() override;

public:
  // The transport config.
  //
  // This should only be modified using the methods below.
  TransportConfig config;

  // The playhead position
  double rt_playhead;

  // The current playhead jump event, if one is relevant for the current
  // processing block.
  PlayheadJumpEvent* rt_playheadJumpEvent;

  // The transport state, as seen by the audio thread.
  //
  // This should be read at the start of every processing block.
  TransportConfig rt_config;

  // This will be true if a stop or jump was requested for the current
  // processing block.
  //
  // This will be set before the node graph is processed for the frame, and
  // reset after.
  bool rt_playheadJumpOrPauseOccurred = false;

  Transport();

  void setIsPlaying(bool isPlaying) {
    config.isPlaying = isPlaying;
    configBufferedValue.set(config);
  }
  void setActiveSequenceId(std::optional<std::string>& sequenceId) {
    config.activeSequenceId = sequenceId;
    configBufferedValue.set(config);
  }
  void setTicksPerQuarter(int64_t ticksPerQuarter) {
    config.ticksPerQuarter = ticksPerQuarter;
    configBufferedValue.set(config);
  }
  void setBeatsPerMinute(double beatsPerMinute) {
    config.beatsPerMinute = beatsPerMinute;
    configBufferedValue.set(config);
  }
  void setPlayheadStart(double playheadPosition) {
    config.playheadStart = playheadPosition;
    configBufferedValue.set(config);
  }
  void jumpTo(double playheadPosition);

  // Must be called at the start of every processing block.
  void rt_prepareForProcessingBlock();

  // Advances the playhead by the given number of samples.
  //
  // This should be called at the end of every processing block, and should be
  // the last thing done within the transport for the block.
  void rt_advancePlayhead(int samples);

  // Returns the value that the playhead would have after advancing it by the
  // given number of samples.
  double rt_getPlayheadAfterAdvance(int samples);
};
