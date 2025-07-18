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

#include "command_handler.h"

#include <rfl/json.hpp>
#include <rfl.hpp>

#include "modules/core/visualization/visualization_broker.h"

#include "modules/command_handlers/model_sync_command_handler.h"
#include "modules/command_handlers/processing_graph_command_handler.h"
#include "modules/command_handlers/sequencer_command_handler.h"
#include "modules/command_handlers/visualization_command_handler.h"

void HeartbeatThread::run() {
  while (!threadShouldExit()) {
    // Sleep for 10 seconds
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

void CommandHandler::addCommandBytesToQueue(juce::MemoryBlock bytes) {
  juce::ScopedLock lock(commandQueueMutex);
  commandQueue.push(std::move(bytes));

  juce::MessageManager::callAsync([this]() {
    processNextCommand();
  });
}

void CommandHandler::processNextCommand() {
  juce::MemoryBlock command;

  {
    juce::ScopedLock lock(commandQueueMutex);

    if (commandQueue.empty()) {
      jassertfalse;
    }

    command = std::move(commandQueue.front());
    commandQueue.pop();
  }

  heartbeatThread.gotMessageSinceLastHeartbeatCheck = true;

  // Convert the command bytes to a string
  std::string commandStr(static_cast<const char*>(command.getData()), command.getSize());

  // std::cout << "Received command: " << commandStr << std::endl;

  auto requestWrapped = rfl::json::read<Request>(commandStr);

  if (!requestWrapped.has_value()) {
    juce::Logger::writeToLog("Failed to parse command: " + commandStr);
    return;
  }

  auto request = std::move(requestWrapped.value());

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

    Anthem::getInstance().comms.send(responseStr);
  }

  if (isExit) {
    juce::Logger::writeToLog("Engine received exit command. Exiting...");

    VisualizationBroker::getInstance().dispose();

    Anthem::getInstance().comms.closeSocketThread();
    juce::JUCEApplication::quit();
  }
}
