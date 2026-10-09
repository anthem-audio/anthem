/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "balance.h"

#include "modules/processing_graph/runtime/node_process_context.h"

#include <juce_core/juce_core.h>
#include <utility>

namespace anthem {

BalanceProcessor::BalanceProcessor(const BalanceProcessorModelImpl& _impl)
  : Processor("Balance"), BalanceProcessorModelBase(_impl) {}

BalanceProcessor::~BalanceProcessor() {}

void BalanceProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
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
                  .id = balancePortId,
                  .parameterDefaultValue = 0.5,
                  .parameterDisplayMode = "pan",
              },
          },
  };
  complete(ProcessorPrepareResult{.portConfiguration = std::move(ports)});
}

void BalanceProcessor::process(NodeProcessContext& context, int numSamples) {
  auto audioInBuffer = context.getInputAudioBuffer(BalanceProcessor::audioInputPortId);
  auto audioOutBuffer = context.getOutputAudioBuffer(BalanceProcessor::audioOutputPortId);

  auto balanceControl = context.getInputControlSignal(BalanceProcessor::balancePortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto normalizedValue = balanceControl.getSample(sample);
    jassert(juce::jlimit(0.0f, 1.0f, normalizedValue) == normalizedValue);
    auto pan = normalizedValue * 2.0f - 1.0f;

    auto gainR = juce::jmin(1.0f - pan, 1.0f);
    auto gainL = juce::jmin(1.0f + pan, 1.0f);

    float gains[2] = {gainR, gainL};

    jassert(audioOutBuffer.getNumChannels() >= 2);

    for (int channel = 0; channel < 2; ++channel) {
      auto inputSample = audioInBuffer.getReadPointer(channel)[sample];
      float outputSample = inputSample;

      outputSample *= gains[channel];

      audioOutBuffer.getWritePointer(channel)[sample] = outputSample;
    }
  }
}

} // namespace anthem
