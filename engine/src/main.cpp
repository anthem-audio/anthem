/*
  Copyright (C) 2023 - 2024 Joshua Wade

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

#define JUCE_CHECK_MEMORY_LEAKS 0

#include <juce_events/juce_events.h>
#include <juce_core/juce_core.h>
#include <juce_audio_devices/juce_audio_devices.h>

#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <cstdlib>
#include <mutex>
#include <condition_variable>

#include "messages_generated.h"
#include "anthem.h"
#include "./command_handlers/processing_graph_command_handler.h"
#include "./command_handlers/processor_command_handler.h"
#include "./command_handlers/project_command_handler.h"

Anthem* anthem;

juce::StreamingSocket socketToUi;

std::mutex socketInUseMutex;

volatile bool heartbeatOccurred = true;

// Checks for a recent heartbeat every 10 seconds. If there wasn't one, we exit
// the application.
void heartbeat() {
  while (true) {
    if (!heartbeatOccurred) {
      juce::MessageManager::callAsync([]() {
        juce::JUCEApplication::getInstance()->systemRequestedQuit();
      });
    }

    heartbeatOccurred = false;

    std::this_thread::sleep_for(std::chrono::seconds(10));
  }
}

// When we send a message to the main thread, these allow the message thread to
// wait until the main thread is done reading from the message buffer before
// fetching a new message.
std::mutex messageHandledMutex;
std::condition_variable messageHandledCv;
volatile bool canWriteToBuffer = true;

class CommandMessage : public juce::Message
{
public:
  CommandMessage(const Request* request) {
    this->request = request;
  }

  const Request* request;
};

class CommandMessageListener : public juce::MessageListener
{
public:
  void handleMessage(const juce::Message& message) override {
    const CommandMessage& command = dynamic_cast<const CommandMessage&>(message);

    auto request = command.request;

    // Create flatbuffers builder
    auto builder = flatbuffers::FlatBufferBuilder();

    flatbuffers::Offset<void> return_value_offset;

    // Access the data in the buffer
    auto command_type = request->command_type();
    bool isExit = false;
    std::optional<flatbuffers::Offset<Response>> response;
    switch (command_type) {
      case Command_Exit: {
        auto exitReply = CreateExitReply(builder);
        auto exitReplyOffset = exitReply.Union();
        response = std::optional(
          CreateResponse(builder, request->id(), ReturnValue_ExitReply, exitReplyOffset)
        );
        isExit = true;
        break;
      }
      case Command_Heartbeat: {
        heartbeatOccurred = true;
        auto heartbeatReply = CreateHeartbeatReply(builder);
        auto heartbeatReplyOffset = heartbeatReply.Union();
        response = std::optional(
          CreateResponse(builder, request->id(), ReturnValue_HeartbeatReply, heartbeatReplyOffset)
        );
        break;
      }
      case Command_AddArrangement:
      case Command_DeleteArrangement:
      case Command_LiveNoteOn:
      case Command_LiveNoteOff:
        response = handleProjectCommand(request, builder, anthem);
        break;
      case Command_GetMasterOutputNodeId:
      case Command_AddProcessor:
      case Command_RemoveProcessor:
      case Command_GetProcessors:
      case Command_ConnectProcessors:
      case Command_DisconnectProcessors:
      case Command_CompileProcessingGraph:
      case Command_GetProcessorPorts:
        response = handleProcessingGraphCommand(request, builder, anthem);
        break;
      case Command_SetParameter:
        response = handleProcessorCommand(request, builder, anthem);
        break;
      default: {
        std::cerr << "Received unknown command (id: " << static_cast<int>(command_type) << ")" << std::endl;
        break;
      }
    }

    if (response.has_value()) {
      builder.Finish(response.value());

      auto receiveBufferPtr = builder.GetBufferPointer();
      auto bufferSize = builder.GetSize();

      // Write the message length to the socket
      auto bufferSize64 = static_cast<uint64_t>(bufferSize);

      // Create an array to hold the bytes of the id
      unsigned char bufferSizeBytes[sizeof(bufferSize64)];

      // Copy the bytes of bufferSize64 into bufferSizeBytes
      std::memcpy(bufferSizeBytes, &bufferSize64, sizeof(bufferSize64));

      std::unique_lock<std::mutex> socketLock(socketInUseMutex);

      socketToUi.write(bufferSizeBytes, sizeof(uint64_t));

      // Write the message to the socket
      socketToUi.write(receiveBufferPtr, bufferSize);

      socketLock.unlock();
    }

    if (isExit) {
      std::cout << "Engine received exit message. Shutting down..." << std::endl;
      juce::JUCEApplication::quit();
    } else {
      canWriteToBuffer = true;
      messageHandledCv.notify_one();
    }
  }
};

std::thread messageLoopThread;

// Main loop that listens for messages from the UI and responds to them
void messageLoop(CommandMessageListener& messageListener) {
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

  std::cout << "Opening socket connection to UI at port " << portStr << "..." << std::endl;
  auto success = socketToUi.connect("::1", std::stoi(portStr.toStdString()));
  if (!success) {
    std::cerr << "Socket failed to start. Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }
  std::cout << "Opened successfully." << std::endl;

  std::cout << "Sending ID back to UI as first message..." << std::endl;

  std::this_thread::sleep_for(std::chrono::seconds(1));

  auto id = std::stoull(idStr.toStdString());

  // Create an array to hold the bytes of the id
  unsigned char idBytes[sizeof(id)];

  // Copy the bytes of id into idBytes
  std::memcpy(idBytes, &id, sizeof(id));

  auto socketWriteResult = socketToUi.write(idBytes, sizeof(unsigned long long));
  if (socketWriteResult <= 0) {
    std::cerr << "Socket failed to write. Result is: " << socketWriteResult << ". Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  std::cout << "Done." << std::endl;

  std::cout << "Starting heartbeat thread..." << std::endl;
  std::thread heartbeat_thread(heartbeat);

  uint8_t tempBuffer[4096];
  juce::MemoryBlock messageBuffer;

  std::cout << "Anthem engine started successfully. Listening for messages from UI..." << std::endl;
  while (true) {
    std::unique_lock<std::mutex> socketLock(socketInUseMutex);

    // Get any available data from the socket
    auto bytesRead = socketToUi.read(tempBuffer, sizeof(tempBuffer), false);

    socketLock.unlock();

    // Append the data to our memory block
    messageBuffer.append(tempBuffer, static_cast<size_t>(bytesRead));

    // Process messages in buffer
    while (messageBuffer.getSize() >= sizeof(uint64_t)) {
      const uint64_t* messageLengthPtr = static_cast<const uint64_t*>(messageBuffer.getData());
      uint64_t messageLength = *messageLengthPtr;

      if (messageBuffer.getSize() >= sizeof(uint64_t) + messageLength)
      {
        // Extract and print the message
        const uint8_t* messagePtr = static_cast<const uint8_t*>(messageBuffer.getData()) + sizeof(uint64_t);

        if (reinterpret_cast<uintptr_t>(messagePtr) % 4 != 0) {
          std::cerr << "Buffer is not properly aligned!" << std::endl;
          return;
        }

        // Convert to a flatbuffers object
        auto request = flatbuffers::GetRoot<Request>(messagePtr);

        // Set the "can write" flag to false. The message handler will set this
        // to true after it's done reading the message buffer.
        canWriteToBuffer = false;

        // Send to the main thread
        messageListener.postMessage(new CommandMessage(request));

        // Wait for the message to be handled before cleaning up the memory
        std::unique_lock<std::mutex> lock(messageHandledMutex);
        messageHandledCv.wait(lock, []() { return canWriteToBuffer; });

        // Remove the processed message from the buffer
        messageBuffer.removeSection(0, sizeof(uint64_t) + messageLength);
      } else {
        // Not enough data for a complete message yet
        break;
      }
    }
  }
}

class AnthemEngineApplication : public juce::JUCEApplicationBase, private juce::ChangeListener
{
private:
  std::unique_ptr<std::thread> message_loop_thread;
  CommandMessageListener commandMessageListener;

  void changeListenerCallback(juce::ChangeBroadcaster */*source*/) override
  {
    std::cout << "change detected" << std::endl;
  }

