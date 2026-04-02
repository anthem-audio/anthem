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

#include "write_parameters_to_control_inputs_action.h"

#include "modules/processing_graph/model/node.h"

void WriteParametersToControlInputsAction::execute(int numSamples) {
  for (auto& parameter : processContext->rt_getInputParameterBindings()) {
    auto value = parameter.value->load();
    jassert(value >= 0.0f && value <= 1.0f);

    if (parameter.rt_smoother->getTargetValue() != value) {
      parameter.rt_smoother->setTargetValue(value);
    }

    auto& controlBuffer = *parameter.rt_buffer;
    for (int sample = 0; sample < numSamples; sample++) {
      parameter.rt_smoother->process(1.0f / sampleRate);
      auto currentValue = parameter.rt_smoother->getCurrentValue();
      jassert(currentValue >= 0.0f && currentValue <= 1.0f);
      controlBuffer.setSample(0, sample, currentValue);
    }
  }
}

void WriteParametersToControlInputsAction::debugPrint() {
  std::cout << "WriteParametersToControlInputsAction: " << processContext->getGraphNode()->id()
            << '\n';
}
