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

#include "generated/lib/model/model.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/sequencer/events/event.h"
#include "modules/util/ring_buffer.h"

#include <memory>

class LiveEventProviderProcessor : public AnthemProcessor, public LiveEventProviderProcessorModelBase {
private:
  std::unique_ptr<RingBuffer<AnthemLiveEvent, 4096>> liveEventBuffer;

  void addLiveEventsToBuffer(std::unique_ptr<AnthemEventBuffer>& targetBuffer);
public:
  LiveEventProviderProcessor(const LiveEventProviderProcessorModelImpl& _impl);
  ~LiveEventProviderProcessor() override;

  LiveEventProviderProcessor(const LiveEventProviderProcessor&) = delete;
  LiveEventProviderProcessor& operator=(const LiveEventProviderProcessor&) = delete;

  LiveEventProviderProcessor(LiveEventProviderProcessor&&) noexcept = default;
  LiveEventProviderProcessor& operator=(LiveEventProviderProcessor&&) noexcept = default;

  int getOutputPortIndex() {
    return 0;
  }

  void prepareToProcess() override;
  void process(AnthemProcessContext& context, int numSamples) override;

  // Adds a live event to be picked up by this processor and sent to the
  // downstream node(s).
  void addLiveEvent(AnthemLiveEvent event);
};
