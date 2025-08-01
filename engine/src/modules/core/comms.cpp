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

#include "comms.h"

#include "modules/core/anthem.h"

AnthemSocketThread::AnthemSocketThread() : juce::Thread("AnthemSocketThread"), socket() {
  pendingHeader.setSize(HEADER_SIZE);
  pendingBytes.setSize(0);
  messageBuffer.setSize(0);

  if (socket.isConnected()) {
    juce::Logger::writeToLog("AnthemSocketThread initialized with an already connected socket.");
  } else {
    juce::Logger::writeToLog("AnthemSocketThread initialized with a disconnected socket.");
  }
  juce::Logger::writeToLog("AnthemSocketThread initialized.");
}

void AnthemSocketThread::run() {
  while (!threadShouldExit()) {
    // Try write

    bool didReadOrWrite = false;
    auto writeResult = writePendingBytes();
    if (writeResult < 0) {
      // Fatal error, kill the application
      juce::MessageManager::callAsync([]() {
        jassertfalse;
        juce::JUCEApplication::quit();
      });
      break;
    }

    if (writeResult > 0) {
      didReadOrWrite = true;
    }

    // Try read

    auto readReadyResult = socket.waitUntilReady(true, SOCKET_TIMEOUT_MS);
    if (readReadyResult < 0) {
      // Fatal error, kill the application
      juce::MessageManager::callAsync([]() {
        jassertfalse;
        juce::JUCEApplication::quit();
      });
      break;
    }

    if (readReadyResult == 0) {
      // No data available, continue
      std::this_thread::sleep_for(std::chrono::milliseconds(THREAD_SLEEP_MS));
      continue;
    }

    // Read data from the socket
    uint8_t buffer[4096];
    auto bytesRead = socket.read(buffer, sizeof(buffer), false);

    if (bytesRead < 0) {
      // Fatal error, kill the application
      juce::MessageManager::callAsync([]() {
        jassertfalse;
        juce::JUCEApplication::quit();
      });
      break;
    }

    if (bytesRead == 0) {
      // No data read, continue
      std::this_thread::sleep_for(std::chrono::milliseconds(THREAD_SLEEP_MS));
      continue;
    }

    messageBuffer.append(buffer, bytesRead);

    while (messageBuffer.getSize() >= sizeof(uint64_t)) {
      const uint64_t* messageLengthPtr = static_cast<const uint64_t*>(messageBuffer.getData());
      uint64_t messageLength = *messageLengthPtr;

      if (messageBuffer.getSize() >= sizeof(uint64_t) + messageLength) {
        processIncomingMessage(messageLength);
      } else {
        // Not enough data for a complete message yet
        break;
      }
    }

    if (!didReadOrWrite) {
      std::this_thread::sleep_for(std::chrono::milliseconds(THREAD_SLEEP_MS));
    }
  }
}

int AnthemSocketThread::writePendingBytes() {
  if (!pendingBytesReadyAndNotFinished && !messageQueueHasMessages()) {
    return 0; // Nothing to write
  }

  if (!pendingBytesReadyAndNotFinished) {
    prepareNextMessage();
  }

  auto result = socket.waitUntilReady(false, SOCKET_TIMEOUT_MS);

  if (result < 0) {
    jassertfalse;
    return -1; // Error state
  }

  if (result == 0) {
    return 1; // Timeout
  }

  if (writeIndex < HEADER_SIZE) {
    // Write the header
    auto bytesToWrite = HEADER_SIZE - writeIndex;
    auto bytesWritten = socket.write(((char *) pendingHeader.getData()) + writeIndex, bytesToWrite);
    if (bytesWritten < 0) {
      jassertfalse;
      return -1; // Error state
    }
    writeIndex += bytesWritten;
  }

  if (writeIndex < HEADER_SIZE) {
    return 1; // Still writing header
  }

  auto writeIndexInPendingBytes = writeIndex - HEADER_SIZE;
  auto bytesToWrite = pendingBytes.getSize() - writeIndexInPendingBytes;

  result = socket.waitUntilReady(false, SOCKET_TIMEOUT_MS);

  if (result < 0) {
    jassertfalse;
    return -1; // Error state
  }

  if (result == 0) {
    return 1; // Timeout
  }

  auto bytesWritten = socket.write(((char *) pendingBytes.getData()) + writeIndexInPendingBytes, bytesToWrite);
  if (bytesWritten < 0) {
    jassertfalse;
    return -1; // Error state
  }
  writeIndex += bytesWritten;

  // Check for completion
  if (writeIndex >= HEADER_SIZE + pendingBytes.getSize()) {
    pendingBytesReadyAndNotFinished = false;
  }

  return 1;
}

