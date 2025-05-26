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

SequenceNoteProviderProcessor::SequenceNoteProviderProcessor(
  const SequenceNoteProviderProcessorModelImpl& _impl
) : AnthemProcessor("SequenceNoteProvider"), SequenceNoteProviderProcessorModelBase(_impl) {
  rt_nextIndexToRead = 0;
}

SequenceNoteProviderProcessor::~SequenceNoteProviderProcessor() {
  // Nothing to do here
}

void SequenceNoteProviderProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& outputEventBuffer = context.getOutputEventBuffer(
    SequenceNoteProviderProcessorModelBase::eventOutputPortId
  );

  auto& channelId = this->channelId();

  auto& transport = Anthem::getInstance().transport;

  // If the transport jumped for any reason, we need to send a stop event to the
  // downstream device.
  if (transport->rt_playheadJumpOccurred) {
    AnthemLiveEvent liveEvent {};
    liveEvent.time = 0;
    liveEvent.event.type = AnthemEventType::AllVoicesOff;

    outputEventBuffer->addEvent(liveEvent);
  }

  auto start = transport->rt_playhead; // Inclusive
  auto end = transport->rt_getPlayheadAfterAdvance(numSamples); // Not inclusive

  // If the transport is not running, we don't need to do anything.
  if (start == end) {
    return;
  }

  auto& sequenceStore = *Anthem::getInstance().sequenceStore;
  auto activeSequenceId = transport->config.activeSequenceId;

  // If the active sequence is not set, we don't need to do anything.
  if (!activeSequenceId) {
    return;
  }

  auto& sequenceMap = sequenceStore.rt_getEventLists();
    if (sequenceMap.find(*activeSequenceId) == sequenceMap.end()) {
    return;
  }

  auto& eventsForSequence = sequenceMap.at(*activeSequenceId);
  if (eventsForSequence.channels->find(channelId) == eventsForSequence.channels->end()) {
    return;
  }

  auto& channelEvents = eventsForSequence.channels->at(channelId);
  for (auto& event : *channelEvents.events) {
    if (event.offset >= start && event.offset < end) {
      AnthemLiveEvent liveEvent {};
      liveEvent.time = event.offset - start;
      liveEvent.event = event.event;

      outputEventBuffer->addEvent(liveEvent);
    }

    if (event.offset >= end) {
      break;
    }
  }
}
