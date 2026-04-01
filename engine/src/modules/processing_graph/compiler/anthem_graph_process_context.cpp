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

#include "anthem_graph_process_context.h"

#include "modules/core/anthem.h"
#include "modules/processing_graph/compiler/anthem_node_process_context.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"

AnthemGraphProcessContext::AnthemGraphProcessContext(GraphRuntimeServices& rtServices)
  : rt_services(&rtServices) {
  auto* currentDevice = Anthem::getInstance().audioDeviceManager.getCurrentAudioDevice();
  jassert(currentDevice != nullptr);

  if (currentDevice != nullptr) {
    blockSize = currentDevice->getCurrentBufferSizeSamples();
    numAudioChannels = currentDevice->getActiveOutputChannels().countNumberOfSetBits();
  }
}

AnthemGraphProcessContext::~AnthemGraphProcessContext() = default;

void AnthemGraphProcessContext::reserve(size_t nodeProcessContextCount,
                                        size_t audioBufferCount,
                                        size_t controlBufferCount,
                                        size_t eventBufferCount) {
  nodeProcessContexts.reserve(nodeProcessContextCount);
  audioBuffers.reserve(audioBufferCount);
  controlBuffers.reserve(controlBufferCount);
  eventBuffers.reserve(eventBufferCount);
}

size_t AnthemGraphProcessContext::allocateAudioBuffer() {
  audioBuffers.emplace_back(numAudioChannels, blockSize);
  return audioBuffers.size() - 1;
}

size_t AnthemGraphProcessContext::allocateControlBuffer() {
  controlBuffers.emplace_back(1, blockSize);
  return controlBuffers.size() - 1;
}

size_t AnthemGraphProcessContext::allocateEventBuffer(size_t initialCapacity) {
  eventBuffers.push_back(std::make_unique<AnthemEventBuffer>(initialCapacity));
  return eventBuffers.size() - 1;
}

AnthemNodeProcessContext&
AnthemGraphProcessContext::createNodeProcessContext(std::shared_ptr<Node>& graphNode) {
  auto context = std::make_unique<AnthemNodeProcessContext>(graphNode, *this);
  auto* contextPtr = context.get();
  nodeProcessContexts.push_back(std::move(context));
  return *contextPtr;
}

juce::AudioSampleBuffer& AnthemGraphProcessContext::getAudioBuffer(size_t index) {
  jassert(index < audioBuffers.size());
  return audioBuffers[index];
}

juce::AudioSampleBuffer& AnthemGraphProcessContext::getControlBuffer(size_t index) {
  jassert(index < controlBuffers.size());
  return controlBuffers[index];
}

std::unique_ptr<AnthemEventBuffer>& AnthemGraphProcessContext::getEventBuffer(size_t index) {
  jassert(index < eventBuffers.size());
  return eventBuffers[index];
}

AnthemLiveNoteId AnthemGraphProcessContext::rt_allocateLiveNoteId() {
  jassert(rt_services != nullptr);
  if (rt_services == nullptr) {
    return anthemInvalidLiveNoteId;
  }

  return rt_services->rt_allocateLiveNoteId();
}

void AnthemGraphProcessContext::cleanup() {
  for (auto& context : nodeProcessContexts) {
    context->cleanup();
  }
}
