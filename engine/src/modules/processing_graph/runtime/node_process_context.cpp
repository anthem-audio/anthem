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

#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/model/node_port.h"
#include "modules/processing_graph/runtime/graph_process_context.h"

#include <algorithm>
#include <utility>

namespace anthem {

NodeProcessContext::NodeProcessContext(std::shared_ptr<Node>& graphNode,
    GraphProcessContext& graphProcessContext,
    BufferBindings bufferBindings)
  : graphNode(graphNode), graphProcessContext(&graphProcessContext) {
  inputAudioBuffers = std::move(bufferBindings.inputAudioBuffers);
  outputAudioBuffers = std::move(bufferBindings.outputAudioBuffers);
  audioProcessBuffer = bufferBindings.audioProcessBuffer;
  inputControlBuffers = std::move(bufferBindings.inputControlBuffers);
  outputControlBuffers = std::move(bufferBindings.outputControlBuffers);
  inputEventBuffers = std::move(bufferBindings.inputEventBuffers);
  outputEventBuffers = std::move(bufferBindings.outputEventBuffers);
  rt_audioBuffersToClear = std::move(bufferBindings.rt_audioBuffersToClear);
  rt_eventBuffersToClear = std::move(bufferBindings.rt_eventBuffersToClear);

  rt_connectedInputControlPorts.reserve(inputControlBuffers.size());
  for (const auto& [portId, bufferIndex] : inputControlBuffers) {
    if (!bufferIndex.has_value()) {
      continue;
    }

    rt_connectedInputControlPorts.push_back(ConnectedInputControlPort{
        .portId = portId,
        .bufferIndex = *bufferIndex,
    });
  }

  inputParameters.reserve(graphNode->controlInputPorts()->size());

  for (auto& port : *graphNode->controlInputPorts()) {
    auto parameterValue = static_cast<float>(port->parameterValue().value_or(0.0));
    auto& parameterConfig = port->config()->parameterConfig();

    if (!parameterConfig.has_value()) {
      continue;
    }

    InputParameterBinding state;
    state.portId = port->id();
    state.value = std::make_unique<std::atomic<float>>(parameterValue);
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

float NodeProcessContext::getParameterValue(int64_t id) const {
  return findInputParameterBinding(id).value->load();
}

void NodeProcessContext::clearBuffers() {
  jassert(graphProcessContext != nullptr);

  for (const auto& slice : rt_audioBuffersToClear) {
    auto buffer = graphProcessContext->rt_getAudioBufferView(slice);
    buffer.clear();
  }

  for (const auto bufferIndex : rt_eventBuffersToClear) {
    graphProcessContext->getEventBuffer(bufferIndex)->clear();
  }
}

size_t NodeProcessContext::getBufferIndex(
    NodePortDataType dataType, BufferDirection direction, int64_t id) const {
  switch (dataType) {
    case NodePortDataType::audio:
      return direction == BufferDirection::input ? inputAudioBuffers.at(id).slotIndex
                                                 : outputAudioBuffers.at(id).slotIndex;
    case NodePortDataType::control: {
      if (direction == BufferDirection::output) {
        return outputControlBuffers.at(id);
      }

      auto bufferIndex = inputControlBuffers.at(id);
      if (!bufferIndex.has_value()) {
        throw std::runtime_error(
            "AnthemNodeProcessContext input control port has no buffer for port ID " +
            std::to_string(id) + ".");
      }

      return *bufferIndex;
    }
    case NodePortDataType::event:
      return direction == BufferDirection::input ? inputEventBuffers.at(id)
                                                 : outputEventBuffers.at(id);
  }

  throw std::runtime_error("AnthemNodeProcessContext received an unsupported port data type.");
}

AudioBufferView NodeProcessContext::getInputAudioBuffer(int64_t id) const {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getAudioBufferView(inputAudioBuffers.at(id));
}

AudioBufferView NodeProcessContext::getMutableInputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getAudioBufferView(inputAudioBuffers.at(id));
}

AudioBufferView NodeProcessContext::getOutputAudioBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getAudioBufferView(outputAudioBuffers.at(id));
}

AudioBufferView NodeProcessContext::getAudioProcessBuffer() {
  jassert(audioProcessBuffer.has_value());
  if (!audioProcessBuffer.has_value()) {
    throw std::runtime_error("AnthemNodeProcessContext has no audio process buffer.");
  }

  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getAudioBufferView(*audioProcessBuffer);
}

bool NodeProcessContext::hasAudioProcessBuffer() const {
  return audioProcessBuffer.has_value();
}

NodeProcessContext::InputControlSignal NodeProcessContext::getInputControlSignal(int64_t id) const {
  auto bufferIndex = inputControlBuffers.at(id);
  if (bufferIndex.has_value()) {
    return InputControlSignal{
        .rt_buffer = graphProcessContext->rt_getControlBufferView(*bufferIndex),
        .rt_hasBuffer = true,
    };
  }

  return InputControlSignal{
      .parameterValue = getParameterValue(id),
  };
}

AudioBufferView NodeProcessContext::getInputControlBuffer(int64_t id) const {
  jassert(graphProcessContext != nullptr);
  auto bufferIndex = inputControlBuffers.at(id);
  if (!bufferIndex.has_value()) {
    return {};
  }

  return graphProcessContext->rt_getControlBufferView(*bufferIndex);
}

AudioBufferView NodeProcessContext::rt_getInputControlBufferByIndex(size_t index) const {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getControlBufferView(index);
}

AudioBufferView NodeProcessContext::getOutputControlBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getControlBufferView(outputControlBuffers.at(id));
}

const EventBuffer& NodeProcessContext::getInputEventBuffer(int64_t id) const {
  jassert(graphProcessContext != nullptr);
  return *graphProcessContext->getEventBuffer(inputEventBuffers.at(id));
}

EventBuffer& NodeProcessContext::getOutputEventBuffer(int64_t id) {
  jassert(graphProcessContext != nullptr);
  return *graphProcessContext->getEventBuffer(outputEventBuffers.at(id));
}

LiveNoteId NodeProcessContext::rt_allocateLiveNoteId() {
  jassert(graphProcessContext != nullptr);
  if (graphProcessContext == nullptr) {
    return invalidLiveNoteId;
  }

  return graphProcessContext->rt_allocateLiveNoteId();
}

EngineRuntimeServices& NodeProcessContext::rt_getEngineRuntimeServices() {
  jassert(graphProcessContext != nullptr);
  return graphProcessContext->rt_getEngineRuntimeServices();
}

} // namespace anthem
