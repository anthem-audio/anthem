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

#include "graph_action_executor.h"

#include "modules/processing_graph/compiler/node_process_context.h"
#include "modules/processing_graph/processor/event_buffer.h"
#include "modules/processing_graph/processor/processor.h"

namespace anthem {

namespace {

void executeClearBuffers(const ClearBuffersActionData& action) {
  action.context->clearBuffers();
}

void executeWriteParametersToControlInputs(const WriteParametersToControlInputsActionData& action,
    float secondsPerSample,
    int numSamples) {
  for (auto& parameter : action.context->rt_getInputParameterBindings()) {
    auto value = parameter.value->load();
    jassert(juce::jlimit(0.0f, 1.0f, value) == value);

    if (parameter.rt_smoother->getTargetValue() != value) {
      parameter.rt_smoother->setTargetValue(value);
    }

    auto& controlBuffer = *parameter.rt_buffer;
    for (int sample = 0; sample < numSamples; ++sample) {
      parameter.rt_smoother->process(secondsPerSample);
      auto currentValue = parameter.rt_smoother->getCurrentValue();
      jassert(juce::jlimit(0.0f, 1.0f, currentValue) == currentValue);
      controlBuffer.setSample(0, sample, currentValue);
    }
  }
}

void executeProcessNode(const ProcessNodeActionData& action, int numSamples) {
  action.processor->process(*action.context, numSamples);
}

void executeCopyAudioBuffer(const CopyAudioBufferActionData& action,
    GraphProcessContext& graphProcessContext,
    int numSamples) {
  auto& source = graphProcessContext.getAudioBuffer(action.sourceBufferIndex);
  auto& destination = graphProcessContext.getAudioBuffer(action.destinationBufferIndex);
  jassert(source.getNumChannels() == destination.getNumChannels());
  jassert(source.getNumSamples() == destination.getNumSamples());
  jassert(numSamples <= source.getNumSamples());

  for (int channel = 0; channel < source.getNumChannels(); ++channel) {
    destination.addFrom(channel, 0, source, channel, 0, numSamples);
  }
}

void executeCopyControlBuffer(const CopyControlBufferActionData& action,
    GraphProcessContext& graphProcessContext,
    int numSamples) {
  auto& source = graphProcessContext.getControlBuffer(action.sourceBufferIndex);
  auto& destination = graphProcessContext.getControlBuffer(action.destinationBufferIndex);
  jassert(source.getNumChannels() == destination.getNumChannels());
  jassert(source.getNumSamples() == destination.getNumSamples());
  jassert(numSamples <= source.getNumSamples());

  for (int channel = 0; channel < source.getNumChannels(); ++channel) {
    destination.copyFrom(channel, 0, source, channel, 0, numSamples);
  }
}

void executeCopyEvents(
    const CopyEventsActionData& action, GraphProcessContext& graphProcessContext) {
  auto* source = graphProcessContext.getEventBuffer(action.sourceBufferIndex).get();
  auto* destination = graphProcessContext.getEventBuffer(action.destinationBufferIndex).get();
  jassert(source != nullptr);
  jassert(destination != nullptr);

  for (size_t eventIndex = 0; eventIndex < source->getNumEvents(); ++eventIndex) {
    destination->addEvent(source->getEvent(eventIndex));
  }
}

} // namespace

void executeGraphActions(std::span<const GraphAction> actions,
    GraphProcessContext& graphProcessContext,
    float sampleRate,
    int numSamples) {
  jassert(sampleRate > 0.0f);
  const auto secondsPerSample = sampleRate > 0.0f ? 1.0f / sampleRate : 0.0f;

  for (const auto& action : actions) {
    switch (action.type) {
      case GraphActionType::ClearBuffers:
        executeClearBuffers(action.clearBuffers);
        break;
      case GraphActionType::WriteParametersToControlInputs:
        executeWriteParametersToControlInputs(
            action.writeParametersToControlInputs, secondsPerSample, numSamples);
        break;
      case GraphActionType::ProcessNode:
        executeProcessNode(action.processNode, numSamples);
        break;
      case GraphActionType::CopyAudioBuffer:
        executeCopyAudioBuffer(action.copyAudioBuffer, graphProcessContext, numSamples);
        break;
      case GraphActionType::CopyControlBuffer:
        executeCopyControlBuffer(action.copyControlBuffer, graphProcessContext, numSamples);
        break;
      case GraphActionType::CopyEvents:
        executeCopyEvents(action.copyEvents, graphProcessContext);
        break;
    }
  }
}

void executeGraphActions(const GraphCompilationResult& result, int numSamples) {
  jassert(result.graphProcessContext != nullptr);
  if (result.graphProcessContext == nullptr) {
    return;
  }

  executeGraphActions(result.actions, *result.graphProcessContext, result.sampleRate, numSamples);
}

} // namespace anthem
