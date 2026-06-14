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

#include "modules/core/constants.h"
#include "modules/core/engine_runtime_services.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/runtime/node_process_context.h"

#include <algorithm>
#include <cstring>
#include <stdexcept>

namespace anthem {

GraphProcessContext::GraphProcessContext(
    EngineRuntimeServices& rtServices, const GraphBufferLayout& bufferLayout)
  : rt_engineRuntimeServices(&rtServices) {
  blockSize = bufferLayout.blockSize;
  numAudioChannels = bufferLayout.numAudioChannels;
}

GraphProcessContext::~GraphProcessContext() = default;

void GraphProcessContext::Builder::reserve(size_t nodeProcessContextCount,
    size_t audioBufferCount,
    size_t controlBufferCount,
    size_t eventBufferCount) {
  jassert(context != nullptr);
  context->nodeProcessContexts.reserve(nodeProcessContextCount);
  context->audioBufferSlots.reserve(audioBufferCount);
  context->controlBuffers.reserve(controlBufferCount);
  context->eventBuffers.reserve(eventBufferCount);
}

size_t GraphProcessContext::Builder::declareAudioBufferSlot() {
  jassert(context != nullptr);
  return declareAudioBufferSlot(context->numAudioChannels);
}

size_t GraphProcessContext::Builder::declareAudioBufferSlot(int channelCount) {
  jassert(context != nullptr);
  jassert(channelCount >= 0);
  if (channelCount < 0) {
    throw std::runtime_error(
        "GraphProcessContext cannot declare a negative-channel audio buffer slot.");
  }

  context->audioArena.reset();
  context->audioBufferSlots.push_back(GraphProcessContext::AudioBufferSlot{
      .channelCount = channelCount,
  });
  return context->audioBufferSlots.size() - 1;
}

size_t GraphProcessContext::Builder::allocateControlBuffer() {
  jassert(context != nullptr);
  context->controlBuffers.emplace_back(1, context->blockSize);
  return context->controlBuffers.size() - 1;
}

size_t GraphProcessContext::Builder::allocateEventBuffer(size_t initialCapacity) {
  jassert(context != nullptr);
  context->eventBuffers.push_back(std::make_unique<EventBuffer>(initialCapacity));
  return context->eventBuffers.size() - 1;
}

size_t GraphProcessContext::Builder::getSharedEmptyEventBufferIndex() {
  jassert(context != nullptr);
  if (context->sharedEmptyEventBufferIndex.has_value()) {
    return *context->sharedEmptyEventBufferIndex;
  }

  auto bufferIndex = allocateEventBuffer(DEFAULT_EVENT_BUFFER_SIZE);
  context->getEventBuffer(bufferIndex)->clear();
  context->sharedEmptyEventBufferIndex = bufferIndex;

  return bufferIndex;
}

NodeProcessContext& GraphProcessContext::Builder::createNodeProcessContext(
    std::shared_ptr<Node>& graphNode, NodeProcessContext::BufferBindings bufferBindings) {
  jassert(context != nullptr);
  auto nodeContext =
      std::make_unique<NodeProcessContext>(graphNode, *context, std::move(bufferBindings));
  auto* nodeContextPtr = nodeContext.get();
  context->nodeProcessContexts.push_back(std::move(nodeContext));

  return *nodeContextPtr;
}

void GraphProcessContext::Builder::registerAudioBufferSlotsUsedByNode(
    const std::vector<size_t>& slotIndices) {
  jassert(context != nullptr);
  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < context->audioBufferSlots.size());
    if (slotIndex >= context->audioBufferSlots.size()) {
      continue;
    }

    context->audioBufferSlots[slotIndex].nodeUseCount++;
  }
}

void GraphProcessContext::Builder::setAudioBufferSlotClearOnAllocate(
    size_t index, bool clearOnAllocate) {
  jassert(context != nullptr);
  jassert(index < context->audioBufferSlots.size());
  if (index >= context->audioBufferSlots.size()) {
    return;
  }

  context->audioBufferSlots[index].clearOnAllocate = clearOnAllocate;
}

void GraphProcessContext::Builder::finalizeAudioArena() {
  jassert(context != nullptr);
  int maxChannelCount = 0;

  for (const auto& slot : context->audioBufferSlots) {
    maxChannelCount = std::max(maxChannelCount, slot.channelCount);
  }

  if (context->audioBufferSlots.empty() || maxChannelCount <= 0) {
    context->audioArena.reset();
    return;
  }

  if (context->blockSize <= 0) {
    throw std::runtime_error(
        "GraphProcessContext cannot create an audio arena for a non-positive block size.");
  }

  context->audioArena =
      std::make_unique<ArenaAllocator>(static_cast<size_t>(context->blockSize) * sizeof(float),
          static_cast<size_t>(maxChannelCount),
          context->audioBufferSlots.size());
}

int GraphProcessContext::getDefaultAudioChannelCount() const {
  return numAudioChannels;
}

int GraphProcessContext::getBlockSize() const {
  return blockSize;
}

size_t GraphProcessContext::getAudioBufferSlotCount() const {
  return audioBufferSlots.size();
}

