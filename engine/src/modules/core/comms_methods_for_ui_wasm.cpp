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

#ifdef __EMSCRIPTEN__

#include "comms_methods_for_ui_wasm.h"

#include <juce_core/juce_core.h>

#include "anthem.h"

std::atomic<bool> commsReady(false);

// This will be false on the first run, at which point it will send an async
// query to the main thread to check if comms is ready. The intended use is
// that this will be polled from the UI side until it returns true.
extern "C" bool isCommsReady(int arg) {
  juce::MessageManager::callAsync([]() {
    if (Anthem::hasInstance()) {
      commsReady.store(true);
    } else {
      commsReady.store(false);
    }
  });

  return commsReady.load();
}

// These must only be called if isCommsReady() returns true.

// getWriteBuffer* will return pointers to the respective fields of the
// readBuffer, and getReadBuffer* will return pointers to the respective fields
// of the writeBuffer. This is because, from the perspective of the UI, our read
// buffer is the UI's write buffer and our write buffer is the UI's read buffer.

extern "C" void* getWriteBufferHeadPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().readBuffer.head;
}

extern "C" void* getWriteBufferTailPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().readBuffer.tail;
}

extern "C" uint32_t getWriteBufferCapacity() {
  return Anthem::getInstance().comms.getSocketOrPipe().readBuffer.capacity;
}

extern "C" uint32_t getWriteBufferMask() {
  return Anthem::getInstance().comms.getSocketOrPipe().readBuffer.mask;
}

extern "C" void* getWriteBufferDataPtr() {
  return Anthem::getInstance().comms.getSocketOrPipe().readBuffer.buffer.getData();
}

extern "C" void* getWriteBufferTicketPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().readBuffer.ticket;
}

extern "C" void* getReadBufferHeadPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.head;
}

extern "C" void* getReadBufferTailPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.tail;
}

extern "C" uint32_t getReadBufferCapacity() {
  return Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.capacity;
}

extern "C" uint32_t getReadBufferMask() {
  return Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.mask;
}

extern "C" void* getReadBufferDataPtr() {
  return Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.buffer.getData();
}

extern "C" void* getReadBufferTicketPtr() {
  return (void*) &Anthem::getInstance().comms.getSocketOrPipe().writeBuffer.ticket;
}

#endif // #ifdef __EMSCRIPTEN__
