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
#include <juce_events/juce_events.h>
#include <juce_gui_basics/juce_gui_basics.h>

#include "messages/messages.h"

class Anthem;

class HeartbeatThread : public juce::Thread {
public:
  volatile bool gotMessageSinceLastHeartbeatCheck = false;
  HeartbeatThread() : juce::Thread("HeartbeatThread") {}

  void run() override {
    while (!threadShouldExit()) {
      // Sleep for a second
      wait(10000);

      if (!gotMessageSinceLastHeartbeatCheck) {
        juce::Logger::writeToLog("No heartbeat or message received in the last 10 seconds. Exiting...");
        juce::MessageManager::callAsync([]() {
          juce::JUCEApplication::quit();
        });
      } else {
        gotMessageSinceLastHeartbeatCheck = false;
      }
    }
  }
};

class CommandHandler {
private:
  HeartbeatThread heartbeatThread;

  juce::CriticalSection commandQueueMutex;
  std::queue<juce::MemoryBlock> commandQueue;

public:
  void startHeartbeatThread() {
    // heartbeatThread.startThread();
  }

  // Called from the socket thread
  void addCommandBytesToQueue(juce::MemoryBlock bytes);

  // Must be called from the message thread
  void processNextCommand();
};
