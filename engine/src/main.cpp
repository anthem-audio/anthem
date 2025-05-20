/*
  Copyright (C) 2023 - 2025 Joshua Wade

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
#include <optional>

#include <rfl/json.hpp>
#include <rfl.hpp>

#include "console_logger.h"

#include "modules/core/anthem.h"
#include "./command_handlers/model_sync_command_handler.h"
#include "./command_handlers/processing_graph_command_handler.h"
#include "./command_handlers/sequencer_command_handler.h"
#include "./command_handlers/visualization_command_handler.h"

#include "comms.h"

#include "messages/messages.h"

volatile bool heartbeatOccurred = true;

// Checks for a recent heartbeat every 10 seconds. If there wasn't one, we exit
// the application.
void heartbeat() {
  while (true) {
    if (!heartbeatOccurred) {
      juce::MessageManager::callAsync([]() {
        juce::JUCEApplication::quit();
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
  Request request;

  CommandMessage(Request request) : request(request) {}
};

class CommandMessageListener : public juce::MessageListener
{
public:
  void handleMessage(const juce::Message& message) override {
    const CommandMessage& command = dynamic_cast<const CommandMessage&>(message);

    auto request = command.request;

    bool isExit = false;

    std::optional<Response> response = std::nullopt;

    if (rfl::holds_alternative<Exit>(request.variant())) {
      auto& requestAsExit = rfl::get<Exit>(request.variant());

      auto exitReply = ExitReply{
        .responseBase = ResponseBase{
          .id = requestAsExit.requestBase.get().id
        }
      };

      response = std::optional(
        std::move(exitReply)
      );

      isExit = true;
    }

    else if (rfl::holds_alternative<Heartbeat>(request.variant())) {
      auto& requestAsHeartbeat = rfl::get<Heartbeat>(request.variant());

      auto heartbeatReply = HeartbeatReply{
        .responseBase = ResponseBase {
          .id = requestAsHeartbeat.requestBase.get().id
        }
      };

      response = std::optional(
        std::move(heartbeatReply)
      );

      heartbeatOccurred = true;
    }

    // Forward request to handlers

    bool didOverwriteResponse = false;
    
    auto handleModelSyncCommandResponse = handleModelSyncCommand(request);
    if (handleModelSyncCommandResponse.has_value()) {
      if (response.has_value()) {
        didOverwriteResponse = true;
      }
      response = std::move(handleModelSyncCommandResponse);
    }

    auto handleProcessingGraphCommandResponse = handleProcessingGraphCommand(request);
    if (handleProcessingGraphCommandResponse.has_value()) {
      if (response.has_value()) {
        didOverwriteResponse = true;
      }
      response = std::move(handleProcessingGraphCommandResponse);
    }

    auto handleSequencerCommandResponse = handleSequencerCommand(request);
    if (handleSequencerCommandResponse.has_value()) {
      if (response.has_value()) {
        didOverwriteResponse = true;
      }
      response = std::move(handleSequencerCommandResponse);
    }

    auto handleVisualizationCommandResponse = handleVisualizationCommand(request);
    if (handleVisualizationCommandResponse.has_value()) {
      if (response.has_value()) {
        didOverwriteResponse = true;
      }
      response = std::move(handleVisualizationCommandResponse);
    }

    // Warn if multiple handlers gave back a reply. This would indicate that a
    // command is being handled multiple times, which is probably a bug.

    if (didOverwriteResponse) {
      juce::Logger::writeToLog("Warning: Multiple command handlers tried to reply to a single command. Only the last reply will be sent back. This is probably a bug.");
    }

    if (response.has_value()) {
      // Serialize the response to a string
      auto responseStr = rfl::json::write(response.value());

      // Send the response back to the UI
      auto socketWriteResult = AnthemComms::getInstance().writeString(responseStr);
      if (socketWriteResult <= 0) {
        std::cerr << "Socket failed to write. Result is: " << socketWriteResult << ". Exiting..." << std::endl;
        juce::JUCEApplication::quit();
        return;
      }
    }

    if (isExit) {
      juce::Logger::writeToLog("Engine received exit message. Shutting down...");
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

  juce::Logger::writeToLog("Opening socket connection to UI at port " + portStr + "...");
  auto success = AnthemComms::getInstance().connect(std::stoi(portStr.toStdString()));
  if (!success) {
    std::cerr << "Socket failed to start. Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }
  juce::Logger::writeToLog("Opened successfully.");

  juce::Logger::writeToLog("Sending ID back to UI as first message...");

  auto id = std::stoull(idStr.toStdString());

  // Create an array to hold the bytes of the id
  unsigned char idBytes[sizeof(id)];

  // Copy the bytes of id into idBytes
  std::memcpy(idBytes, &id, sizeof(id));

  auto socketWriteResult = AnthemComms::getInstance().write(idBytes, sizeof(unsigned long long));
  if (socketWriteResult <= 0) {
    std::cerr << "Socket failed to write. Result is: " << socketWriteResult << ". Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  juce::Logger::writeToLog("Done.");

  juce::Logger::writeToLog("Starting heartbeat thread...");
  std::thread heartbeat_thread(heartbeat);

  uint8_t tempBuffer[4096];
  juce::MemoryBlock messageBuffer;

  int microsecondBackoff = 0;
  int microsecondBackoffMax = 5000;
  int microsecondBackoffIncrement = 100;

  juce::Logger::writeToLog("Anthem engine started successfully. Listening for messages from UI...");
  while (true) {
    // Get any available data from the socket
    auto bytesRead = AnthemComms::getInstance().read(tempBuffer, sizeof(tempBuffer), false);

    // Append the data to our memory block
    messageBuffer.append(tempBuffer, static_cast<size_t>(bytesRead));

    // If we didn't read any bytes, we should wait for a bit before trying again
    if (bytesRead <= 0) {
      std::this_thread::sleep_for(std::chrono::microseconds(microsecondBackoff));

      microsecondBackoff += microsecondBackoffIncrement;
      if (microsecondBackoff > microsecondBackoffMax) {
        microsecondBackoff = microsecondBackoffMax;
      }

      continue;
    }

    // Process messages in buffer
    while (messageBuffer.getSize() >= sizeof(uint64_t)) {
      const uint64_t* messageLengthPtr = static_cast<const uint64_t*>(messageBuffer.getData());
      uint64_t messageLength = *messageLengthPtr;

      if (messageBuffer.getSize() >= sizeof(uint64_t) + messageLength) {
        // Extract and print the message
        const uint8_t* messagePtr = static_cast<const uint8_t*>(messageBuffer.getData()) + sizeof(uint64_t);

        if (reinterpret_cast<uintptr_t>(messagePtr) % 4 != 0) {
          std::cerr << "Fatal: Buffer is not properly aligned!" << std::endl;
          juce::JUCEApplication::quit();
          return;
        }

        // Convert message to a string
        std::string messageStr(reinterpret_cast<const char*>(messagePtr), messageLength);

        // std::cout << std::endl << "Received message: " << std::endl << messageStr << std::endl;

        // Convert to a Request object
        auto requestWrapped = rfl::json::read<Request>(messageStr);

        // Try to unwrap the request
        if (requestWrapped.error()) {
          std::cerr << "Failed to parse request: " << messageStr << std::endl;
          return;
        }

        // Set the "can write" flag to false. The message handler will set this
        // to true after it's done reading the message buffer.
        canWriteToBuffer = false;

        // Send to the main thread
        messageListener.postMessage(new CommandMessage(std::move(requestWrapped.value())));

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
    // juce::Logger::writeToLog("change detected");
  }

public:
  AnthemEngineApplication() {}

  const juce::String getApplicationName() override { return "JUCE_APPLICATION_NAME_STRING"; }
  const juce::String getApplicationVersion() override { return "0.0.1"; }

  bool moreThanOneInstanceAllowed() override { return true; }

  void anotherInstanceStarted(const juce::String &/*commandLineParameters*/) override {}
  void suspended() override {}
  void resumed() override {}
  void shutdown() override {
    // Destruct Anthem instance
    if (Anthem::hasInstance()) {
      Anthem::getInstance().shutdown();
      Anthem::cleanup();
    }
  }

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

  void initialise(const juce::String &commandLineParameters) override
  {
    // Remove this line to disable logging
    juce::Logger::setCurrentLogger(new ConsoleLogger());

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

    // #ifndef NDEBUG

    // juce::Logger::writeToLog("If you want to attach a debugger, you can do it now. Press enter to continue.");
    // std::cin.get();

    // #endif

    juce::Logger::writeToLog("Starting Anthem engine...");
    Anthem::getInstance().initialize();

    // This starts the message loop in a thread. The message loop thread
    // communicates back to the main thread every time it receives a
    // message from the UI, and the main thread takes care of processing
    // the message.
    message_loop_thread = std::make_unique<std::thread>(messageLoop, std::ref(commandMessageListener));
    message_loop_thread->detach();
  }
};

START_JUCE_APPLICATION(AnthemEngineApplication);
