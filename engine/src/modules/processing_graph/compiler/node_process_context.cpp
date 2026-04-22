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

#include "node_process_context.h"

#include "modules/core/constants.h"
#include "modules/processing_graph/compiler/graph_process_context.h"
#include "modules/processing_graph/model/node.h"

#include <algorithm>
#include <string>

namespace anthem {

NodeProcessContext::NodeProcessContext(
    std::shared_ptr<Node>& graphNode, GraphProcessContext& graphProcessContext)
  : graphNode(graphNode), graphProcessContext(&graphProcessContext) {
  inputAudioBuffers.reserve(graphNode->audioInputPorts()->size());
  outputAudioBuffers.reserve(graphNode->audioOutputPorts()->size());
  inputControlBuffers.reserve(graphNode->controlInputPorts()->size());
  outputControlBuffers.reserve(graphNode->controlOutputPorts()->size());
  inputEventBuffers.reserve(graphNode->eventInputPorts()->size());
  outputEventBuffers.reserve(graphNode->eventOutputPorts()->size());
  inputParameters.reserve(graphNode->controlInputPorts()->size());

  for (auto& port : *graphNode->audioInputPorts()) {
    inputAudioBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateAudioBuffer(),
    });
  }

  for (auto& port : *graphNode->audioOutputPorts()) {
    outputAudioBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateAudioBuffer(),
    });
  }

  for (auto& port : *graphNode->controlInputPorts()) {
    inputControlBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateControlBuffer(),
    });
  }

  for (auto& port : *graphNode->controlOutputPorts()) {
    outputControlBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateControlBuffer(),
    });
  }

  for (auto& port : *graphNode->eventInputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph recompilation can preserve processing state across compiles.
    inputEventBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE),
    });
  }

  for (auto& port : *graphNode->eventOutputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph recompilation can preserve processing state across compiles.
    outputEventBuffers.push_back(PortBufferHandle{
        .portId = port->id(),
        .bufferIndex = graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE),
    });
  }

  size_t inputParameterIndex = 0;
  for (auto& port : *graphNode->controlInputPorts()) {
    const auto controlBufferIndex = inputParameterIndex++;
    auto parameterValue = static_cast<float>(port->parameterValue().value_or(0.0));
    auto& parameterConfig = port->config()->parameterConfig();
    auto& inputControlBuffer =
        graphProcessContext.getControlBuffer(inputControlBuffers[controlBufferIndex].bufferIndex);

    if (!parameterConfig.has_value()) {
      continue;
    }

    InputParameterBinding state;
    state.portId = port->id();
    state.rt_buffer = &inputControlBuffer;
    state.value = std::make_unique<std::atomic<float>>(parameterValue);
    state.rt_smoother = std::make_unique<LinearParameterSmoother>(
        parameterValue, static_cast<float>((*parameterConfig)->smoothingDurationSeconds()));
    inputParameters.push_back(std::move(state));
  }
}

void NodeProcessContext::cleanup() {
  // Intentionally empty. The graph context owns the underlying storage and
  // everything else is managed with RAII.
}

const NodeProcessContext::PortBufferHandle& NodeProcessContext::findBufferHandle(
    const std::vector<PortBufferHandle>& handles, int64_t portId, const char* bufferType) const {
  auto it = std::find_if(handles.begin(), handles.end(), [portId](const PortBufferHandle& handle) {
    return handle.portId == portId;
  });

  if (it == handles.end()) {
    throw std::runtime_error("AnthemNodeProcessContext could not find " + std::string(bufferType) +
                             " buffer for port ID " + std::to_string(portId) + ".");
  }

  return *it;
}

NodeProcessContext::InputParameterBinding& NodeProcessContext::findInputParameterBinding(
    int64_t id) {
  auto it = std::find_if(inputParameters.begin(),
      inputParameters.end(),
      [id](const InputParameterBinding& inputParameter) { return inputParameter.portId == id; });

  if (it == inputParameters.end()) {
    throw std::runtime_error(
        "AnthemNodeProcessContext could not find input parameter binding for port ID " +
        std::to_string(id) + ".");
  }

  return *it;
}

const NodeProcessContext::InputParameterBinding& NodeProcessContext::findInputParameterBinding(
    int64_t id) const {
  auto it = std::find_if(inputParameters.begin(),
      inputParameters.end(),
      [id](const InputParameterBinding& inputParameter) { return inputParameter.portId == id; });

  if (it == inputParameters.end()) {
    throw std::runtime_error(
        "AnthemNodeProcessContext could not find input parameter binding for port ID " +
        std::to_string(id) + ".");
  }

  return *it;
}

void NodeProcessContext::setParameterValue(int64_t id, float value) {
  // Throw if not on the JUCE message thread
  if (!juce::MessageManager::getInstance()->isThisTheMessageThread()) {
    throw std::runtime_error(
        "AnthemNodeProcessContext::setParameterValue() must be called on the JUCE message thread.");
  }

  findInputParameterBinding(id).value->store(value);
}

float NodeProcessContext::getParameterValue(int64_t id) {
  return findInputParameterBinding(id).value->load();
}

void NodeProcessContext::clearBuffers() {
  jassert(graphProcessContext != nullptr);

  for (const auto& handle : inputAudioBuffers) {
    graphProcessContext->getAudioBuffer(handle.bufferIndex).clear();
  }

  for (const auto& handle : inputEventBuffers) {
    graphProcessContext->getEventBuffer(handle.bufferIndex)->clear();
  }

  for (const auto& handle : outputEventBuffers) {
    graphProcessContext->getEventBuffer(handle.bufferIndex)->clear();
  }
}

juce::AudioSampleBuffer& NodeProcessContext::getInputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getAudioBuffer(
      findBufferHandle(inputAudioBuffers, id, "input audio").bufferIndex);
}

juce::AudioSampleBuffer& NodeProcessContext::getOutputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getAudioBuffer(
      findBufferHandle(outputAudioBuffers, id, "output audio").bufferIndex);
}

juce::AudioSampleBuffer& NodeProcessContext::getInputControlBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getControlBuffer(
      findBufferHandle(inputControlBuffers, id, "input control").bufferIndex);
}

juce::AudioSampleBuffer& NodeProcessContext::getOutputControlBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getControlBuffer(
      findBufferHandle(outputControlBuffers, id, "output control").bufferIndex);
}

std::unique_ptr<EventBuffer>& NodeProcessContext::getInputEventBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getEventBuffer(
      findBufferHandle(inputEventBuffers, id, "input event").bufferIndex);
}

std::unique_ptr<EventBuffer>& NodeProcessContext::getOutputEventBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getEventBuffer(
      findBufferHandle(outputEventBuffers, id, "output event").bufferIndex);
}

LiveNoteId NodeProcessContext::rt_allocateLiveNoteId() {
  jassert(graphProcessContext != nullptr);
  if (graphProcessContext == nullptr) {
    return invalidLiveNoteId;
  }

  return graphProcessContext->rt_allocateLiveNoteId();
}

} // namespace anthem
