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

#include "sequence_note_provider.h"

#include "modules/core/anthem.h"
#include "modules/sequencer/runtime/runtime_sequence_store.h"

#include <optional>

SequenceNoteProviderProcessor::SequenceNoteProviderProcessor(
  const SequenceNoteProviderProcessorModelImpl& _impl
) : AnthemProcessor("SequenceNoteProvider"), SequenceNoteProviderProcessorModelBase(_impl) {
  rt_nextIndexToRead = 0;
}

SequenceNoteProviderProcessor::~SequenceNoteProviderProcessor() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::addEventsForJump(std::unique_ptr<AnthemEventBuffer>& targetBuffer, PlayheadJumpEvent& event) {
  auto& trackId = this->trackId();

  auto& eventsForJump = event.eventsToPlayAtJump;
  if (eventsForJump.find(trackId) != eventsForJump.end()) {
    auto& events = eventsForJump.at(trackId);
    for (auto& jumpEvent : events) {
      targetBuffer->addEvent(jumpEvent);
    }
  }
}

void SequenceNoteProviderProcessor::prepareToProcess() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& outputEventBuffer = context.getOutputEventBuffer(
    SequenceNoteProviderProcessorModelBase::eventOutputPortId
  );

  auto& trackId = this->trackId();

  auto& transport = Anthem::getInstance().transport;
  auto* config = transport->rt_config;

  // If the transport jumped for any reason, we need to send a stop event to the
  // downstream device.
  if (transport->rt_playheadJumpOrPauseOccurred) {
    AnthemLiveEvent liveEvent {};
    liveEvent.time = 0;
    liveEvent.event.type = AnthemEventType::AllVoicesOff;

    outputEventBuffer->addEvent(liveEvent);
  }

  if (transport->rt_playheadJumpEvent != nullptr) {
    addEventsForJump(outputEventBuffer, *transport->rt_playheadJumpEvent);
  }

  if (!config->isPlaying) {
    return;
  }

  auto& sequenceStore = *Anthem::getInstance().sequenceStore;
  auto activeSequenceId = config->activeSequenceId;

  // If the active sequence is not set, we don't need to do anything.
  if (!activeSequenceId) {
    return;
  }

  auto& sequenceMap = sequenceStore.rt_getEventLists();
  if (sequenceMap.find(*activeSequenceId) == sequenceMap.end()) {
    return;
  }

  auto& eventsForSequence = sequenceMap.at(*activeSequenceId);

  const std::string* sourceTrackId = &trackId;
  if (config->activeTrackId.has_value() && config->activeTrackId.value() == trackId) {
    auto noTrackEventListIter =
      eventsForSequence.tracks->find(anthem_sequencer_track_ids::noTrack);
    if (noTrackEventListIter != eventsForSequence.tracks->end()) {
      sourceTrackId = &anthem_sequencer_track_ids::noTrack;
    }
  }

  auto sourceTrackEventListIter = eventsForSequence.tracks->find(*sourceTrackId);
  if (sourceTrackEventListIter == eventsForSequence.tracks->end()) {
    return;
  }

  auto& channelEvents = sourceTrackEventListIter->second;

  double playheadPos = transport->rt_playhead;

  // If there are invalidation ranges and the playhead is within one of the
  // ranges, we need to send a note stop event
  if (channelEvents.invalidationOccurred) {
    // Send a note off event for all notes in this channel
    AnthemLiveEvent liveEvent{};
    liveEvent.time = 0;
    liveEvent.event.type = AnthemEventType::AllVoicesOff;
    outputEventBuffer->addEvent(liveEvent);
  }

  double ticks = transport->rt_getPlayheadAdvanceAmount(numSamples);

  double incrementRemaining = ticks;
  double loopStart = config->loopStart;
  double loopEnd = config->loopEnd; // This will be infinite if no loop is set

  while (incrementRemaining > 0.0) {
    double incrementAmount = incrementRemaining;
    bool didJump = false;

    double start = playheadPos; // Inclusive
    double end = -1; // Not inclusive

    if (playheadPos + incrementAmount >= loopEnd) {
      // If the increment would take us past the loop end, we need to
      // calculate how much of the increment we can actually apply.
      incrementAmount = loopEnd - playheadPos;
      incrementRemaining -= incrementAmount;
      playheadPos = loopStart;
      end = loopEnd;
      didJump = true;
    }
    else {
      playheadPos += incrementAmount;
      end = playheadPos;
      incrementRemaining = 0.0;
    }

    // This might happen if a loop is created a long ways before the playhead
    // and the playhead has to jump back
    if (incrementAmount < 0) {
      incrementAmount = 0;
    }

    for (auto& event : *channelEvents.events) {
      if (event.offset >= start && event.offset < end) {
        AnthemLiveEvent liveEvent{};
        liveEvent.time = event.offset - start;
        liveEvent.event = event.event;

        outputEventBuffer->addEvent(liveEvent);
      }

      if (event.offset >= end) {
        break;
      }
    }

    if (didJump) {
      // Stop all sound
      AnthemLiveEvent liveEvent{};
      liveEvent.time = 0;
      liveEvent.event.type = AnthemEventType::AllVoicesOff;

      outputEventBuffer->addEvent(liveEvent);

      // Then play the events for loop start
      if (config->playheadJumpEventForLoop.has_value()) {
        addEventsForJump(outputEventBuffer, config->playheadJumpEventForLoop.value());
      }
    }
  }
}
