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
#include <limits>
#include <stdexcept>

namespace anthem {

namespace {

// wasm is 32-bit, so we need these to make sure the arena won't try to
// allocate larger than 4GB and subsequently overflow to a much smaller arena.
size_t checkedAdd(size_t a, size_t b, const char* context) {
  if (b > std::numeric_limits<size_t>::max() - a) {
    throw std::overflow_error(context);
  }

  return a + b;
}

size_t checkedMultiply(size_t a, size_t b, const char* context) {
  if (a != 0 && b > std::numeric_limits<size_t>::max() / a) {
    throw std::overflow_error(context);
  }

  return a * b;
}

} // namespace

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
  context->sampleBufferSlots.reserve(audioBufferCount + controlBufferCount);
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

  context->sampleArena.reset();
  context->sampleBufferSlots.push_back(GraphProcessContext::SampleBufferSlot{
      .kind = GraphProcessContext::SampleBufferSlotKind::audio,
      .channelCount = channelCount,
  });
  return context->sampleBufferSlots.size() - 1;
}

size_t GraphProcessContext::Builder::allocateControlBuffer() {
  jassert(context != nullptr);
  context->sampleArena.reset();
  context->sampleBufferSlots.push_back(GraphProcessContext::SampleBufferSlot{
      .kind = GraphProcessContext::SampleBufferSlotKind::control,
      .channelCount = 1,
  });
  return context->sampleBufferSlots.size() - 1;
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

void GraphProcessContext::Builder::registerSampleBufferSlotsUsedByNode(
    const std::vector<size_t>& slotIndices) {
  jassert(context != nullptr);
  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < context->sampleBufferSlots.size());
    if (slotIndex >= context->sampleBufferSlots.size()) {
      continue;
    }

    context->sampleBufferSlots[slotIndex].nodeUseCount++;
  }
}

void GraphProcessContext::Builder::setSampleBufferSlotClearOnAllocate(
    size_t index, bool clearOnAllocate) {
  jassert(context != nullptr);
  jassert(index < context->sampleBufferSlots.size());
  if (index >= context->sampleBufferSlots.size()) {
    return;
  }

  context->sampleBufferSlots[index].clearOnAllocate = clearOnAllocate;
}

void GraphProcessContext::Builder::finalizeSampleArena() {
  jassert(context != nullptr);
  int maxAudioChannelCount = 0;
  size_t audioSlotCount = 0;
  size_t controlSlotCount = 0;

  for (const auto& slot : context->sampleBufferSlots) {
    switch (slot.kind) {
      case GraphProcessContext::SampleBufferSlotKind::audio:
        maxAudioChannelCount = std::max(maxAudioChannelCount, slot.channelCount);
        audioSlotCount++;
        break;
      case GraphProcessContext::SampleBufferSlotKind::control:
        controlSlotCount++;
        break;
    }
  }

  if (context->sampleBufferSlots.empty() || (maxAudioChannelCount <= 0 && controlSlotCount == 0)) {
    context->sampleArena.reset();
    return;
  }

  if (context->blockSize <= 0) {
    throw std::runtime_error(
        "GraphProcessContext cannot create a sample arena for a non-positive block size.");
  }

  const auto audioBlockCount =
      checkedMultiply(checkedMultiply(static_cast<size_t>(std::max(0, maxAudioChannelCount)),
                          audioSlotCount,
                          "GraphProcessContext sample arena size overflowed."),
          static_cast<size_t>(2),
          "GraphProcessContext sample arena size overflowed.");
  const auto controlBlockCount = checkedMultiply(controlSlotCount,
      static_cast<size_t>(2),
      "GraphProcessContext sample arena size overflowed.");
  const auto totalBlockCount = checkedAdd(
      audioBlockCount, controlBlockCount, "GraphProcessContext sample arena size overflowed.");

  if (totalBlockCount == 0) {
    context->sampleArena.reset();
    return;
  }

  context->sampleArena = std::make_unique<ArenaAllocator>(
      static_cast<size_t>(context->blockSize) * sizeof(float), totalBlockCount);
}

int GraphProcessContext::getDefaultAudioChannelCount() const {
  return numAudioChannels;
}

int GraphProcessContext::getBlockSize() const {
  return blockSize;
}

size_t GraphProcessContext::getSampleBufferSlotCount() const {
  return sampleBufferSlots.size();
}

int GraphProcessContext::getSampleBufferSlotChannelCount(size_t index) const {
  jassert(index < sampleBufferSlots.size());
  if (index >= sampleBufferSlots.size()) {
    return 0;
  }

  return sampleBufferSlots[index].channelCount;
}

bool GraphProcessContext::getSampleBufferSlotClearOnAllocate(size_t index) const {
  jassert(index < sampleBufferSlots.size());
  if (index >= sampleBufferSlots.size()) {
    return true;
  }

  return sampleBufferSlots[index].clearOnAllocate;
}

