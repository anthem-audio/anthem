/*
  Copyright (C) 2025 Joshua Wade

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

#ifdef __EMSCRIPTEN__

#include <bit>
#include <cstdint>

#include "emscripten.h"
#include "emscripten/atomic.h"

#include <juce_core/juce_core.h>

// This is a ring buffer for communicating with the UI. The UI is expected to
// hook into this memory and use it via the Atomics API. One side writes while
// the other reads.
class CommsRingBufferWasm {
public:
  uint32_t head;
  uint32_t tail;
  uint32_t capacity;
  uint32_t mask;
  int32_t ticket;

  juce::MemoryBlock buffer;

  CommsRingBufferWasm(uint32_t capacityPow2) :
    head(0),
    tail(0),
    capacity(capacityPow2),
    mask(capacityPow2 - 1),
    ticket(0)
  {
    buffer.setSize(capacity);
    buffer.fillWith(0);
  }

  uint32_t size() const {
    uint32_t currentHead = emscripten_atomic_load_u32((uint32_t*)&head);
    uint32_t currentTail = emscripten_atomic_load_u32((uint32_t*)&tail);
    return (currentHead - currentTail) & mask;
  }

  bool tryEnqueue(uint8_t value) {
    incrementTicket();

    uint32_t currentHead = emscripten_atomic_load_u32((uint32_t*)&head);
    uint32_t currentTail = emscripten_atomic_load_u32((uint32_t*)&tail);
    if (((currentHead + 1) & mask) == (currentTail & mask)) {
      // Full
      return false;
    }

    uint32_t nextHead = (currentHead + 1) & mask;
    uint8_t* bufferPtr = static_cast<uint8_t*>(buffer.getData());
    emscripten_atomic_store_u8((uint8_t*)&bufferPtr[currentHead], value);
    emscripten_atomic_store_u32((uint32_t*)&head, nextHead);

    notifyTicketChange();

    return true;
  }

  bool tryDequeue(uint8_t& value) {
    uint32_t currentHead = emscripten_atomic_load_u32((uint32_t*)&head);
    uint32_t currentTail = emscripten_atomic_load_u32((uint32_t*)&tail);
    if ((currentHead & mask) == (currentTail & mask)) {
      // Empty
      return false;
    }

    uint32_t nextTail = (currentTail + 1) & mask;
    uint8_t* bufferPtr = static_cast<uint8_t*>(buffer.getData());
    value = emscripten_atomic_load_u8((uint8_t*)&bufferPtr[currentTail]);
    emscripten_atomic_store_u32((uint32_t*)&tail, nextTail);
    return true;
  }

  int32_t getTicketValue() const {
    return std::bit_cast<int32_t>(emscripten_atomic_load_u32((uint32_t*)&ticket));
  }

  void waitForTicketSignal(int32_t lastSeenTicket) const {
    emscripten_atomic_wait_u32((uint32_t*)&ticket, std::bit_cast<uint32_t>(lastSeenTicket), -1);
  }

  void incrementTicket() {
    emscripten_atomic_add_u32(&ticket, 1);
  }

  void notifyTicketChange() {
    emscripten_atomic_notify(&ticket, 1);
  }
};

#endif // #ifdef __EMSCRIPTEN__
