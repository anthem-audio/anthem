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

#include "graph_executor_shared.h"

#include "modules/processing_graph/model/runtime_graph.h"
#include "modules/processing_graph/processor/event_buffer.h"
#include "modules/processing_graph/processor/processor.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <atomic>
#include <juce_core/juce_core.h>

namespace anthem {

GraphExecutorState::GraphExecutorState(RuntimeGraph& runtimeGraph) : runtimeGraph(runtimeGraph) {}

namespace {

void rt_writeParametersToControlInputs(
    NodeProcessContext& context, float sampleRate, int numSamples) {
  jassert(sampleRate > 0.0f);
  const auto secondsPerSample = sampleRate > 0.0f ? 1.0f / sampleRate : 0.0f;

  for (auto& parameter : context.rt_getInputParameterBindings()) {
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

void rt_copyAudioBuffer(
    const RuntimeConnectionCopy& copy, GraphProcessContext& graphProcessContext, int numSamples) {
  auto& source = graphProcessContext.getAudioBuffer(copy.sourceBufferIndex);
  auto& destination = graphProcessContext.getAudioBuffer(copy.destinationBufferIndex);
  jassert(source.getNumChannels() == destination.getNumChannels());
  jassert(source.getNumSamples() == destination.getNumSamples());
  jassert(numSamples <= source.getNumSamples());

  for (int channel = 0; channel < source.getNumChannels(); ++channel) {
    destination.addFrom(channel, 0, source, channel, 0, numSamples);
  }
}

void rt_copyControlBuffer(
    const RuntimeConnectionCopy& copy, GraphProcessContext& graphProcessContext, int numSamples) {
  auto& source = graphProcessContext.getControlBuffer(copy.sourceBufferIndex);
  auto& destination = graphProcessContext.getControlBuffer(copy.destinationBufferIndex);
  jassert(source.getNumChannels() == destination.getNumChannels());
  jassert(source.getNumSamples() == destination.getNumSamples());
  jassert(numSamples <= source.getNumSamples());

  for (int channel = 0; channel < source.getNumChannels(); ++channel) {
    destination.copyFrom(channel, 0, source, channel, 0, numSamples);
  }
}

void rt_copyEvents(const RuntimeConnectionCopy& copy, GraphProcessContext& graphProcessContext) {
  auto* source = graphProcessContext.getEventBuffer(copy.sourceBufferIndex).get();
  auto* destination = graphProcessContext.getEventBuffer(copy.destinationBufferIndex).get();
  jassert(source != nullptr);
  jassert(destination != nullptr);

  for (size_t eventIndex = 0; eventIndex < source->getNumEvents(); ++eventIndex) {
    destination->addEvent(source->getEvent(eventIndex));
  }
}

void rt_copyIncomingConnection(
    const RuntimeConnectionCopy& copy, GraphProcessContext& graphProcessContext, int numSamples) {
  switch (copy.dataType) {
    case RuntimeConnectionDataType::audio:
      rt_copyAudioBuffer(copy, graphProcessContext, numSamples);
      break;
    case RuntimeConnectionDataType::control:
      rt_copyControlBuffer(copy, graphProcessContext, numSamples);
      break;
    case RuntimeConnectionDataType::event:
      rt_copyEvents(copy, graphProcessContext);
      break;
  }
}

} // namespace

void rt_prepareGraphForBlock(GraphExecutorState& state) {
  for (auto& [_, runtimeNode] : state.runtimeGraph.nodes) {
    runtimeNode.rt_state.rt_remainingUpstreamNodes.store(
        runtimeNode.upstreamNodeCount, std::memory_order_relaxed);
  }
}

void rt_processNode(GraphExecutorState& state, RuntimeNode& node, int numSamples) {
  jassert(state.runtimeGraph.graphProcessContext != nullptr);
  jassert(node.nodeProcessContext != nullptr);

  if (state.runtimeGraph.graphProcessContext == nullptr || node.nodeProcessContext == nullptr) {
    return;
  }

  node.nodeProcessContext->clearBuffers();
  rt_writeParametersToControlInputs(
      *node.nodeProcessContext, state.runtimeGraph.sampleRate, numSamples);

  for (const auto& incomingConnectionCopy : node.incomingConnectionCopies) {
    rt_copyIncomingConnection(
        incomingConnectionCopy, *state.runtimeGraph.graphProcessContext, numSamples);
  }

  if (node.processor != nullptr) {
    node.processor->process(*node.nodeProcessContext, numSamples);
  }
}

bool rt_decrementRemainingUpstreamNodes(RuntimeNode& node) {
  const auto previousRemainingUpstreamNodeCount =
      node.rt_state.rt_remainingUpstreamNodes.fetch_sub(1, std::memory_order_acq_rel);
  jassert(previousRemainingUpstreamNodeCount > 0);

  return previousRemainingUpstreamNodeCount == 1;
}

} // namespace anthem
