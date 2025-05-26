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

#include "modules/util/double_buffered_value.h"

class TransportConfig {
public:
  std::optional<std::string> activeSequenceId;
  int64_t ticksPerQuarter = 96;
  double beatsPerMinute = 120.0;
  bool isPlaying = false;
};

class Transport {
public:
  // The transport state
  TransportConfig config;

  // The audio thread reads the transport state from here
  DoubleBufferedValue<TransportConfig> configBufferedValue;

  // The transport state, as seen by the audio thread.
  //
  // This should be read at the start of every processing block.
  TransportConfig rt_config;

  // The playhead position
  double rt_playhead;

  // This will be true if a stop or jump was requested for the current
  // processing block.
  //
  // This will be set before the node graph is processed for the frame, and
  // reset after.
  bool rt_playheadJumpOccurred = false;

  Transport();

  void play();
  void stop();

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

  // Must be called at the start of every processing block.
  void rt_prepareForProcessingBlock();

  // Advances the playhead by the given number of samples.
  //
  // This should be called at the end of every processing block, and should be
  // the last thing done within the transport for the block.
  void rt_advancePlayhead(int samples);

  double rt_getPlayheadAfterAdvance(int samples);
};
