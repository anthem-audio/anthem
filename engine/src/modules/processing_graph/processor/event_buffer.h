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

#pragma once

#include "modules/core/constants.h"
#include "modules/sequencer/events/event.h"

#include <cstddef>
#include <cstdlib>
#include <juce_core/juce_core.h>
#include <stdexcept>

namespace anthem {

class EventBuffer {
private:
  JUCE_LEAK_DETECTOR(EventBuffer)

  struct StorageBlock {
    StorageBlock* previous;
    size_t capacity;
  };

  static_assert(sizeof(StorageBlock) % alignof(LiveEvent) == 0,
      "StorageBlock must leave the event payload aligned.");

  StorageBlock* activeBlock;

  // The active contiguous event storage.
  LiveEvent* buffer;

  // The capacity of the active buffer.
  size_t capacity;

  // The number of events in the active buffer.
  size_t numEvents;

  // Sticky lifetime diagnostics for this published graph result.
  size_t highWaterMark;
  size_t timesGrown;

  // Per-block overflow diagnostics.
  bool overflowedThisBlock;
  size_t droppedEventsThisBlock;

  static StorageBlock* allocateBlock(size_t requestedCapacity) {
    auto clampedCapacity = requestedCapacity == 0 ? static_cast<size_t>(1) : requestedCapacity;
    auto bytes = sizeof(StorageBlock) + sizeof(LiveEvent) * clampedCapacity;
    auto* raw = static_cast<std::byte*>(std::malloc(bytes));

    if (raw == nullptr) {
      return nullptr;
    }

    auto* block = reinterpret_cast<StorageBlock*>(raw);
    block->previous = nullptr;
    block->capacity = clampedCapacity;

    return block;
  }

  static LiveEvent* getBlockBuffer(StorageBlock* block) {
    return reinterpret_cast<LiveEvent*>(reinterpret_cast<std::byte*>(block) + sizeof(StorageBlock));
  }

  static void destroyBlocks(StorageBlock* block) {
    while (block != nullptr) {
      auto* previous = block->previous;
      std::free(block);
      block = previous;
    }
  }

  bool grow() {
    if (capacity >= static_cast<size_t>(MAX_EVENT_BUFFER_SIZE)) {
      return false;
    }

    size_t newCapacity = capacity * 2;
    if (newCapacity <= capacity) {
      newCapacity = static_cast<size_t>(MAX_EVENT_BUFFER_SIZE);
    }

    if (newCapacity > static_cast<size_t>(MAX_EVENT_BUFFER_SIZE)) {
      newCapacity = static_cast<size_t>(MAX_EVENT_BUFFER_SIZE);
    }

    auto* newBlock = allocateBlock(newCapacity);
    if (newBlock == nullptr) {
      return false;
    }

    auto* newBuffer = getBlockBuffer(newBlock);
    for (size_t i = 0; i < numEvents; i++) {
      newBuffer[i] = buffer[i];
    }

    newBlock->previous = activeBlock;
    activeBlock = newBlock;
    buffer = newBuffer;
    capacity = newBlock->capacity;
    timesGrown++;

    return true;
  }
public:
  explicit EventBuffer(size_t initialCapacity)
    : activeBlock(nullptr), buffer(nullptr), capacity(0), numEvents(0), highWaterMark(0),
      timesGrown(0), overflowedThisBlock(false), droppedEventsThisBlock(0) {
    auto requestedCapacity = initialCapacity;
    if (requestedCapacity == 0) {
      requestedCapacity = 1;
    }

    if (requestedCapacity > static_cast<size_t>(MAX_EVENT_BUFFER_SIZE)) {
      requestedCapacity = static_cast<size_t>(MAX_EVENT_BUFFER_SIZE);
    }

    activeBlock = allocateBlock(requestedCapacity);
    if (activeBlock == nullptr) {
      throw std::runtime_error("Failed to allocate buffer for event buffer.");
    }

    buffer = getBlockBuffer(activeBlock);
    capacity = activeBlock->capacity;
  }

  ~EventBuffer() {
    destroyBlocks(activeBlock);
  }

  bool addEvent(LiveEvent event) {
    if (numEvents >= capacity && !grow()) {
      overflowedThisBlock = true;
      droppedEventsThisBlock++;
      return false;
    }

    buffer[numEvents] = event;
    numEvents++;

    if (numEvents > highWaterMark) {
      highWaterMark = numEvents;
    }

    return true;
  }

  void clear() {
    numEvents = 0;
    overflowedThisBlock = false;
    droppedEventsThisBlock = 0;
  }

  const LiveEvent& getEvent(size_t index) const {
    return buffer[index];
  }

  size_t getNumEvents() const {
    return numEvents;
  }

  size_t getSize() const {
    return capacity;
  }

  bool didOverflowThisBlock() const {
    return overflowedThisBlock;
  }

  size_t getDroppedEventsThisBlock() const {
    return droppedEventsThisBlock;
  }

  size_t getHighWaterMark() const {
    return highWaterMark;
  }

  size_t getTimesGrown() const {
    return timesGrown;
  }
};

} // namespace anthem
