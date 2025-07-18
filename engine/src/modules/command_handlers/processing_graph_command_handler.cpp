/*
  Copyright (C) 2024 - 2025 Joshua Wade

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

#include "processing_graph_command_handler.h"

#include "modules/core/anthem.h"

std::optional<Response>
handleProcessingGraphCommand(Request& request) {
  auto& anthem = Anthem::getInstance();

  if (rfl::holds_alternative<CompileProcessingGraphRequest>(request.variant())) {
    auto& compileProcessingGraphRequest = rfl::get<CompileProcessingGraphRequest>(request.variant());

    juce::Logger::writeToLog("Compiling from UI request...");

    // Test for the audio device to exist. We need to be able to query a valid
    // audio device to get buffer size and sample rate
    if (anthem.audioDeviceManager.getCurrentAudioDevice() == nullptr) {
      jassertfalse;
      juce::JUCEApplication::quit();
    }

    try {
      anthem.compileProcessingGraph();
    } catch (std::runtime_error& e) {
      juce::Logger::writeToLog("Error compiling: " + std::string(e.what()));

      return std::optional(CompileProcessingGraphResponse {
        .success = false,
        .error = std::string(e.what()),
        .responseBase = ResponseBase {
          .id = compileProcessingGraphRequest.requestBase.get().id
        }
      });
    }

    juce::Logger::writeToLog("Finished compiling.");

    return std::optional(CompileProcessingGraphResponse {
      .success = true,
      .error = std::nullopt,
      .responseBase = ResponseBase {
        .id = compileProcessingGraphRequest.requestBase.get().id
      }
    });
  } else if (rfl::holds_alternative<GetPluginStateRequest>(request.variant())) {
    juce::Logger::writeToLog("Handling GetPluginStateRequest...");

    auto& getPluginStateRequest = rfl::get<GetPluginStateRequest>(request.variant());

    auto& nodes = *Anthem::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(getPluginStateRequest.nodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    auto errorResponse = std::optional(GetPluginStateResponse{
      .state = "",
      .isValid = false,
      .responseBase = ResponseBase {
        .id = getPluginStateRequest.requestBase.get().id
      }
    });

    if (node == nullptr) {
      juce::Logger::writeToLog("Node " + getPluginStateRequest.nodeId + " not found in processing graph.");
      return errorResponse;
    }

    auto processor = node->getProcessor();

    if (!processor) {
      juce::Logger::writeToLog("Node " + getPluginStateRequest.nodeId + " does not have a processor.");
      return errorResponse;
    }

    juce::MemoryBlock state;
    processor.value()->getState(state);

    std::string stateString = "";
    
    if (state.getSize() > 0) {
      stateString = state.toBase64Encoding().toStdString();
    }

    return std::optional(GetPluginStateResponse{
      .state = stateString,
      .isValid = true,
      .responseBase = ResponseBase {
        .id = getPluginStateRequest.requestBase.get().id
      }
    });
  } else if (rfl::holds_alternative<SetPluginStateRequest>(request.variant())) {
    juce::Logger::writeToLog("Handling SetPluginStateRequest...");

    auto& setPluginStateRequest = rfl::get<SetPluginStateRequest>(request.variant());

    auto& nodes = *Anthem::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(setPluginStateRequest.nodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    if (node == nullptr) {
      juce::Logger::writeToLog("Node " + setPluginStateRequest.nodeId + " not found in processing graph.");
      return std::nullopt;
    }

    auto processor = node->getProcessor();

    if (!processor) {
      juce::Logger::writeToLog("Node " + setPluginStateRequest.nodeId + " does not have a processor.");
      return std::nullopt;
    }

    if (setPluginStateRequest.state.empty()) {
      juce::Logger::writeToLog("Received empty state for node " + setPluginStateRequest.nodeId);
      return std::nullopt;
    }

    juce::MemoryBlock state;
    state.fromBase64Encoding(setPluginStateRequest.state);

    try {
      processor.value()->setState(state);
      return std::nullopt;
    } catch (std::runtime_error& e) {
      juce::Logger::writeToLog("Error setting plugin state: " + std::string(e.what()));
      return std::nullopt;
    }
  }

  return std::nullopt;
}
