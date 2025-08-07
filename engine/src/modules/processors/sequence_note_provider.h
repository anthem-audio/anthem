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
#include "modules/sequencer/runtime/transport.h"
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/processing_graph/compiler/anthem_process_context.h"

// This processor is a bridge between the sequencer and the node graph. It's a
// special node that the sequencer can use to send notes from the sequence to the
// node graph as note events.
class SequenceNoteProviderProcessor : public AnthemProcessor, public SequenceNoteProviderProcessorModelBase {
private:
  uint64_t rt_nextIndexToRead;

  void addEventsForJump(std::unique_ptr<AnthemEventBuffer>& targetBuffer, PlayheadJumpEvent& event);
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
  void process(AnthemProcessContext& context, int numSamples) override;
};
