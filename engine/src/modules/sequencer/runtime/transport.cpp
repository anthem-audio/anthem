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

#include "modules/core/anthem.h"

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

  // Check for play
  if (newConfig.isPlaying && !rt_config.isPlaying) {
    // We should set the pointer that allows consumers to read any events we
    // want to post on start
    if (newConfig.playheadJumpEventForStart != nullptr) {
      rt_playheadJumpEventForStart = newConfig.playheadJumpEventForStart;
    }
  }

  // Check for change to start event list, and clean up the old one if necessary
  if (newConfig.playheadJumpEventForStart != rt_config.playheadJumpEventForStart) {
    if (rt_config.playheadJumpEventForStart != nullptr) {
      playheadJumpEventDeleteBuffer.add(rt_config.playheadJumpEventForStart);
    }
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

  // If we're not playing, then we do not want downstream consumers to pick up
  // any sequencer events that this object might have contained
  if (!rt_config.isPlaying) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEvent);
    rt_playheadJumpEvent = nullptr;
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

  rt_playheadJumpEventForStart = nullptr; // This is cleaned up elsewhere
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

PlayheadJumpEvent* Transport::createPlayheadJumpEvent(double playheadPosition) {
  auto* event = new PlayheadJumpEvent();

  event->newPlayheadPosition = playheadPosition;

  if (config.activeSequenceId.has_value()) {
    auto& patterns = *Anthem::getInstance().project->sequence()->patterns();
    if (patterns.find(config.activeSequenceId.value()) != patterns.end()) {
      auto& pattern = *patterns.at(config.activeSequenceId.value());
      event->eventsToPlayAtJump.clear();
      addStartEventsForPattern(config.activeSequenceId.value(), playheadPosition, event->eventsToPlayAtJump);
    }

    auto& arrangements = *Anthem::getInstance().project->sequence()->arrangements();
    if (arrangements.find(config.activeSequenceId.value()) != arrangements.end()) {
      auto& arrangement = *arrangements.at(config.activeSequenceId.value());

      for (auto& clipPair : *arrangement.clips()) {
        auto& clip = *clipPair.second;
        auto clipOffset = clip.offset();
        if (playheadPosition < clipOffset) {
          continue;
        }

        auto& clipTimeView = clip.timeView();
        if (clipTimeView.has_value()) {
          auto start = clipTimeView.value()->start();
          auto end = clipTimeView.value()->end();
          if (playheadPosition >= clipOffset + (end - start)) {
            continue;
          }

          addStartEventsForPattern(
            clip.patternId(), playheadPosition - clipOffset + start, event->eventsToPlayAtJump);
        }
        else {
          addStartEventsForPattern(
            clip.patternId(), playheadPosition - clipOffset, event->eventsToPlayAtJump);
        }
      }
    }
  }

  return event;
}

void Transport::setPlayheadStart(double playheadStart) {
  auto* event = createPlayheadJumpEvent(playheadStart);

  config.playheadStart = playheadStart;
  config.playheadJumpEventForStart = event;
  configBufferedValue.set(config);
}

void Transport::jumpTo(double playheadPosition) {
  auto* event = createPlayheadJumpEvent(playheadPosition);

  playheadJumpEventBuffer.add(event);
}

void Transport::timerCallback() {
  // Clean up any playhead jump events that have been sent back from the audio
  // thread for deletion
  while (auto event = playheadJumpEventDeleteBuffer.read()) {
    delete event.value();
  }
}

void Transport::addStartEventsForPattern(
  std::string patternId, double offset, std::unordered_map<std::string, std::vector<AnthemLiveEvent>>& collector) {
  auto& pattern = *Anthem::getInstance().project->sequence()->patterns()->at(patternId);

  for (auto& pair : *pattern.notes()) {
    auto& channelId = pair.first;
    auto& notes = pair.second;

    for (auto& note : *notes) {
      auto noteOffset = note->offset();
      auto noteLength = note->length();
      // noteOffset < offset, because if noteOffset == offset then the note
      // will be picked up by the sequencer
      if (noteOffset < offset && noteOffset + noteLength > offset) {
        if (collector.find(channelId) == collector.end()) {
          collector[channelId] = std::vector<AnthemLiveEvent>();
        }

        auto& events = collector[channelId];
        events.push_back(AnthemLiveEvent{
          .time = 0,
          .event = AnthemEvent {
            .type = AnthemEventType::NoteOn,
            .noteOn = AnthemNoteOnEvent(
              static_cast<int16_t>(note->key()),
              static_cast<int16_t>(0),
              static_cast<float>(note->velocity()),
              0.f,
              static_cast<int32_t>(-1)
            )
          }
        });
      }
    }
  }
}
