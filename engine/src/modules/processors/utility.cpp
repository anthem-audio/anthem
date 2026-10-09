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

#include "utility.h"

#include "modules/processing_graph/runtime/node_process_context.h"

#include <juce_core/juce_core.h>
#include <utility>

namespace anthem {

UtilityProcessor::UtilityProcessor(const UtilityProcessorModelImpl& _impl)
  : Processor("Utility"), UtilityProcessorModelBase(_impl) {}

UtilityProcessor::~UtilityProcessor() {}

void UtilityProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  ProcessorNodePortConfiguration ports{
      .audioInputPorts =
          {
              ProcessorPortConfiguration{
                  .id = audioInputPortId,
                  .channelCount = 2,
              },
          },
      .audioOutputPorts =
          {
              ProcessorPortConfiguration{
                  .id = audioOutputPortId,
                  .channelCount = 2,
              },
          },
      .controlInputPorts =
          {
              ProcessorPortConfiguration{
                  .id = gainPortId,
                  .parameterDefaultValue = kGainParameterZeroDbNormalized,
                  .parameterDisplayMode = "gainDb",
                  .parameterUnitLabel = "dB",
              },
              ProcessorPortConfiguration{
                  .id = balancePortId,
                  .parameterDefaultValue = 0.5,
                  .parameterDisplayMode = "pan",
              },
          },
  };
  complete(ProcessorPrepareResult{.portConfiguration = std::move(ports)});
}

void UtilityProcessor::process(NodeProcessContext& context, int numSamples) {
  auto audioInBuffer = context.getInputAudioBuffer(UtilityProcessor::audioInputPortId);
  auto audioOutBuffer = context.getOutputAudioBuffer(UtilityProcessor::audioOutputPortId);

  auto gainControl = context.getInputControlSignal(UtilityProcessor::gainPortId);
  auto balanceControl = context.getInputControlSignal(UtilityProcessor::balancePortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto gainParamValue = gainControl.getSample(sample);
    auto targetGain = paramValueToGainLinear(gainParamValue);

    auto balanceParamValue = balanceControl.getSample(sample);
    jassert(juce::jlimit(0.0f, 1.0f, balanceParamValue) == balanceParamValue);

    auto pan = balanceParamValue * 2.0f - 1.0f;
    auto gainR = juce::jmin(1.0f - pan, 1.0f);
    auto gainL = juce::jmin(1.0f + pan, 1.0f);

    float gains[2] = {gainR * targetGain, gainL * targetGain};

    jassert(audioOutBuffer.getNumChannels() >= 2);

    for (int channel = 0; channel < 2; ++channel) {
      auto inputSample = audioInBuffer.getReadPointer(channel)[sample];

      audioOutBuffer.getWritePointer(channel)[sample] = inputSample * gains[channel];
    }
  }
}

} // namespace anthem
