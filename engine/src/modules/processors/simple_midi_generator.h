/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

class SimpleMidiGeneratorProcessor : public AnthemProcessor, public SimpleMidiGeneratorProcessorModelBase {
private:
  double sampleRate;
  size_t durationSamples;
  int velocity;
  bool noteOn;

  int16_t currentNote;
  int32_t currentNoteId;
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

  void process(AnthemProcessContext& context, int numSamples) override;
};
