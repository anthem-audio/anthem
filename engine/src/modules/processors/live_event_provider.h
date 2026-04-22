/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "generated/lib/model/processing_graph/processors/live_event_provider.h"
#include "modules/processing_graph/processor/event_buffer.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/processors/note_tracker.h"
#include "modules/sequencer/events/event.h"
#include "modules/util/ring_buffer.h"

#include <memory>

namespace anthem {

class NodeProcessContext;

struct LiveInputEvent {
  double sampleOffset = 0.0;
  LiveInputNoteId inputId = invalidLiveInputNoteId;
  Event event;
};

class LiveEventProviderProcessor : public Processor, public LiveEventProviderProcessorModelBase {
private:
  static constexpr size_t rt_maxTrackedLiveNotes = 1024;

  std::unique_ptr<RingBuffer<LiveInputEvent, 4096>> liveInputEventBuffer;
  NoteTracker<rt_maxTrackedLiveNotes> rt_activeLiveNotes;

  void rt_emitLiveNoteOffFromTrackedNote(std::unique_ptr<EventBuffer>& targetBuffer,
      const TrackedNote& trackedNote,
      double sampleOffset);
  void rt_handleLiveNoteOn(NodeProcessContext& context,
      std::unique_ptr<EventBuffer>& targetBuffer,
      LiveInputNoteId inputId,
      const NoteOnEvent& noteOnEvent,
      double sampleOffset);
  void rt_handleLiveNoteOff(std::unique_ptr<EventBuffer>& targetBuffer,
      LiveInputNoteId inputId,
      const NoteOffEvent& noteOffEvent,
      double sampleOffset);
  void rt_addLiveEventsToBuffer(
      NodeProcessContext& context, std::unique_ptr<EventBuffer>& targetBuffer);
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
  void process(NodeProcessContext& context, int numSamples) override;

  void addLiveInputEvent(LiveInputEvent event);
};

} // namespace anthem
