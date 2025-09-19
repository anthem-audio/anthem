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

// #ifdef __EMSCRIPTEN__

#include "comms_pipe_wasm.h"

bool AnthemPipeWasm::initMemory() {
  readBuffer.tryEnqueue(1);
  readBuffer.tryEnqueue(2);
  writeBuffer.tryEnqueue(3);

  EM_ASM({
    console.log("AnthemPipeWasm readBuffer.size(): " + $0);
    console.log("AnthemPipeWasm writeBuffer.size(): " + $1);
  }, readBuffer.size(), writeBuffer.size());

  return true;
}

int AnthemPipeWasm::connect(juce::String address, int port, int timeoutMs) {
  initMemory();
  isConnectedFlag = true;
  return 0;
}

int AnthemPipeWasm::waitUntilReady(bool forRead, int timeoutMs) {
  return 0;
}

int AnthemPipeWasm::read(void* destBuffer, int maxBytesToRead, bool shouldBlock) {
  return 0;
}

int AnthemPipeWasm::write(const void* sourceBuffer, int numBytesToWrite) {
  return 0;
}

bool AnthemPipeWasm::isConnected() const {
  return isConnectedFlag;
}

// #endif // #ifdef __EMSCRIPTEN__
