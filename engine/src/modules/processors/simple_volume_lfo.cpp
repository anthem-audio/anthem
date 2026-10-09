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

#include "simple_volume_lfo.h"

#include "modules/core/engine.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <utility>

namespace anthem {

SimpleVolumeLfoProcessor::SimpleVolumeLfoProcessor(const SimpleVolumeLfoProcessorModelImpl& _impl)
  : Processor("SimpleVolumeLfo"), SimpleVolumeLfoProcessorModelBase(_impl) {}

SimpleVolumeLfoProcessor::~SimpleVolumeLfoProcessor() {}

void SimpleVolumeLfoProcessor::rt_advanceState(RuntimeState& state, float rt_rate) {
  if (state.rt_increasing) {
    state.rt_amplitude += rt_rate;
  } else {
    state.rt_amplitude -= rt_rate;
  }

  if (state.rt_amplitude >= 1.0f) {
    state.rt_amplitude = 1.0f;
    state.rt_increasing = false;
  } else if (state.rt_amplitude <= 0.0f) {
    state.rt_amplitude = 0.0f;
    state.rt_increasing = true;
  }
}

void SimpleVolumeLfoProcessor::prepareToProcess(ProcessorPrepareCallback complete) {
  const auto audioProcessingConfig =
      Engine::getInstance().audioSessionController->getCurrentAudioProcessingConfig();
  if (!audioProcessingConfig.has_value()) {
    complete(ProcessorPrepareResult{
        .success = false,
        .error = std::string("No audio processing config is active."),
    });
    return;
  }

  rt_state = RuntimeState{};
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
  };
  complete(ProcessorPrepareResult{.portConfiguration = std::move(ports)});
}

void SimpleVolumeLfoProcessor::process(NodeProcessContext& context, int numSamples) {
  auto inputBuffer = context.getInputAudioBuffer(SimpleVolumeLfoProcessor::audioInputPortId);
  auto outputBuffer = context.getOutputAudioBuffer(SimpleVolumeLfoProcessor::audioOutputPortId);

  // Generate a sine wave
  for (int sample = 0; sample < numSamples; ++sample) {
    for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel) {
      const float inputValue = inputBuffer.getSample(channel, sample);
      outputBuffer.getWritePointer(channel)[sample] = inputValue * rt_state.rt_amplitude;
    }

    rt_advanceState(rt_state, rt_rate);
  }
}

} // namespace anthem
