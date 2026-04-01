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

#include "generated/lib/model/processing_graph/processors/sequence_note_provider.h"
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processors/note_tracker.h"
#include "modules/sequencer/events/event.h"

class AnthemNodeProcessContext;
class PlayheadJumpEvent;

// This processor is a bridge between the sequencer and the node graph. It's a
// special node that the sequencer can use to send notes from the sequence to the
// node graph as note events.
//
// If this node's track ID matches the transport's active track ID, the node may
// read from the reserved track-less sequence event list instead of the
// per-track list.
class SequenceNoteProviderProcessor : public AnthemProcessor,
                                      public SequenceNoteProviderProcessorModelBase {
private:
  static constexpr size_t rt_maxTrackedSequenceNotes = 256;

  NoteTracker<rt_maxTrackedSequenceNotes> rt_activeSequenceNotes;

  void rt_emitLiveNoteOffFromTrackedNote(std::unique_ptr<AnthemEventBuffer>& targetBuffer,
                                         const TrackedNote& trackedNote,
                                         double sampleOffset);
  void rt_emitLiveNoteOffsForAllTrackedNotes(std::unique_ptr<AnthemEventBuffer>& targetBuffer,
                                             double sampleOffset);
  void rt_handleSequenceNoteOn(AnthemNodeProcessContext& context,
                               std::unique_ptr<AnthemEventBuffer>& targetBuffer,
                               AnthemSourceNoteId sourceId,
                               const AnthemNoteOnEvent& noteOnEvent,
                               double sampleOffset);
  void rt_handleSequenceNoteOff(std::unique_ptr<AnthemEventBuffer>& targetBuffer,
                                AnthemSourceNoteId sourceId,
                                const AnthemNoteOffEvent& noteOffEvent,
                                double sampleOffset);
  void rt_addEventsForJump(AnthemNodeProcessContext& context,
                           std::unique_ptr<AnthemEventBuffer>& targetBuffer,
                           const PlayheadJumpEvent& event,
                           double sampleTimeOffset = 0.0);
public:
  SequenceNoteProviderProcessor(const SequenceNoteProviderProcessorModelImpl& _impl);
  ~SequenceNoteProviderProcessor() override;

  SequenceNoteProviderProcessor(const SequenceNoteProviderProcessor&) = delete;
  SequenceNoteProviderProcessor& operator=(const SequenceNoteProviderProcessor&) = delete;

  SequenceNoteProviderProcessor(SequenceNoteProviderProcessor&&) noexcept = default;
  SequenceNoteProviderProcessor& operator=(SequenceNoteProviderProcessor&&) noexcept = default;

  int getOutputPortIndex() {
    return 0;
  }

  void prepareToProcess() override;
  void process(AnthemNodeProcessContext& context, int numSamples) override;
};
