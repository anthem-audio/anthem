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

#include "modules/util/ring_buffer.h"
#include "modules/sequencer/events/event.h"

// Represents the playhead jumping to a new location for the current sequence.
//
// There is a map included that contains the events that should be played at the
// new playhead position. For example, if we jump into the middle of a note, we
// want to start playing that note.
class PlayheadJumpEvent {
private:
  JUCE_LEAK_DETECTOR(PlayheadJumpEvent)

public:
  double newPlayheadPosition = 0.0;
  std::unordered_map<std::string, std::vector<AnthemLiveEvent>> eventsToPlayAtJump;
};

class TransportConfig {
private:
  JUCE_LEAK_DETECTOR(TransportConfig)

public:
  std::optional<std::string> activeSequenceId;
  int64_t ticksPerQuarter = 96;
  double beatsPerMinute = 120.0;
  bool isPlaying = false;
  double playheadStart = 0.0;

  PlayheadJumpEvent playheadJumpEventForStart;

  bool hasLoop = false;
  std::optional<PlayheadJumpEvent> playheadJumpEventForLoop;
  double loopStart;
  double loopEnd;

  TransportConfig() {
    loopStart = 0.0;
    loopEnd = std::numeric_limits<double>::infinity();
  }
};

class Transport : private juce::Timer {
private:
  JUCE_LEAK_DETECTOR(Transport)

  // The audio thread reads the transport state from here
  RingBuffer<TransportConfig*, 64> configBuffer;

  // The audio thread sends old configs back to be deleted here
  RingBuffer<TransportConfig*, 64> configDeleteBuffer;

  // Playhead jump events are sent to the audio thread through this buffer.
  RingBuffer<PlayheadJumpEvent*, 64> playheadJumpEventBuffer;

  // PLayhead jump events are sent back to the main thread for deletion through
  // this buffer.
  RingBuffer<PlayheadJumpEvent*, 256> playheadJumpEventDeleteBuffer;

  PlayheadJumpEvent* rt_playheadJumpEventForSeek;
  PlayheadJumpEvent* rt_playheadJumpEventForStart;

  void timerCallback() override;

  void addStartEventsForPattern(
    std::string patternId, double offset, std::unordered_map<std::string, std::vector<AnthemLiveEvent>>& collector);

  PlayheadJumpEvent createPlayheadJumpEvent(double playheadPosition);

  void updateLoopPoints(bool send);
  void clearLoopPoints();

  void sendConfigToAudioThread();

  double sampleRate;

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
  TransportConfig* rt_config;

  // This will be true if a stop or jump was requested for the current
  // processing block.
  //
  // This will be set before the node graph is processed for the frame, and
  // reset after.
  bool rt_playheadJumpOrPauseOccurred = false;

  Transport();

  void setIsPlaying(bool isPlaying);
  void setActiveSequenceId(std::optional<std::string>& sequenceId);
  void setTicksPerQuarter(int64_t ticksPerQuarter);
  void setBeatsPerMinute(double beatsPerMinute);

  // Sets the start point for the playhead.
  //
  // The start point is the position that the playhead will jump to when the
  // transport is stopped, making it the place that playback will start from
  // when the transport is started again.
  void setPlayheadStart(double playheadPosition);
  void updatePlayheadJumpEventForStart(bool send = true);

  // Jumps the playhead to the given position.
  void jumpTo(double playheadPosition);

  // Pulls loop points from the active sequence and sends the relevant loop
  // information to the audio thread, including events to play on loop jump.
  void updateLoopPoints() {
    updateLoopPoints(true);
  }

  // Analogous to `prepareToProcess()` in AnthemProcessor, this must be called
  // before the transport is used for processing.
  void prepareToProcess();

  // Must be called at the start of every processing block.
  void rt_prepareForProcessingBlock();

  // Gets the exact number of ticks that the playhead would advance by, given
  // the current buffer size in samples.
  double rt_getPlayheadAdvanceAmount(int samples);

  // Advances the playhead by the given number of samples.
  //
  // This should be called at the end of every processing block, and should be
  // the last thing done within the transport for the block.
  void rt_advancePlayhead(int samples);

  // Returns the value that the playhead would have after advancing it by the
  // given number of samples.
  double rt_getPlayheadAfterAdvance(int samples);
};
