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

void rt_writeParametersToControlInputs(NodeProcessContext& context, int numSamples) {
  for (auto& parameter : context.rt_getInputParameterBindings()) {
    if (!parameter.rt_shouldWriteToBuffer) {
      continue;
    }

    auto value = parameter.value->load();
    jassert(juce::jlimit(0.0f, 1.0f, value) == value);

    auto& controlBuffer = *parameter.rt_buffer;
    for (int sample = 0; sample < numSamples; ++sample) {
      controlBuffer.setSample(0, sample, value);
    }
  }
}

void rt_applyControlConnectionTransfer(const RuntimeConnectionTransferAction& action,
    GraphProcessContext& graphProcessContext,
    int numSamples) {
  jassert(!action.sourceBufferIndices.empty());

  auto& source = graphProcessContext.getControlBuffer(action.sourceBufferIndices.back());
  auto& destination = graphProcessContext.getControlBuffer(action.destinationBufferIndex);
  jassert(source.getNumChannels() == destination.getNumChannels());
  jassert(source.getNumSamples() == destination.getNumSamples());
  jassert(numSamples <= source.getNumSamples());

  for (int channel = 0; channel < source.getNumChannels(); ++channel) {
    destination.copyFrom(channel, 0, source, channel, 0, numSamples);
  }
}

void rt_applyEventConnectionTransfer(
    const RuntimeConnectionTransferAction& action, GraphProcessContext& graphProcessContext) {
  jassert(!action.sourceBufferIndices.empty());

  auto* destination = graphProcessContext.getEventBuffer(action.destinationBufferIndex).get();
  jassert(destination != nullptr);

  for (const auto sourceBufferIndex : action.sourceBufferIndices) {
    const auto* source = graphProcessContext.getEventBuffer(sourceBufferIndex).get();
    jassert(source != nullptr);

    for (size_t eventIndex = 0; eventIndex < source->getNumEvents(); ++eventIndex) {
      destination->addEvent(source->getEvent(eventIndex));
    }
  }
}

void rt_applyAudioConnectionTransfer(const RuntimeConnectionTransferAction& action,
    GraphProcessContext& graphProcessContext,
    int numSamples) {
  const auto& destinationSlice = action.destinationAudioSlice;
  auto& destination = graphProcessContext.getAudioBuffer(destinationSlice.bufferIndex);
  jassert(!action.sourceAudioSlices.empty());
  jassert(numSamples <= destination.getNumSamples());
  jassert(destinationSlice.channelCount > 0);
  jassert(destinationSlice.channelCount <= destination.getNumChannels());

#if JUCE_ASSERTIONS_ENABLED
  for (const auto& sourceSlice : action.sourceAudioSlices) {
    const auto& source = graphProcessContext.getAudioBuffer(sourceSlice.bufferIndex);
    jassert(source.getNumSamples() == destination.getNumSamples());
    jassert(numSamples <= source.getNumSamples());
    jassert(sourceSlice.channelCount == destinationSlice.channelCount);
    jassert(sourceSlice.channelCount <= source.getNumChannels());
  }
#endif

  for (int channel = 0; channel < destinationSlice.channelCount; ++channel) {
    auto* destinationSamples = destination.getWritePointer(channel);

    for (int sample = 0; sample < numSamples; ++sample) {
      float sum = 0.0f;

      for (const auto& sourceSlice : action.sourceAudioSlices) {
        const auto& source = graphProcessContext.getAudioBuffer(sourceSlice.bufferIndex);
        sum += source.getReadPointer(channel)[sample];
      }

      destinationSamples[sample] = sum;
    }
  }
}

void rt_applyConnectionTransfer(const RuntimeConnectionTransferAction& action,
    GraphProcessContext& graphProcessContext,
    int numSamples) {
  switch (action.dataType) {
    case RuntimeConnectionDataType::audio:
      rt_applyAudioConnectionTransfer(action, graphProcessContext, numSamples);
      break;
    case RuntimeConnectionDataType::control:
      rt_applyControlConnectionTransfer(action, graphProcessContext, numSamples);
      break;
    case RuntimeConnectionDataType::event:
      rt_applyEventConnectionTransfer(action, graphProcessContext);
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
  rt_writeParametersToControlInputs(*node.nodeProcessContext, numSamples);

  for (const auto& connectionTransferAction : node.connectionTransferActions) {
    rt_applyConnectionTransfer(
        connectionTransferAction, *state.runtimeGraph.graphProcessContext, numSamples);
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
