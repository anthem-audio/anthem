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

#include <queue>
#include <string>

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <juce_gui_basics/juce_gui_basics.h>

class Anthem;

class AnthemSocketThread : public juce::Thread {
  friend class AnthemComms;

private:
  static constexpr size_t HEADER_SIZE = sizeof(uint64_t);

  // This is set so low because we care about responsiveness going both
  // directions. The UI may be sending live note events from UI actions which
  // should be handled as soon as possible, and the engine will be sending
  // visualization updates which optimally will occur more often than the
  // framerate of the UI and should occur regularly. If either read or write
  // blocks for very long, it will hold up communication in both directions,
  // which is something we want to avoid.
  static constexpr int SOCKET_TIMEOUT_MS = 2;

  static constexpr int THREAD_SLEEP_MS = 1;

  juce::StreamingSocket socket;

  // Tries writing the current message to the socket. This may complete without
  // sending everything.
  //
  // Returns -1 if there was a fatal error, 0 if nothing was available to write,
  // and 1 if something was written or if there was a timeout but there is still
  // more data to write.
  int writePendingBytes();

  // Fields for tracking write state

  juce::MemoryBlock pendingHeader;
  juce::MemoryBlock pendingBytes;
  
  // The header is 8 bytes. This indexes into (header, pendingBytes). If the
  // index is 0 - 7, we are reading from the header. If it is 8 or more, we are
  // reading from pendingBytes. For example if writeIndex is 8, we are reading from
  // pendingBytes[0]. If writeIndex is 9, we are reading from pendingBytes[1], and
  // so on.
  size_t writeIndex = 0;
  bool pendingBytesReadyAndNotFinished = false;

  // Fields for tracking read state

  juce::MemoryBlock messageBuffer;

  bool messageQueueHasMessages();
  void prepareNextMessage();
  
  void processIncomingMessage(uint64_t messageLength);

protected:
  std::queue<juce::MemoryBlock> messageQueue;
  juce::CriticalSection queueLock;

public:
  AnthemSocketThread();

  void run() override;
};

// This class manages the socket communication with the UI.
class AnthemComms {
private:
  AnthemSocketThread socketThread;
public:
  AnthemComms() : socketThread() {
    juce::Logger::writeToLog("AnthemComms initialized.");
  }
  ~AnthemComms() = default;

  void init();

  void send(std::string& message);
  void sendRaw(juce::MemoryBlock& message);

  // Stops the socket thread, after all messages have been sent.
  //
  // THIS IS BLOCKING. This should only be called on application exit, when
  // there's definitely no more data to send or receive.
  void closeSocketThread();
};
