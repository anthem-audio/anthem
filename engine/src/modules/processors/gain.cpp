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

#include "gain.h"

#include "modules/processing_graph/compiler/anthem_process_context.h"

GainProcessor::GainProcessor(const GainProcessorModelImpl& _impl)
    : AnthemProcessor("Gain"), GainProcessorModelBase(_impl) {
  // // Audio input port
  // config.addAudioInput(
  //   std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  // );

  // // Audio output port
  // config.addAudioOutput(
  //   std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Audio, 0)
  // );

  // // Control ports
  
  // // Amplitude
  // config.addControlInput(
  //   std::make_shared<AnthemProcessorPortConfig>(AnthemGraphDataType::Control, 0),
  //   std::make_shared<AnthemProcessorParameterConfig>(0ul, 1.0f, 0.0f, 10.0f)
  // );
}

GainProcessor::~GainProcessor() {}

void GainProcessor::prepareToProcess() {}

void GainProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& audioInBuffer = context.getInputAudioBuffer(GainProcessorModelBase::audioInputPortId);
  auto& audioOutBuffer = context.getOutputAudioBuffer(GainProcessorModelBase::audioOutputPortId);

  auto& amplitudeControlBuffer = context.getInputControlBuffer(GainProcessorModelBase::gainPortId);

  for (int sample = 0; sample < numSamples; sample++) {
    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      auto inputSample = audioInBuffer.getReadPointer(channel)[sample];
      auto amplitudeSample = amplitudeControlBuffer.getReadPointer(0)[sample];

      audioOutBuffer.getWritePointer(channel)[sample] = inputSample * amplitudeSample;
    }
  }
}
