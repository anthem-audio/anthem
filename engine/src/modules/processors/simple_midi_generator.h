/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

#include "generated/lib/model/processing_graph/processors/simple_midi_generator.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/sequencer/events/note_events.h"
#include "modules/sequencer/events/note_instance_id.h"

class SimpleMidiGeneratorProcessor : public AnthemProcessor,
                                     public SimpleMidiGeneratorProcessorModelBase {
private:
  double sampleRate;
  size_t durationSamples;
  int velocity;
  bool noteOn;

  int16_t currentNote;
  AnthemLiveNoteId currentNoteId;
  size_t currentNoteDuration;
public:
  SimpleMidiGeneratorProcessor(const SimpleMidiGeneratorProcessorModelImpl& _impl);
  ~SimpleMidiGeneratorProcessor() override;

  SimpleMidiGeneratorProcessor(const SimpleMidiGeneratorProcessor&) = delete;
  SimpleMidiGeneratorProcessor& operator=(const SimpleMidiGeneratorProcessor&) = delete;

  SimpleMidiGeneratorProcessor(SimpleMidiGeneratorProcessor&&) noexcept = default;
  SimpleMidiGeneratorProcessor& operator=(SimpleMidiGeneratorProcessor&&) noexcept = default;

  int getOutputPortIndex() {
    return 0;
  }

  void prepareToProcess() override;
  void process(AnthemNodeProcessContext& context, int numSamples) override;
};