void GraphProcessContext::rt_prepareSampleArenaForBlock() {
  if (sampleArena != nullptr) {
    sampleArena->reset();
  }

  for (auto& slot : sampleBufferSlots) {
    slot.rt_arenaHandle = std::nullopt;
    slot.rt_remainingNodeUseCount = slot.nodeUseCount;
  }
}

void GraphProcessContext::rt_allocateSampleBufferSlotsForNode(
    const std::vector<size_t>& slotIndices) {
  if (sampleArena == nullptr) {
    return;
  }

  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < sampleBufferSlots.size());
    if (slotIndex >= sampleBufferSlots.size()) {
      continue;
    }

    auto& slot = sampleBufferSlots[slotIndex];
    jassert(slot.channelCount > 0);

    if (slot.rt_arenaHandle.has_value()) {
      continue;
    }

    slot.rt_arenaHandle = sampleArena->allocateOrAbort(static_cast<size_t>(slot.channelCount),
        "GraphProcessContext::rt_allocateSampleBufferSlotsForNode");

    auto* slotData = sampleArena->getPointer(*slot.rt_arenaHandle);
    jassert(slotData != nullptr);

    if (slot.clearOnAllocate && slotData != nullptr) {
      std::memset(slotData,
          0,
          static_cast<size_t>(slot.channelCount) * static_cast<size_t>(blockSize) * sizeof(float));
    }
  }
}

void GraphProcessContext::rt_releaseSampleBufferSlotUsesForNode(
    const std::vector<size_t>& slotIndices) {
  if (sampleArena == nullptr) {
    return;
  }

  for (const auto slotIndex : slotIndices) {
    jassert(slotIndex < sampleBufferSlots.size());
    if (slotIndex >= sampleBufferSlots.size()) {
      continue;
    }

    auto& slot = sampleBufferSlots[slotIndex];
    jassert(slot.rt_remainingNodeUseCount > 0);

    if (slot.rt_remainingNodeUseCount == 0) {
      continue;
    }

    slot.rt_remainingNodeUseCount--;

    if (slot.rt_remainingNodeUseCount > 0) {
      continue;
    }

    if (slot.rt_arenaHandle.has_value()) {
      [[maybe_unused]] const auto didFree = sampleArena->free(*slot.rt_arenaHandle);
      jassert(didFree);
      slot.rt_arenaHandle = std::nullopt;
    }
  }
}

void GraphProcessContext::rt_allocateAllSampleBufferSlots() {
  std::vector<size_t> slotIndices;
  slotIndices.reserve(sampleBufferSlots.size());

  for (size_t slotIndex = 0; slotIndex < sampleBufferSlots.size(); ++slotIndex) {
    slotIndices.push_back(slotIndex);
  }

  rt_allocateSampleBufferSlotsForNode(slotIndices);
}

AudioBufferView GraphProcessContext::rt_getAudioBufferView(size_t index) {
  jassert(index < sampleBufferSlots.size());
  if (index >= sampleBufferSlots.size()) {
    return {};
  }

  return rt_getAudioBufferView(AudioBufferSlotSlice{
      .slotIndex = index,
      .channelCount = sampleBufferSlots[index].channelCount,
  });
}

AudioBufferView GraphProcessContext::rt_getAudioBufferView(const AudioBufferSlotSlice& slice) {
  jassert(slice.slotIndex < sampleBufferSlots.size());
  if (slice.slotIndex >= sampleBufferSlots.size()) {
    return {};
  }

  auto& slot = sampleBufferSlots[slice.slotIndex];
  jassert(slice.channelCount >= 0);
  jassert(slice.channelCount <= slot.channelCount);
  jassert(slot.rt_arenaHandle.has_value());

  if (sampleArena == nullptr || !slot.rt_arenaHandle.has_value() || slice.channelCount < 0 ||
      slice.channelCount > slot.channelCount) {
    return {};
  }

  auto* slotData = sampleArena->getPointer(*slot.rt_arenaHandle);
  jassert(slotData != nullptr);

  if (slotData == nullptr) {
    return {};
  }

  return AudioBufferView(
      reinterpret_cast<float*>(slotData), slice.channelCount, blockSize, blockSize);
}

AudioBufferView GraphProcessContext::rt_getControlBufferView(size_t index) {
  jassert(index < sampleBufferSlots.size());
  if (index >= sampleBufferSlots.size()) {
    return {};
  }

  auto& slot = sampleBufferSlots[index];
  jassert(slot.kind == SampleBufferSlotKind::control);
  if (slot.kind != SampleBufferSlotKind::control) {
    return {};
  }

  return rt_getAudioBufferView(AudioBufferSlotSlice{
      .slotIndex = index,
      .channelCount = 1,
  });
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
