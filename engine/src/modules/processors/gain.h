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

#include "generated/lib/model/model.h"
#include "modules/processing_graph/processor/anthem_processor.h"
#include "modules/processors/gain_parameter_mapping.h"

// Applies gain to the input audio signal.
class GainProcessor : public AnthemProcessor, public GainProcessorModelBase {
private:
  // Converts an incoming [0.0, 1.0] parameter value to a linear gain value.
  //
  // In the header to allow inlining.
  float paramValueToGainLinear(float paramValue) {
    return gainParameterValueToLinear(paramValue);
  }
public:
  GainProcessor(const GainProcessorModelImpl& _impl);
  ~GainProcessor() override;

  GainProcessor(const GainProcessor&) = delete;
  GainProcessor& operator=(const GainProcessor&) = delete;

  GainProcessor(GainProcessor&&) noexcept = default;
  GainProcessor& operator=(GainProcessor&&) noexcept = default;

  void prepareToProcess() override;
  void process(AnthemProcessContext& context, int numSamples) override;
};
