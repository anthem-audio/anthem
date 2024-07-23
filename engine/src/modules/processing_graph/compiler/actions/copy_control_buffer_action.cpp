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

#include "copy_control_buffer_action.h"

void CopyControlBufferAction::execute(int numSamples) {
  auto& sourceBuffer = source->getOutputControlBuffer(sourcePort);
  auto& destinationBuffer = destination->getInputControlBuffer(destinationPort);
  auto& destinationParameter = destination->getGraphNode()->processor->config.getParameterByIndex(destinationPort);

  // Ensure the buffers have the same number of channels and the same size
  jassert(sourceBuffer.getNumChannels() == destinationBuffer.getNumChannels());
  jassert(sourceBuffer.getNumSamples() == destinationBuffer.getNumSamples());

  for (int channel = 0; channel < sourceBuffer.getNumChannels(); ++channel) {
    for (int sample = 0; sample < numSamples; ++sample) {
      float sourceSample = sourceBuffer.getSample(channel, sample);

      // Overwrite the destination, unless the source is NaN
      if (!std::isnan(sourceSample)) {
        // Scale the incoming value based on the min/max values defined by the
        // parameter definition
        auto max = destinationParameter->maxValue;
        auto min = destinationParameter->minValue;
        auto scaledSample = sourceSample * (max - min) + min;

        destinationBuffer.setSample(channel, sample, scaledSample);
      }
    }
  }
}

void CopyControlBufferAction::debugPrint() {
  std::cout 
    << "CopyControlBufferAction: "
    << this->source->getGraphNode()->processor->config.getId()
    << " -> "
    << this->destination->getGraphNode()->processor->config.getId()
    << std::endl;
}

