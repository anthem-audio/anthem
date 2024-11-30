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

#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processing_graph/topology/anthem_graph_node_port.h"

class ToneGeneratorProcessor : public AnthemProcessor, public ToneGeneratorProcessorModelBase {
private:
  double phase;
  double sampleRate;

  bool hasNoteOverride;
  int noteOverride;
public:
  ToneGeneratorProcessor(const ToneGeneratorProcessorModelImpl& _impl);
  ~ToneGeneratorProcessor() override;

  ToneGeneratorProcessor(const ToneGeneratorProcessor&) = delete;
  ToneGeneratorProcessor& operator=(const ToneGeneratorProcessor&) = delete;

  ToneGeneratorProcessor(ToneGeneratorProcessor&&) noexcept = default;
  ToneGeneratorProcessor& operator=(ToneGeneratorProcessor&&) noexcept = default;

  int getOutputPortIndex() {
    return 0;
  }

  void process(AnthemProcessContext& context, int numSamples) override;

  void initialize(std::shared_ptr<AnthemModelBase> self, std::shared_ptr<AnthemModelBase> parent) override {
    ToneGeneratorProcessorModelBase::initialize(self, parent);

    AnthemProcessor::assignProcessorToNode(
      this->nodeId(),
      std::static_pointer_cast<AnthemProcessor>(
        std::static_pointer_cast<ToneGeneratorProcessor>(self)
      )
    );
  }
};