int GraphProcessContext::getAudioBufferSlotChannelCount(size_t index) const {
  jassert(index < audioBufferSlots.size());
  if (index >= audioBufferSlots.size()) {
    return 0;
  }

  return audioBufferSlots[index].channelCount;
}

bool GraphProcessContext::getAudioBufferSlotClearOnAllocate(size_t index) const {
  jassert(index < audioBufferSlots.size());
  if (index >= audioBufferSlots.size()) {
    return true;
  }

  return audioBufferSlots[index].clearOnAllocate;
}

void GraphProcessContext::rt_prepareAudioArenaForBlock() {
  if (audioArena != nullptr) {
    audioArena->reset();
  }

  for (auto& slot : audioBufferSlots) {
    slot.rt_arenaHandle = std::nullopt;
    slot.rt_remainingNodeUseCount = slot.nodeUseCount;
  }
}

void GraphProcessContext::rt_allocateAudioBufferSlotsForNode(
    const std::vector<size_t>& slotIndices) {
  if (audioArena == nullptr) {
    return;
  }

  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < audioBufferSlots.size());
    if (slotIndex >= audioBufferSlots.size()) {
      continue;
    }

    auto& slot = audioBufferSlots[slotIndex];
    jassert(slot.channelCount > 0);

    if (slot.rt_arenaHandle.has_value()) {
      continue;
    }

    slot.rt_arenaHandle = audioArena->allocate(static_cast<size_t>(slot.channelCount));
    jassert(slot.rt_arenaHandle.has_value());

    if (!slot.rt_arenaHandle.has_value()) {
      continue;
    }

    auto* slotData = audioArena->getPointer(*slot.rt_arenaHandle);
    jassert(slotData != nullptr);

    if (slot.clearOnAllocate && slotData != nullptr) {
      std::memset(slotData,
          0,
          static_cast<size_t>(slot.channelCount) * static_cast<size_t>(blockSize) * sizeof(float));
    }
  }
}

void GraphProcessContext::rt_releaseAudioBufferSlotUsesForNode(
    const std::vector<size_t>& slotIndices) {
  if (audioArena == nullptr) {
    return;
  }

  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < audioBufferSlots.size());
    if (slotIndex >= audioBufferSlots.size()) {
      continue;
    }

    auto& slot = audioBufferSlots[slotIndex];
    jassert(slot.rt_remainingNodeUseCount > 0);

    if (slot.rt_remainingNodeUseCount == 0) {
      continue;
    }

    slot.rt_remainingNodeUseCount--;

    if (slot.rt_remainingNodeUseCount > 0) {
      continue;
    }

    if (slot.rt_arenaHandle.has_value()) {
      [[maybe_unused]] const auto didFree = audioArena->free(*slot.rt_arenaHandle);
      jassert(didFree);
      slot.rt_arenaHandle = std::nullopt;
    }
  }
}

void GraphProcessContext::rt_allocateAllAudioBufferSlots() {
  std::vector<size_t> slotIndices;
  slotIndices.reserve(audioBufferSlots.size());

  for (size_t slotIndex = 0; slotIndex < audioBufferSlots.size(); ++slotIndex) {
    slotIndices.push_back(slotIndex);
  }

  rt_allocateAudioBufferSlotsForNode(slotIndices);
}

AudioBufferView GraphProcessContext::rt_getAudioBufferView(size_t index) {
  jassert(index < audioBufferSlots.size());
  if (index >= audioBufferSlots.size()) {
    return {};
  }

  return rt_getAudioBufferView(AudioBufferSlotSlice{
      .slotIndex = index,
      .channelCount = audioBufferSlots[index].channelCount,
  });
}

AudioBufferView GraphProcessContext::rt_getAudioBufferView(const AudioBufferSlotSlice& slice) {
  jassert(slice.slotIndex < audioBufferSlots.size());
  if (slice.slotIndex >= audioBufferSlots.size()) {
    return {};
  }

  auto& slot = audioBufferSlots[slice.slotIndex];
  jassert(slice.channelCount >= 0);
  jassert(slice.channelCount <= slot.channelCount);
  jassert(slot.rt_arenaHandle.has_value());

  if (audioArena == nullptr || !slot.rt_arenaHandle.has_value() || slice.channelCount < 0 ||
      slice.channelCount > slot.channelCount) {
    return {};
  }

  auto* slotData = audioArena->getPointer(*slot.rt_arenaHandle);
  jassert(slotData != nullptr);

  if (slotData == nullptr) {
    return {};
  }

  return AudioBufferView(
      reinterpret_cast<float*>(slotData), slice.channelCount, blockSize, blockSize);
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
  jassert(rt_engineRuntimeServices != nullptr);
  if (rt_engineRuntimeServices == nullptr) {
    return invalidLiveNoteId;
  }

  return rt_engineRuntimeServices->rt_allocateLiveNoteId();
}

EngineRuntimeServices& GraphProcessContext::rt_getEngineRuntimeServices() {
  jassert(rt_engineRuntimeServices != nullptr);
  return *rt_engineRuntimeServices;
}

void GraphProcessContext::cleanup() {
  for (auto& context : nodeProcessContexts) {
    context->cleanup();
  }
}

} // namespace anthem
