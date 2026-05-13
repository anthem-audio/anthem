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

namespace anthem {

UtilityProcessor::UtilityProcessor(const UtilityProcessorModelImpl& _impl)
  : Processor("Utility"), UtilityProcessorModelBase(_impl) {}

UtilityProcessor::~UtilityProcessor() {}

std::optional<std::string> UtilityProcessor::prepareToProcess() {
  return std::nullopt;
}

void UtilityProcessor::process(NodeProcessContext& context, int numSamples) {
  auto& audioInBuffer = context.getInputAudioBuffer(UtilityProcessorModelBase::audioInputPortId);
  auto& audioOutBuffer = context.getOutputAudioBuffer(UtilityProcessorModelBase::audioOutputPortId);

  auto& gainControlBuffer = context.getInputControlBuffer(UtilityProcessorModelBase::gainPortId);
  auto& balanceControlBuffer =
      context.getInputControlBuffer(UtilityProcessorModelBase::balancePortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto gainParamValue = gainControlBuffer.getReadPointer(0)[sample];
    auto targetGain = paramValueToGainLinear(gainParamValue);

    auto balanceParamValue = balanceControlBuffer.getReadPointer(0)[sample];
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
