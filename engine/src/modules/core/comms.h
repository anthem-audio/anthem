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

#include <juce_core/juce_core.h>

// This class manages communication with the UI.
class AnthemComms {
public:
  virtual void init() = 0;

  virtual void send(std::string& message) = 0;
  virtual void sendRaw(juce::MemoryBlock& message) = 0;

  // Stops the socket thread, after all messages have been sent.
  //
  // THIS IS BLOCKING. This should only be called on application exit, when
  // there's definitely no more data to send or receive.
  virtual void closeSocketThread() = 0;
};
