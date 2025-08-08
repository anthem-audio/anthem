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

#include "live_event_provider.h"

LiveEventProviderProcessor::LiveEventProviderProcessor(
  const LiveEventProviderProcessorModelImpl& _impl
) : AnthemProcessor("LiveEventProvider"), LiveEventProviderProcessorModelBase(_impl) {
  liveEventBuffer = std::make_unique<RingBuffer<AnthemLiveEvent, 4096>>();
}

LiveEventProviderProcessor::~LiveEventProviderProcessor() {
  // Nothing to do here
}

void LiveEventProviderProcessor::addLiveEventsToBuffer(std::unique_ptr<AnthemEventBuffer>& targetBuffer) {
  while (true) {
    auto eventOpt = liveEventBuffer->read();
    if (!eventOpt.has_value()) {
      return;
    }

    auto event = eventOpt.value();
    targetBuffer->addEvent(std::move(event));
  }
}

void LiveEventProviderProcessor::addLiveEvent(AnthemLiveEvent event) {
  liveEventBuffer->add(std::move(event));
}

void LiveEventProviderProcessor::prepareToProcess() {}

void LiveEventProviderProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& outputEventBuffer = context.getOutputEventBuffer(
    LiveEventProviderProcessorModelBase::eventOutputPortId
  );

  addLiveEventsToBuffer(outputEventBuffer);
}
