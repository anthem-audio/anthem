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

#include <memory>

#include "generated/lib/model/processing_graph/processors/live_event_provider.h"
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processors/note_tracker.h"
#include "modules/sequencer/events/event.h"
#include "modules/util/ring_buffer.h"

class AnthemNodeProcessContext;

struct AnthemLiveInputEvent {
  double sampleOffset = 0.0;
  AnthemLiveInputNoteId inputId = anthemInvalidLiveInputNoteId;
  AnthemEvent event;
};

class LiveEventProviderProcessor
  : public AnthemProcessor,
    public LiveEventProviderProcessorModelBase {
private:
  static constexpr size_t rt_maxTrackedLiveNotes = 1024;

  std::unique_ptr<RingBuffer<AnthemLiveInputEvent, 4096>> liveInputEventBuffer;
  NoteTracker<rt_maxTrackedLiveNotes> rt_activeLiveNotes;

  void rt_emitLiveNoteOffFromTrackedNote(
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    const TrackedNote& trackedNote,
    double sampleOffset
  );
  void rt_handleLiveNoteOn(
    AnthemNodeProcessContext& context,
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    AnthemLiveInputNoteId inputId,
    const AnthemNoteOnEvent& noteOnEvent,
    double sampleOffset
  );
  void rt_handleLiveNoteOff(
    std::unique_ptr<AnthemEventBuffer>& targetBuffer,
    AnthemLiveInputNoteId inputId,
    const AnthemNoteOffEvent& noteOffEvent,
    double sampleOffset
  );
  void rt_addLiveEventsToBuffer(
    AnthemNodeProcessContext& context,
    std::unique_ptr<AnthemEventBuffer>& targetBuffer
  );

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
  void process(AnthemNodeProcessContext& context, int numSamples) override;

  void addLiveInputEvent(AnthemLiveInputEvent event);
};
