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
    : AnthemProcessor("Gain"), GainProcessorModelBase(_impl) {}

GainProcessor::~GainProcessor() {}

void GainProcessor::prepareToProcess() {}

void GainProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& audioInBuffer = context.getInputAudioBuffer(GainProcessorModelBase::audioInputPortId);
  auto& audioOutBuffer = context.getOutputAudioBuffer(GainProcessorModelBase::audioOutputPortId);

  auto& amplitudeControlBuffer = context.getInputControlBuffer(GainProcessorModelBase::gainPortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto paramValue = amplitudeControlBuffer.getReadPointer(0)[sample];
    float targetGain = paramValueToGainLinear(paramValue);

    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      auto inputSample = audioInBuffer.getReadPointer(channel)[sample];
      auto outputSample = inputSample * targetGain;

      audioOutBuffer.getWritePointer(channel)[sample] = outputSample;
    }
  }
}
