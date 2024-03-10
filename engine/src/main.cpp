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

#include <boost/interprocess/ipc/message_queue.hpp>

#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <cstdlib>
#include <mutex>
#include <condition_variable>

#include "messages_generated.h"
#include "open_message_queue.h"
#include "anthem.h"
#include "./command_handlers/project_command_handler.h"

using namespace boost::interprocess;

Anthem* anthem;

std::unique_ptr<message_queue> mqToUi;
std::unique_ptr<message_queue> mqFromUi;

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
      case Command_GetMasterOutputNodeId:
      case Command_AddProcessor:
      case Command_DeleteArrangement:
      case Command_GetProcessors:
      case Command_ConnectProcessors:
      case Command_CompileProcessingGraph:
      case Command_LiveNoteOn:
      case Command_LiveNoteOff:
        response = handleProjectCommand(request, builder, anthem);
        break;
      default: {
        std::cerr << "Received unknown command (id: " << static_cast<int>(command_type) << ")" << std::endl;
        break;
      }
    }

    if (response.has_value()) {
      builder.Finish(response.value());

      auto receive_buffer_ptr = builder.GetBufferPointer();
      auto buffer_size = builder.GetSize();

      // Send the response to the UI
      mqToUi->send(receive_buffer_ptr, buffer_size, 0);
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
  auto idStr = juce::JUCEApplication::getCommandLineParameters();

  if (idStr.length() == 0) {
    std::cerr << "Engine ID was not provided. Exiting..." << std::endl;
    juce::JUCEApplication::quit();
    return;
  }

  auto mqToUiName = "engine-to-ui-" + idStr;
  auto mqFromUiName = "ui-to-engine-" + idStr;

  std::cout << "Creating engine-to-ui message queue..." << std::endl;

  // Create a message_queue.
  mqToUi = std::unique_ptr<message_queue>(
    new message_queue(
      create_only,
      mqToUiName.toStdString().c_str(),

      // 100 messages can be in the queue at once
      100,

      // Each message can be a maximum of 65536 bytes (?) long
      65536));

  std::cout << "Opening ui-to-engine message queue..." << std::endl;
  mqFromUi = openMessageQueue(mqFromUiName.toStdString().c_str());
  std::cout << "Opened successfully." << std::endl;

  std::cout << "Starting heartbeat thread..." << std::endl;
  std::thread heartbeat_thread(heartbeat);

  uint8_t buffer[65536];

  std::cout << "Anthem engine started successfully. Listening for messages from UI..." << std::endl;
  while (true) {
    std::unique_lock<std::mutex> lock(messageHandledMutex);
    messageHandledCv.wait(lock, []() { return canWriteToBuffer; });
    canWriteToBuffer = false;

    std::size_t received_size;
    unsigned int priority;

    mqFromUi->receive(buffer, sizeof(buffer), received_size, priority);

    // Create a const pointer to the start of the buffer
    const void* send_buffer_ptr = static_cast<const void*>(buffer);

    // Get the root of the buffer
    auto request = flatbuffers::GetRoot<Request>(send_buffer_ptr);

    messageListener.postMessage(new CommandMessage(request));
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