public:
  AnthemEngineApplication() {}

  const juce::String getApplicationName() override { return "JUCE_APPLICATION_NAME_STRING"; }
  const juce::String getApplicationVersion() override { return "0.0.1"; }

  bool moreThanOneInstanceAllowed() override { return true; }

  void anotherInstanceStarted(const juce::String &/*commandLineParameters*/) override {}
  void suspended() override {}
  void resumed() override {}
  void shutdown() override {}

  void systemRequestedQuit() override
  {
    setApplicationReturnValue(0);
    quit();
  }

  void unhandledException(const std::exception */*exception*/, const juce::String &/*sourceFilename*/,
              int /*lineNumber*/) override
  {
    // This might not work
  }

  void initialise(const juce::String &/*commandLineParameters*/) override
  {
                                // wow, C++ sure is weird
    const char * anthemSplash = R"V0G0N(
           ,++,
          /####\
         /##**##\
        =##/  \##=              ,---.            ,--.  ,--.                       
      /##=/    \=##\           /  O  \ ,--,--, ,-'  '-.|  ,---.  ,---. ,--,--,--. 
     =##/   ..   \##=         |  .-.  ||      \'-.  .-'|  .-.  || .-. :|        | 
   /##=/   /##\   \=##\       |  | |  ||  ||  |  |  |  |  | |  |\   --.|  |  |  | 
  =##,    /####\    ,##=      `--' `--'`--''--'  `--'  `--' `--' `----'`--`--`--' 
.#####---*##/\##*---#####.
 *=#######*/  \*#######=*



)V0G0N";

    std::cout << anthemSplash;

    std::cout << "If you want to attach a debugger, you can do it now. Press enter to continue." << std::endl;
    std::cin.get();

    std::cout << "Starting Anthem engine..." << std::endl;
    anthem = new Anthem();

    // This starts the message loop in a thread. The message loop thread
    // communicates back to the main thread every time it receives a
    // message from the UI, and the main thread takes care of processing
    // the message.
    message_loop_thread = std::make_unique<std::thread>(messageLoop, std::ref(commandMessageListener));
    message_loop_thread->detach();
  }
};

START_JUCE_APPLICATION(AnthemEngineApplication);
