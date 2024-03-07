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

#include "simple_volume_lfo_node.h"

#include "anthem_process_context.h"

SimpleVolumeLfoNode::SimpleVolumeLfoNode() : AnthemProcessor("SimpleVolumeLfoNode") {
  rate = 0.0001;
  amplitude = 1;

  config.addAudioInput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, "input")
  );
  config.addAudioOutput(
    std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, "output")
  );
}

SimpleVolumeLfoNode::~SimpleVolumeLfoNode() {}

void SimpleVolumeLfoNode::process(AnthemProcessContext& context, int numSamples) {
  auto& inputBuffer = context.getInputAudioBuffer(0);
  auto& outputBuffer = context.getOutputAudioBuffer(0);

  // Generate a sine wave
  for (int sample = 0; sample < numSamples; ++sample) {
    for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel) {
      const float inputValue = inputBuffer.getSample(channel, sample);
      outputBuffer.getWritePointer(channel)[sample] = inputValue * amplitude;
    }

    if (increasing) {
      amplitude += rate;
    } else {
      amplitude -= rate;
    }

    if (amplitude >= 1) {
      increasing = false;
    } else if (amplitude <= 0) {
      increasing = true;
    }
  }
}

