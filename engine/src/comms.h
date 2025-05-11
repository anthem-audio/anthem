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

#include <mutex>

#include <thread>
#include <chrono>

// This file contains socket communication utilities for communicating with the
// UI. Non-realtime modules can import this file and use it to send messages to
// the UI.

class AnthemComms {
private:
  juce::StreamingSocket socketToUi;
  std::mutex socketInUseMutex;

  // Writes the size of the upcoming message to the socket. The UI expects the
  // expected size of each message to be sent before the message itself.
  int writeMessageSize(uint64_t size) {
    uint64_t size64 = size;
    uint8_t sizeBytes[sizeof(uint64_t)];
    std::memcpy(sizeBytes, &size64, sizeof(size64));
    return socketToUi.write(sizeBytes, sizeof(uint64_t));
  }

public:
  // Constructor
  AnthemComms() = default;

  // Destructor
  ~AnthemComms() = default;

  // Deleted copy constructor and assignment operator
  AnthemComms(const AnthemComms&) = delete;
  AnthemComms& operator=(const AnthemComms&) = delete;

  // Deleted move constructor and assignment operator
  AnthemComms(AnthemComms&&) = delete;
  AnthemComms& operator=(AnthemComms&&) = delete;

  // Connect to the UI socket
  bool connect(int port) {
    bool ok = socketToUi.connect("::1", port);
    socketToUi.waitUntilReady(false, 1000);
    return ok;
  }

  // Read from the socket
  int read(void* buffer, int size, bool waitForData = true) {
    std::lock_guard<std::mutex> socketLock(socketInUseMutex);
    return socketToUi.read(buffer, size, waitForData);
  }

  // Write raw bytes to the socket.
  int write(const void* buffer, int size) {
    std::lock_guard<std::mutex> socketLock(socketInUseMutex);
    return socketToUi.write(buffer, size);
  }

  // Write a string to the UI. This will first write the size of the string, and
  // then the string itself.
  int writeString(const std::string& str) {
    std::lock_guard<std::mutex> socketLock(socketInUseMutex);
    auto sizeResult = writeMessageSize(str.size());
    if (sizeResult < 0) {
      return sizeResult;
    }
    return socketToUi.write(str.c_str(), str.size());
  }

  // Singleton instance
  static AnthemComms& getInstance() {
    static AnthemComms instance;
    return instance;
  }
};
