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

#include "graph_process_context.h"

#include "modules/processing_graph/compiler/node_process_context.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"

namespace anthem {

GraphProcessContext::GraphProcessContext(
    GraphRuntimeServices& rtServices, const GraphBufferLayout& bufferLayout)
  : rt_services(&rtServices) {
  blockSize = bufferLayout.blockSize;
  numAudioChannels = bufferLayout.numAudioChannels;
}

GraphProcessContext::~GraphProcessContext() = default;

void GraphProcessContext::reserve(size_t nodeProcessContextCount,
    size_t audioBufferCount,
    size_t controlBufferCount,
    size_t eventBufferCount) {
  nodeProcessContexts.reserve(nodeProcessContextCount);
  audioBuffers.reserve(audioBufferCount);
  controlBuffers.reserve(controlBufferCount);
  eventBuffers.reserve(eventBufferCount);
}

size_t GraphProcessContext::allocateAudioBuffer() {
  audioBuffers.emplace_back(numAudioChannels, blockSize);
  return audioBuffers.size() - 1;
}

size_t GraphProcessContext::allocateControlBuffer() {
  controlBuffers.emplace_back(1, blockSize);
  return controlBuffers.size() - 1;
}

size_t GraphProcessContext::allocateEventBuffer(size_t initialCapacity) {
  eventBuffers.push_back(std::make_unique<EventBuffer>(initialCapacity));
  return eventBuffers.size() - 1;
}

NodeProcessContext& GraphProcessContext::createNodeProcessContext(
    std::shared_ptr<Node>& graphNode) {
  auto context = std::make_unique<NodeProcessContext>(graphNode, *this);
  auto* contextPtr = context.get();
  nodeProcessContexts.push_back(std::move(context));
  return *contextPtr;
}

juce::AudioSampleBuffer& GraphProcessContext::getAudioBuffer(size_t index) {
  jassert(index < audioBuffers.size());
  return audioBuffers[index];
}

juce::AudioSampleBuffer& GraphProcessContext::getControlBuffer(size_t index) {
  jassert(index < controlBuffers.size());
  return controlBuffers[index];
}

std::unique_ptr<EventBuffer>& GraphProcessContext::getEventBuffer(size_t index) {
  jassert(index < eventBuffers.size());
  return eventBuffers[index];
}

LiveNoteId GraphProcessContext::rt_allocateLiveNoteId() {
  jassert(rt_services != nullptr);
  if (rt_services == nullptr) {
    return invalidLiveNoteId;
  }

  return rt_services->rt_allocateLiveNoteId();
}

void GraphProcessContext::cleanup() {
  for (auto& context : nodeProcessContexts) {
    context->cleanup();
  }
}

} // namespace anthem
