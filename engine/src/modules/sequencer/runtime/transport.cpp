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
  config.loopStart = 0.0;
  config.loopEnd = std::numeric_limits<double>::infinity();

  // Initialize the transport with default values
  configBufferedValue.set(config);

  rt_playheadJumpEvent = nullptr;
  rt_playheadJumpEventForSeek = nullptr;
  rt_playheadJumpEventForStart = nullptr;

  // Start the cleanup loop, which will clean up memory sent back from the audio
  // thread
  this->startTimer(100);
}

void Transport::prepareToProcess() {
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);
  sampleRate = currentDevice->getCurrentSampleRate();
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
  if (newConfig.playheadJumpEventForStart != rt_config.playheadJumpEventForStart &&
      rt_config.playheadJumpEventForStart != nullptr) {
    playheadJumpEventDeleteBuffer.add(rt_config.playheadJumpEventForStart);
  }

  // Check for change to loop jump event list, and clean up the old one if necessary
  if (newConfig.playheadJumpEventForLoop != rt_config.playheadJumpEventForLoop &&
      rt_config.playheadJumpEventForLoop != nullptr) {
    playheadJumpEventDeleteBuffer.add(rt_config.playheadJumpEventForLoop);
  }

  // Update the real-time transport state
  rt_config = newConfig;

  // Check if there are any playhead jump events to process
  while (auto event = playheadJumpEventBuffer.read()) {
    if (rt_playheadJumpEventForSeek != nullptr) {
      playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    }
    rt_playheadJumpEventForSeek = event.value();
  }

  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playhead = rt_playheadJumpEventForSeek->newPlayheadPosition;
    rt_playheadJumpOrPauseOccurred = true;
  }

  // If we're not playing, then we do not want downstream consumers to pick up
  // any sequencer events that this object might have contained
  if (!rt_config.isPlaying) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    rt_playheadJumpEventForSeek = nullptr;
  }

  // Set the public-facing playhead jump event pointer
  if (rt_playheadJumpEventForSeek != nullptr) {
    rt_playheadJumpEvent = rt_playheadJumpEventForSeek;
  }
  else if (rt_playheadJumpEventForStart != nullptr) {
    // If there is no seek event, but there is a start event, then we use that
    // as the playhead jump event
    rt_playheadJumpEvent = rt_playheadJumpEventForStart;
  }
  else {
    // Otherwise, we have no playhead jump event for this processing block
    rt_playheadJumpEvent = nullptr;
  }
}

void Transport::rt_advancePlayhead(int numSamples) {
  rt_playhead = rt_getPlayheadAfterAdvance(numSamples);
  rt_playheadJumpOrPauseOccurred = false;

  // Send the playhead jump event back to the main thread for deletion, if there
  // is one
  if (rt_playheadJumpEventForSeek != nullptr) {
    playheadJumpEventDeleteBuffer.add(rt_playheadJumpEventForSeek);
    rt_playheadJumpEventForSeek = nullptr;
  }

  rt_playheadJumpEventForStart = nullptr; // This is cleaned up elsewhere
}

double Transport::rt_getPlayheadAdvanceAmount(int numSamples) {
  if (!rt_config.isPlaying) {
    return 0.0;
  }
  auto ticksPerQuarter = rt_config.ticksPerQuarter;
  auto beatsPerMinute = rt_config.beatsPerMinute;
  auto ticksPerMinute = ticksPerQuarter * beatsPerMinute;
  auto ticksPerSecond = ticksPerMinute / 60.0;
  auto ticksPerSample = ticksPerSecond / sampleRate;
  return static_cast<double>(numSamples * ticksPerSample);
}

double Transport::rt_getPlayheadAfterAdvance(int numSamples) {
  if (rt_config.isPlaying) {
    auto ticks = rt_getPlayheadAdvanceAmount(numSamples);

    // Because we're using floating point math, the math operations here must
    // precisely mirror those in the event provider nodes. If not, then we might
    // drop or double-count events.
    double timePointer = rt_playhead;
    double incrementRemaining = ticks;
    double loopStart = rt_config.loopStart;
    double loopEnd = rt_config.loopEnd; // This will be infinite if no loop is set

    while (incrementRemaining > 0.0) {
      double incrementAmount = incrementRemaining;

      if (timePointer + incrementAmount >= loopEnd) {
        // If the increment would take us past the loop end, we need to
        // calculate how much of the increment we can actually apply.
        incrementAmount = loopEnd - timePointer;
        incrementRemaining -= incrementAmount;
        timePointer = loopStart;
      }
      else {
        timePointer += incrementAmount;
        incrementRemaining = 0.0;
      }
    }

    rt_playhead = timePointer;
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
  if (config.hasLoop && playheadPosition >= config.loopEnd) {
    double mod = std::fmod(playheadPosition - config.loopStart, config.loopEnd - config.loopStart);
    playheadPosition = config.loopStart + mod;
  }

  auto* event = createPlayheadJumpEvent(playheadPosition);

  playheadJumpEventBuffer.add(event);
}

void Transport::clearLoopPoints() {
  if (!config.hasLoop) {
    return;
  }

  config.hasLoop = false;
  config.loopStart = 0.0;
  config.loopEnd = std::numeric_limits<double>::infinity();

  // The audio thread will release this into the delete buffer when it picks up the new config
  config.playheadJumpEventForLoop = nullptr;
}

void Transport::updateLoopPoints(bool send) {
  if (!config.activeSequenceId.has_value()) {
    clearLoopPoints();

    if (send) {
      configBufferedValue.set(config);
    }

    return;
  }

  auto& patterns = *Anthem::getInstance().project->sequence()->patterns();
  auto& arrangements = *Anthem::getInstance().project->sequence()->arrangements();

  std::shared_ptr<LoopPointsModel> loopPoints;

  if (patterns.find(config.activeSequenceId.value()) != patterns.end() &&
      patterns.at(config.activeSequenceId.value())->loopPoints().has_value()) {
    loopPoints = patterns.at(config.activeSequenceId.value())->loopPoints().value();
  }
  else if (arrangements.find(config.activeSequenceId.value()) != arrangements.end() &&
      arrangements.at(config.activeSequenceId.value())->loopPoints().has_value()) {
    loopPoints = arrangements.at(config.activeSequenceId.value())->loopPoints().value();
  }
  else {
    clearLoopPoints();

    if (send) {
      configBufferedValue.set(config);
    }

    return;
  }

  config.hasLoop = true;
  config.loopStart = static_cast<double>(loopPoints->start());
  config.loopEnd = static_cast<double>(loopPoints->end());
  config.playheadJumpEventForLoop = createPlayheadJumpEvent(static_cast<double>(config.loopStart));

  configBufferedValue.set(config);
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
