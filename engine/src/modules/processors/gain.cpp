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

#include "gain.h"

#include "modules/core/engine.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <utility>

namespace anthem {

GainProcessor::GainProcessor(const GainProcessorModelImpl& _impl)
  : Processor("Gain"), GainProcessorModelBase(_impl) {}

GainProcessor::~GainProcessor() {}

void GainProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  const auto audioProcessingConfig =
      Engine::getInstance().audioSessionController->getCurrentAudioProcessingConfig();
  if (!audioProcessingConfig.has_value()) {
    complete(ProcessorPrepareResult{
        .success = false,
        .error = std::string("No audio processing config is active."),
    });
    return;
  }

  ProcessorNodePortConfiguration ports{
      .audioInputPorts =
          {
              ProcessorPortConfiguration{
                  .id = audioInputPortId,
                  .channelCount = audioProcessingConfig->outputChannelCount,
              },
          },
      .audioOutputPorts =
          {
              ProcessorPortConfiguration{
                  .id = audioOutputPortId,
                  .channelCount = audioProcessingConfig->outputChannelCount,
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
          },
  };
  complete(ProcessorPrepareResult{.portConfiguration = std::move(ports)});
}

void GainProcessor::process(NodeProcessContext& context, int numSamples) {
  auto audioInBuffer = context.getInputAudioBuffer(GainProcessor::audioInputPortId);
  auto audioOutBuffer = context.getOutputAudioBuffer(GainProcessor::audioOutputPortId);

  auto amplitudeControl = context.getInputControlSignal(GainProcessor::gainPortId);

  for (int sample = 0; sample < numSamples; sample++) {
    auto paramValue = amplitudeControl.getSample(sample);
    float targetGain = paramValueToGainLinear(paramValue);

    for (int channel = 0; channel < audioOutBuffer.getNumChannels(); ++channel) {
      auto inputSample = audioInBuffer.getReadPointer(channel)[sample];
      auto outputSample = inputSample * targetGain;

      audioOutBuffer.getWritePointer(channel)[sample] = outputSample;
    }
  }
}

} // namespace anthem
