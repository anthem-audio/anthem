/*
  Copyright (C) 2024 Joshua Wade

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

#include <juce_audio_basics/juce_audio_basics.h>

#include "modules/core/constants.h"
#include "modules/processing_graph/processor/anthem_processor.h"

#include "generated/lib/model/processing_graph/processors/master_output.h"

class MasterOutputProcessor : public AnthemProcessor, public MasterOutputProcessorModelBase {
public:
  juce::AudioSampleBuffer buffer;

  MasterOutputProcessor(const MasterOutputProcessorModelImpl& _impl);
  ~MasterOutputProcessor() override;

  MasterOutputProcessor(const MasterOutputProcessor&) = delete;
  MasterOutputProcessor& operator=(const MasterOutputProcessor&) = delete;

  MasterOutputProcessor(MasterOutputProcessor&&) noexcept = default;
  MasterOutputProcessor& operator=(MasterOutputProcessor&&) noexcept = default;

  int getInputPortIndex() {
    return 0;
  }

  void process(AnthemProcessContext& context, int numSamples) override;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    MasterOutputProcessorModelBase::initialize(self, parent);

    AnthemProcessor::assignProcessorToNode(
      this->nodeId(),
      std::static_pointer_cast<AnthemProcessor>(
        std::static_pointer_cast<MasterOutputProcessor>(self)
      )
    );
  }
};
