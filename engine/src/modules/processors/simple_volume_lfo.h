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

#include "generated/lib/model/processing_graph/processors/simple_volume_lfo.h"
#include "modules/processing_graph/processor/processor.h"

namespace anthem {

class SimpleVolumeLfoProcessor : public Processor, public SimpleVolumeLfoProcessorModelBase {
private:
  friend class SimpleVolumeLfoTest;

  struct RuntimeState {
    float rt_amplitude = 1.0f;
    bool rt_increasing = false;
  };

  float rt_rate = 0.0001f;
  RuntimeState rt_state;

  static void rt_advanceState(RuntimeState& state, float rt_rate);
public:
  SimpleVolumeLfoProcessor(const SimpleVolumeLfoProcessorModelImpl& _impl);
  ~SimpleVolumeLfoProcessor() override;

  SimpleVolumeLfoProcessor(const SimpleVolumeLfoProcessor&) = delete;
  SimpleVolumeLfoProcessor& operator=(const SimpleVolumeLfoProcessor&) = delete;

  SimpleVolumeLfoProcessor(SimpleVolumeLfoProcessor&&) noexcept = default;
  SimpleVolumeLfoProcessor& operator=(SimpleVolumeLfoProcessor&&) noexcept = default;

  std::optional<std::string> prepareToProcess() override;
  void process(NodeProcessContext& context, int numSamples) override;
};

} // namespace anthem
