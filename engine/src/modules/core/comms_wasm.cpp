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

#include "comms_wasm.h"

AnthemCommsWasm::AnthemCommsWasm() : AnthemComms()/*, socketThread()*/ {
  juce::Logger::writeToLog("AnthemCommsWasm initialized.");
}

void AnthemCommsWasm::init() {
  // Nothing to do here yet
  juce::Logger::writeToLog("AnthemCommsWasm init called.");
}

void AnthemCommsWasm::send(std::string& message) {
  juce::MemoryBlock messageBlock(message.data(), message.size());
  sendRaw(messageBlock);
}

void AnthemCommsWasm::sendRaw(juce::MemoryBlock& message) {
  // No-op for now
  juce::Logger::writeToLog("AnthemCommsWasm sendRaw called, currently no-op");
}

void AnthemCommsWasm::closeSocketThread() {
  // No-op for now
  juce::Logger::writeToLog("AnthemCommsWasm closeSocketThread called, currently no-op");
}

#endif // #ifdef __EMSCRIPTEN__