void AnthemSocketThread::processIncomingMessage(uint64_t messageLength) {
  const uint8_t* messagePtr = static_cast<const uint8_t*>(messageBuffer.getData()) + sizeof(uint64_t);

  juce::MemoryBlock messageBlock(messageLength, false);
  std::memcpy(messageBlock.getData(), messagePtr, messageLength);

  // Remove the processed message from the buffer
  messageBuffer.removeSection(0, sizeof(uint64_t) + messageLength);

  Anthem::getInstance().commandHandler.addCommandBytesToQueue(std::move(messageBlock));
}

bool AnthemSocketThread::messageQueueHasMessages() {
  juce::ScopedLock lock(queueLock);
  return !messageQueue.empty();
}

void AnthemSocketThread::prepareNextMessage() {
  // Narrower block scope so that we unlock as soon as possible
  {
    juce::ScopedLock lock(queueLock);

    if (messageQueue.empty()) {
      pendingBytesReadyAndNotFinished = false;
      return;
    }

    // Pull the next message body
    pendingBytes = std::move(messageQueue.front());
    messageQueue.pop();
  }

  // Prepare the header, which is the size of the message
  uint64_t messageSize = pendingBytes.getSize();
  void* headerData = pendingHeader.getData();
  std::memcpy(headerData, &messageSize, HEADER_SIZE);

  // Reset state
  writeIndex = 0;
  pendingBytesReadyAndNotFinished = true;
}

void AnthemComms::init() {
  auto parameters = juce::JUCEApplication::getCommandLineParameters();

  auto spaceIndex = parameters.indexOfChar(' ');

  if (spaceIndex == -1) {
    std::cerr << "Invalid command line args: " << parameters << " - Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  auto portStr = parameters.substring(0, spaceIndex);
  auto idStr = parameters.substring(spaceIndex + 1);

  if (portStr.length() == 0) {
    std::cerr << "Port was not provided. Args: " << parameters << " - Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  if (idStr.length() == 0) {
    std::cerr << "Engine ID was not provided. Args: " << parameters << " - Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  juce::Logger::writeToLog("Opening socket connection to UI at port " + portStr + "...");

  int port = std::stoi(portStr.toStdString());

  auto success = socketThread.socket.connect("::1", port);
  socketThread.socket.waitUntilReady(false, 1000); // should be unnecessary?
  if (!success) {
    std::cerr << "Socket failed to start. Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }
  juce::Logger::writeToLog("Opened successfully.");

  juce::Logger::writeToLog("Sending ID back to UI as first message: " + idStr);

  auto id = std::stoull(idStr.toStdString());
  juce::MemoryBlock idBlock(sizeof(int64_t));
  std::memcpy(idBlock.getData(), &id, sizeof(int64_t));
  socketThread.messageQueue.push(std::move(idBlock));

  socketThread.startThread();
}

void AnthemComms::sendRaw(juce::MemoryBlock& message) {
  juce::ScopedLock lock(socketThread.queueLock);
  socketThread.messageQueue.push(message);
}

void AnthemComms::send(std::string& message) {
  juce::MemoryBlock messageBlock(message.data(), message.size());
  sendRaw(messageBlock);
}

void AnthemComms::closeSocketThread() {
  int i = 0;
  while (socketThread.messageQueueHasMessages()) {
    juce::Thread::sleep(100);
    i++;
    if (i > 100) {
      juce::Logger::writeToLog("Socket thread is taking too long to close. Forcing exit.");
      break;
    }
  }

  socketThread.stopThread(1000);
}
