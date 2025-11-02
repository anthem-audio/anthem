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

#include "bw_math.h"

// Applies gain to the input audio signal.
class GainProcessor : public AnthemProcessor, public GainProcessorModelBase {
private:
  // Converts an incoming [0.0, 1.0] parameter value to a linear gain value.
  //
  // In the header to allow inlining.
  float paramValueToGainLinear(float paramValue) {
    // Below 0.05, map linearly from 0 to -40dB
    if (paramValue <= 0.05f) {
      float neg40db = bw_dB2linf(-40.f);
      return (paramValue / 0.05f) * neg40db;
    }

    // Above 0.05, map exponentially from -40dB to 0dB
    float scaledValue = (paramValue - 0.05f) / 0.95f; // Scale to [0, 1]
    float gainDB = scaledValue * 40.f - 40.f;         // Map to [-40, 0] dB
    return bw_dB2linf(gainDB);
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
