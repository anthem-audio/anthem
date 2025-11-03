/*
  Copyright (C) 2025 Joshua Wade

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

#include "modules/processing_graph/compiler/anthem_process_context.h"

#include <juce_core/juce_core.h>

BalanceProcessor::BalanceProcessor(const BalanceProcessorModelImpl& _impl)
    : AnthemProcessor("Balance"), BalanceProcessorModelBase(_impl) {}

BalanceProcessor::~BalanceProcessor() {}

void BalanceProcessor::prepareToProcess() {}

void BalanceProcessor::process(AnthemProcessContext& context, int numSamples) {
  auto& audioInBuffer = context.getInputAudioBuffer(BalanceProcessorModelBase::audioInputPortId);
  auto& audioOutBuffer = context.getOutputAudioBuffer(BalanceProcessorModelBase::audioOutputPortId);

  auto& balanceControlBuffer = context.getInputControlBuffer(BalanceProcessorModelBase::balancePortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto paramValue = balanceControlBuffer.getReadPointer(0)[sample];

    auto gainR = bw_minf(1.0f - paramValue, 1.0f);
    auto gainL = bw_minf(1.0f + paramValue, 1.0f);

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
