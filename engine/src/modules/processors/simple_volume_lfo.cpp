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

#include "simple_volume_lfo.h"

#include "modules/processing_graph/compiler/anthem_process_context.h"

SimpleVolumeLfoProcessor::SimpleVolumeLfoProcessor(const SimpleVolumeLfoProcessorModelImpl& _impl)
  : AnthemProcessor("SimpleVolumeLfo"), SimpleVolumeLfoProcessorModelBase(_impl) {
  rate = 0.0001f;
  amplitude = 1;

  // // Audio input port
  // config.addAudioInput(
  //   std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  // );

  // // Audio output port
  // config.addAudioOutput(
  //   std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  // );
}

SimpleVolumeLfoProcessor::~SimpleVolumeLfoProcessor() {}

void SimpleVolumeLfoProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& inputBuffer = context.getInputAudioBuffer(SimpleVolumeLfoProcessorModelBase::audioInputPortId);
  auto& outputBuffer = context.getOutputAudioBuffer(SimpleVolumeLfoProcessorModelBase::audioOutputPortId);

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

