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

// This class implements a "pipe" whose interface is the same as
// juce::StreamingSocket. This allows our comms layer to use the same interface
// for both desktop (using a real socket to the UI process) and WebAssembly
// (using this pipe).

#pragma once

// #ifdef __EMSCRIPTEN__

#include "emscripten.h"

#include <juce_core/juce_core.h>

#include "comms_ring_buffer_wasm.h"

class AnthemPipeWasm {
private:
  bool isConnectedFlag = false;

  CommsRingBufferWasm readBuffer;
  CommsRingBufferWasm writeBuffer;

  bool initMemory();
public:
  AnthemPipeWasm() : readBuffer(65536), writeBuffer(65536) {
    std::cout << "AnthemPipeWasm constructor called." << std::endl;
  }
  ~AnthemPipeWasm() {
    std::cout << "AnthemPipeWasm destructor called." << std::endl;
  }

  int connect(juce::String address, int port, int timeoutMs = 0);
  
  int waitUntilReady(bool forRead, int timeoutMs = 0);

  int read(void* destBuffer, int maxBytesToRead, bool shouldBlock);

  int write(const void* sourceBuffer, int numBytesToWrite);

  bool isConnected() const;
};

// #endif // #ifdef __EMSCRIPTEN__
