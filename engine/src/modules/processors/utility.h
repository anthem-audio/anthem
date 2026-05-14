/*
  Copyright (C) 2026 Joshua Wade

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

#include "generated/lib/model/processing_graph/processors/utility.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/processors/gain_parameter_mapping.h"

// Applies track utility controls to the input audio signal.
namespace anthem {

class UtilityProcessor : public Processor, public UtilityProcessorModelBase {
private:
  // Converts an incoming [0.0, 1.0] parameter value to a linear gain value.
  //
  // In the header to allow inlining.
  float paramValueToGainLinear(float paramValue) {
    return gainParameterValueToLinear(paramValue);
  }
public:
  UtilityProcessor(const UtilityProcessorModelImpl& _impl);
  ~UtilityProcessor() override;

  UtilityProcessor(const UtilityProcessor&) = delete;
  UtilityProcessor& operator=(const UtilityProcessor&) = delete;

  UtilityProcessor(UtilityProcessor&&) noexcept = default;
  UtilityProcessor& operator=(UtilityProcessor&&) noexcept = default;

  void prepareToProcess(ProcessorPrepareCallback complete) override;
  void process(NodeProcessContext& context, int numSamples) override;
};

} // namespace anthem
