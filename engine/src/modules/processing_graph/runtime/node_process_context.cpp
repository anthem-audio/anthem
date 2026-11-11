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

  const auto processor = graphNode->getProcessor();
  for (const auto& port : *graphNode->controlInputPorts()) {
    if (!port->isAvailable() || !port->config()->parameterConfig())
      continue;
    const auto parameter = processor->getParameter(port->id());
    if (!parameter)
      throw std::runtime_error("Processor has no base value for a confirmed parameter.");
    const auto buffer = inputControlBuffers.find(port->id());
    inputParameters.push_back({.portId = port->id(),
        .parameter = parameter,
        .controlBufferIndex = buffer == inputControlBuffers.end() ? std::nullopt : buffer->second});
  }
}

void NodeProcessContext::cleanup() {
  // Intentionally empty. The graph context owns the underlying storage and
  // everything else is managed with RAII.
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

float NodeProcessContext::getParameterValue(int64_t id) const {
  return findInputParameterBinding(id).parameter->value.load(std::memory_order_relaxed);
}

void NodeProcessContext::rt_updateParameterControl() {
  for (const auto& binding : inputParameters)
    binding.parameter->rt_setControlled(binding.controlBufferIndex.has_value());
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

void NodeProcessContext::rt_clearOutputs() {
  for (const auto& [_, slice] : outputAudioBuffers)
    graphProcessContext->rt_getAudioBufferView(slice).clear();
  for (const auto& [_, index] : outputControlBuffers)
    graphProcessContext->rt_getControlBufferView(index).clear();
  for (const auto& [_, index] : outputEventBuffers)
    graphProcessContext->getEventBuffer(index)->clear();
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
  const auto parameter = std::find_if(inputParameters.begin(),
      inputParameters.end(),
      [id](const auto& binding) { return binding.portId == id; });
  if (parameter != inputParameters.end())
    return rt_getInputParameterSignal(*parameter);
  const auto buffer = getInputControlBuffer(id);
  return {.rt_buffer = buffer, .rt_hasBuffer = buffer.isValid()};
}

NodeProcessContext::InputControlSignal NodeProcessContext::rt_getInputParameterSignal(
    const InputParameterBinding& binding) const {
  if (binding.controlBufferIndex)
    return {.rt_buffer = graphProcessContext->rt_getControlBufferView(*binding.controlBufferIndex),
        .rt_hasBuffer = true};
  return {.parameterValue = binding.parameter->value.load(std::memory_order_relaxed)};
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
