/*
  Copyright (C) 2024 Joshua Wade

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

#include <stdexcept>

#include "arena_allocator.h"
#include "anthem_processor_event.h"

class AnthemEventBuffer {
  // ALlocator for this buffer. This allocator maintains a huge buffer of memory
  // that can be used to reallocate our buffer if it gets too big, without
  // having to allocate from the OS, which allows this class to be real-time
  // safe.
  //
  // This allocator is owned by the graph compilation result, and so should be
  // deallocated there.
  ArenaBufferAllocator<AnthemProcessorEvent>* allocator;

  // Deallocation pointer for the buffer. This is used to deallocate the buffer
  // when the buffer is no longer needed.
  void* deallocatePtr;

  // The buffer of events.
  AnthemProcessorEvent* buffer;

  // The size of the buffer.
  size_t size;

  // The number of events in the buffer.
  size_t numEvents;

public:
  // Constructor
  AnthemEventBuffer(ArenaBufferAllocator<AnthemProcessorEvent>* allocator, size_t size) : allocator(allocator), size(size), numEvents(0), deallocatePtr(nullptr) {
    auto result = allocator->allocate(size);

    if (!result.success) {
      throw std::runtime_error("Failed to allocate buffer for event buffer.");
    }

    buffer = result.memoryStart;
    deallocatePtr = result.deallocatePtr;
  }

  // Destructor
  ~AnthemEventBuffer() {
    allocator->deallocate(deallocatePtr);
  }

  // Reallocation function. This function will reallocate the buffer to a new
  // size. This function will copy the old buffer into the new buffer.
  void reallocate(size_t newSize) {
    auto result = allocator->allocate(newSize);

    if (!result.success) {
      throw std::runtime_error("Failed to reallocate buffer for event buffer.");
    }

    // Copy the old buffer into the new buffer.
    for (size_t i = 0; i < numEvents; i++) {
      result.memoryStart[i] = buffer[i];
    }

    // Deallocate the old buffer.
    allocator->deallocate(deallocatePtr);

    // Set the new buffer.
    buffer = result.memoryStart;
    deallocatePtr = result.deallocatePtr;
    size = newSize;
  }

  // Adds an event to the buffer.
  void addEvent(AnthemProcessorEvent event) {
    if (numEvents >= size) {
      reallocate(size * 2);
    }

    buffer[numEvents] = event;
    numEvents++;
  }

  // Clears the buffer.
  void clear() {
    numEvents = 0;
  }

  // Returns the event at the given index.
  AnthemProcessorEvent& getEvent(size_t index) {
    return buffer[index];
  }

  // Returns the number of events in the buffer.
  size_t getNumEvents() {
    return numEvents;
  }

  // Returns the size of the buffer.
  size_t getSize() {
    return size;
  }
};
