/*
  Copyright (C) 2025 - 2026 Joshua Wade

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

#include "modules/command_handlers/model_sync_command_handler.h"
#include "modules/command_handlers/processing_graph_command_handler.h"
#include "modules/command_handlers/sequencer_command_handler.h"
#include "modules/command_handlers/test_command_handler.h"
#include "modules/command_handlers/visualization_command_handler.h"
#include "modules/core/visualization/visualization_broker.h"

#include <rfl.hpp>
#include <rfl/json.hpp>

namespace anthem {

void HeartbeatThread::markMessageReceived() {
  gotMessageSinceLastHeartbeatCheck.store(true, std::memory_order_release);
}

void HeartbeatThread::run() {
  while (!threadShouldExit()) {
    // Sleep for 10 seconds
    wait(10000);

    if (!gotMessageSinceLastHeartbeatCheck.exchange(false, std::memory_order_acq_rel)) {
      juce::Logger::writeToLog(
          "No heartbeat or message received in the last 10 seconds. Exiting...");
      juce::MessageManager::callAsync([]() { juce::JUCEApplicationBase::quit(); });
    }
  }
}

void CommandHandler::startHeartbeatThread() {
  heartbeatThread.markMessageReceived();

  if (heartbeatThreadStarted) {
    return;
  }

  if (heartbeatThread.startThread()) {
    heartbeatThreadStarted = true;
  }
}

void CommandHandler::addCommandBytesToQueue(juce::MemoryBlock bytes) {
  juce::ScopedLock lock(commandQueueMutex);
  commandQueue.push(std::move(bytes));

  juce::MessageManager::callAsync([this]() { processNextCommand(); });
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

  heartbeatThread.markMessageReceived();

  // Convert the command bytes to a string
  std::string commandStr(static_cast<const char*>(command.getData()), command.getSize());
  // juce::Logger::writeToLog("Received command: " + juce::String(commandStr));

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

    auto exitReply =
        ExitReply{.responseBase = ResponseBase{.id = requestAsExit.requestBase.get().id}};

    response = std::optional(exitReply);

    isExit = true;
  }

  else if (rfl::holds_alternative<Heartbeat>(request.variant())) {
    auto& requestAsHeartbeat = rfl::get<Heartbeat>(request.variant());

// On desktop, we use a heartbeat to make sure that we have an active
// connection to the UI. While it shouldn't be possible due to how we start
// the engine from the Dart side, this is a last resort to make sure that we
// don't have a dangling engine process if something goes wrong.
//
// On web, we don't need this for two reasons: First, the web version is
// self-contained within the browser tab; if something is wrong, the tab can
// just be closed. Second, the connection between the UI and engine is much
// more direct on web, since the UI gets an object to puppeteer the engine
// directly, and the risk of losing track of the engine is much lower.
//
// The other reason this is removed on web is that when the browser loses
// focus, it may throttle or pause background tasks, which causes the UI to
// stop sending heartbeats. We could fix this, but since it's not needed on
// web anyway, it's simpler to just disable it.
#ifndef __EMSCRIPTEN__
    startHeartbeatThread();
#endif // #ifndef __EMSCRIPTEN__

    auto heartbeatReply =
        HeartbeatReply{.responseBase = ResponseBase{.id = requestAsHeartbeat.requestBase.get().id}};

    response = std::optional(heartbeatReply);
  }

  else if (rfl::holds_alternative<EngineReadyCheckRequest>(request.variant())) {
    auto& requestAsReadyCheck = rfl::get<EngineReadyCheckRequest>(request.variant());

    auto readyCheckReply = EngineReadyCheckResponse{.success = true,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = requestAsReadyCheck.requestBase.get().id}};

    response = std::optional(std::move(readyCheckReply));
  }

  else if (rfl::holds_alternative<StartAudioRequest>(request.variant())) {
    auto& requestAsStartAudio = rfl::get<StartAudioRequest>(request.variant());

    juce::Logger::writeToLog("Starting audio callback after model init...");
    auto audioConfig = Engine::getInstance().startAudioCallback();
    juce::Logger::writeToLog("startAudioCallback() returned.");

    auto startAudioReply = StartAudioResponse{.success = audioConfig != nullptr,
        .error = audioConfig != nullptr
                     ? std::nullopt
                     : std::optional<std::string>("Failed to initialize audio device."),
        .audioConfig = audioConfig != nullptr ? std::optional(audioConfig) : std::nullopt,
        .responseBase = ResponseBase{.id = requestAsStartAudio.requestBase.get().id}};

    response = std::optional(std::move(startAudioReply));
  }

  else if (rfl::holds_alternative<StopAudioRequest>(request.variant())) {
    auto& requestAsStopAudio = rfl::get<StopAudioRequest>(request.variant());

    juce::Logger::writeToLog("Stopping audio callback...");
    Engine::getInstance().stopAudioCallback();
    juce::Logger::writeToLog("stopAudioCallback() returned.");

    auto stopAudioReply = StopAudioResponse{.success = true,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = requestAsStopAudio.requestBase.get().id}};

    response = std::optional(std::move(stopAudioReply));
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

  auto handleTestCommandResponse = handleTestCommand(request);
  if (handleTestCommandResponse.has_value()) {
    if (response.has_value()) {
      didOverwriteResponse = true;
    }
    response = std::move(handleTestCommandResponse);
  }

  // Warn if multiple handlers gave back a reply. This would indicate that a
  // command is being handled multiple times, which is probably a bug.

  if (didOverwriteResponse) {
    juce::Logger::writeToLog(
        "Warning: Multiple command handlers tried to reply to a single command. Only the last "
        "reply will be sent back. This is probably a bug.");
  }

  if (response.has_value()) {
    // Serialize the response to a string
    auto responseStr = rfl::json::write(response.value());

    Engine::getInstance().comms.send(responseStr);
  }

  if (isExit) {
    juce::Logger::writeToLog("Engine received exit command. Exiting...");

    VisualizationBroker::getInstance().dispose();

    Engine::getInstance().comms.closeSocketThread();
    Engine::getInstance().shutdown();
    juce::JUCEApplicationBase::quit();
  }
}

} // namespace anthem
