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
    inputAudioBuffers.emplace(port->id(), graphProcessContext.allocateAudioBuffer());
  }

  for (auto& port : *graphNode->audioOutputPorts()) {
    outputAudioBuffers.emplace(port->id(), graphProcessContext.allocateAudioBuffer());
  }

  for (auto& port : *graphNode->controlInputPorts()) {
    inputControlBuffers.emplace(port->id(), graphProcessContext.allocateControlBuffer());
  }

  for (auto& port : *graphNode->controlOutputPorts()) {
    outputControlBuffers.emplace(port->id(), graphProcessContext.allocateControlBuffer());
  }

  for (auto& port : *graphNode->eventInputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph recompilation can preserve processing state across compiles.
    inputEventBuffers.emplace(
        port->id(), graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE));
  }

  for (auto& port : *graphNode->eventOutputPorts()) {
    // TODO: Seed initial capacities from persisted per-port runtime hints once
    // graph recompilation can preserve processing state across compiles.
    outputEventBuffers.emplace(
        port->id(), graphProcessContext.allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE));
  }

  for (auto& port : *graphNode->controlInputPorts()) {
    const auto controlBufferIndex = inputControlBuffers.at(port->id());
    auto parameterValue = static_cast<float>(port->parameterValue().value_or(0.0));
    auto& parameterConfig = port->config()->parameterConfig();
    auto& inputControlBuffer = graphProcessContext.getControlBuffer(controlBufferIndex);

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

  for (const auto& [portId, bufferIndex] : inputAudioBuffers) {
    juce::ignoreUnused(portId);
    graphProcessContext->getAudioBuffer(bufferIndex).clear();
  }

  for (const auto& [portId, bufferIndex] : inputEventBuffers) {
    juce::ignoreUnused(portId);
    graphProcessContext->getEventBuffer(bufferIndex)->clear();
  }

  for (const auto& [portId, bufferIndex] : outputEventBuffers) {
    juce::ignoreUnused(portId);
    graphProcessContext->getEventBuffer(bufferIndex)->clear();
  }
}

size_t NodeProcessContext::getBufferIndex(
    NodePortDataType dataType, BufferDirection direction, int64_t id) const {
  switch (dataType) {
    case NodePortDataType::audio:
      return direction == BufferDirection::input ? inputAudioBuffers.at(id)
                                                 : outputAudioBuffers.at(id);
    case NodePortDataType::control:
      return direction == BufferDirection::input ? inputControlBuffers.at(id)
                                                 : outputControlBuffers.at(id);
    case NodePortDataType::event:
      return direction == BufferDirection::input ? inputEventBuffers.at(id)
                                                 : outputEventBuffers.at(id);
  }

  throw std::runtime_error("AnthemNodeProcessContext received an unsupported port data type.");
}

juce::AudioSampleBuffer& NodeProcessContext::getInputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getAudioBuffer(inputAudioBuffers.at(id));
}

juce::AudioSampleBuffer& NodeProcessContext::getOutputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getAudioBuffer(outputAudioBuffers.at(id));
}

juce::AudioSampleBuffer& NodeProcessContext::getInputControlBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getControlBuffer(inputControlBuffers.at(id));
}

juce::AudioSampleBuffer& NodeProcessContext::getOutputControlBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getControlBuffer(outputControlBuffers.at(id));
}

std::unique_ptr<EventBuffer>& NodeProcessContext::getInputEventBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getEventBuffer(inputEventBuffers.at(id));
}

std::unique_ptr<EventBuffer>& NodeProcessContext::getOutputEventBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->getEventBuffer(outputEventBuffers.at(id));
}

LiveNoteId NodeProcessContext::rt_allocateLiveNoteId() {
  jassert(graphProcessContext != nullptr);
  if (graphProcessContext == nullptr) {
    return invalidLiveNoteId;
  }

  return graphProcessContext->rt_allocateLiveNoteId();
}

} // namespace anthem
