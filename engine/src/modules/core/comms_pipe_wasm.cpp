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

#include "comms_pipe_wasm.h"

int AnthemPipeWasm::connect(juce::String address, int port, int timeoutMs) {
  isConnectedFlag = true;
  return 1;
}

int AnthemPipeWasm::waitUntilReady(bool forRead, int timeoutMs) {
  return 1; // always ready
}

int AnthemPipeWasm::read(void* destBuffer, int maxBytesToRead, bool shouldBlock) {
  int bytesWritten = 0;

  while (bytesWritten < maxBytesToRead) {
    uint8_t byte;
    if (!readBuffer.tryDequeue(byte)) {
      break;
    }
    ((uint8_t*)destBuffer)[bytesWritten] = byte;
    bytesWritten++;
  }
  
  return bytesWritten;
}

int AnthemPipeWasm::write(const void* sourceBuffer, int numBytesToWrite) {
  for (int i = 0; i < numBytesToWrite; i++) {
    if (!writeBuffer.tryEnqueue(((const uint8_t*)sourceBuffer)[i])) {
      return i; // Return number of bytes successfully written
    }
  }

  return numBytesToWrite;
}

bool AnthemPipeWasm::isConnected() const {
  return isConnectedFlag;
}

#endif // #ifdef __EMSCRIPTEN__
