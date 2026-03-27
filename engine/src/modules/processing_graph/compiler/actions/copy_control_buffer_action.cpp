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

#include "copy_control_buffer_action.h"

void CopyControlBufferAction::execute(int numSamples) {
  auto& sourceBuffer = source->getOutputControlBuffer(sourcePortId);
  auto& destinationBuffer = destination->getInputControlBuffer(destinationPortId);

  // Ensure the buffers have the same number of channels and the same size
  jassert(sourceBuffer.getNumChannels() == destinationBuffer.getNumChannels());
  jassert(sourceBuffer.getNumSamples() == destinationBuffer.getNumSamples());

  for (int channel = 0; channel < sourceBuffer.getNumChannels(); ++channel) {
    for (int sample = 0; sample < numSamples; ++sample) {
      float sourceSample = sourceBuffer.getSample(channel, sample);

      // Overwrite the destination, unless the source is NaN
      if (!std::isnan(sourceSample)) {
        jassert(sourceSample >= 0.0f && sourceSample <= 1.0f);
        destinationBuffer.setSample(channel, sample, sourceSample);
      }
    }
  }
}

void CopyControlBufferAction::debugPrint() {
  std::cout 
    << "CopyControlBufferAction: "
    << this->source->getGraphNode()->id()
    << " -> "
    << this->destination->getGraphNode()->id()
    << std::endl;
}

