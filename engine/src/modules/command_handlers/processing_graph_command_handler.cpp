/*
  Copyright (C) 2024 - 2026 Joshua Wade

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

#include "modules/core/engine.h"
#include "modules/processors/live_event_provider.h"

#include <string>

namespace anthem {

namespace {
std::string toIdString(int64_t id) {
  return std::to_string(id);
}
} // namespace

std::optional<Response> handleProcessingGraphCommand(Request& request) {
  auto& engine = Engine::getInstance();

  if (rfl::holds_alternative<PublishProcessingGraphRequest>(request.variant())) {
    auto& publishProcessingGraphRequest =
        rfl::get<PublishProcessingGraphRequest>(request.variant());

    juce::Logger::writeToLog("Publishing from UI request...");

    if (!engine.isAudioThreadRunning()) {
      juce::Logger::writeToLog(
          "Skipping processing graph publish because the audio thread is not running.");

      return std::optional(PublishProcessingGraphResponse{.success = true,
          .error = std::nullopt,
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    // We need a valid device in order to query the sample rate and block size
    // used by the published graph.
    if (engine.audioDeviceManager.getCurrentAudioDevice() == nullptr) {
      juce::Logger::writeToLog(
          "Cannot publish processing graph because no audio device is active.");

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string("No audio device is active."),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    try {
      engine.publishProcessingGraph();
    } catch (std::runtime_error& e) {
      juce::Logger::writeToLog("Error publishing: " + std::string(e.what()));

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string(e.what()),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    juce::Logger::writeToLog("Finished publishing.");

    return std::optional(PublishProcessingGraphResponse{.success = true,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
  } else if (rfl::holds_alternative<GetPluginStateRequest>(request.variant())) {
    juce::Logger::writeToLog("Handling GetPluginStateRequest...");

    auto& getPluginStateRequest = rfl::get<GetPluginStateRequest>(request.variant());

    auto& nodes = *Engine::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(getPluginStateRequest.nodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    auto errorResponse = std::optional(GetPluginStateResponse{.state = "",
        .isValid = false,
        .responseBase = ResponseBase{.id = getPluginStateRequest.requestBase.get().id}});

    if (node == nullptr) {
      juce::Logger::writeToLog(
          "Node " + toIdString(getPluginStateRequest.nodeId) + " not found in processing graph.");
      return errorResponse;
    }

    auto processor = node->getProcessor();

    if (!processor) {
      juce::Logger::writeToLog(
          "Node " + toIdString(getPluginStateRequest.nodeId) + " does not have a processor.");
      return errorResponse;
    }

    juce::MemoryBlock state;
    processor.value()->getState(state);

    std::string stateString = "";

    if (state.getSize() > 0) {
      stateString = state.toBase64Encoding().toStdString();
    }

    return std::optional(GetPluginStateResponse{.state = stateString,
        .isValid = true,
        .responseBase = ResponseBase{.id = getPluginStateRequest.requestBase.get().id}});
  } else if (rfl::holds_alternative<SetPluginStateRequest>(request.variant())) {
    juce::Logger::writeToLog("Handling SetPluginStateRequest...");

    auto& setPluginStateRequest = rfl::get<SetPluginStateRequest>(request.variant());

    auto& nodes = *Engine::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(setPluginStateRequest.nodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    if (node == nullptr) {
      juce::Logger::writeToLog(
          "Node " + toIdString(setPluginStateRequest.nodeId) + " not found in processing graph.");
      return std::nullopt;
    }

    auto processor = node->getProcessor();

    if (!processor) {
      juce::Logger::writeToLog(
          "Node " + toIdString(setPluginStateRequest.nodeId) + " does not have a processor.");
      return std::nullopt;
    }

    if (setPluginStateRequest.state.empty()) {
      juce::Logger::writeToLog(
          "Received empty state for node " + toIdString(setPluginStateRequest.nodeId));
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
  } else if (rfl::holds_alternative<SendLiveEventRequest>(request.variant())) {
    auto& sendLiveEventRequest = rfl::get<SendLiveEventRequest>(request.variant());

    // Get the node that is the live event provider
    auto& nodes = *Engine::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(sendLiveEventRequest.liveEventProviderNodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    if (node == nullptr) {
      juce::Logger::writeToLog("Node " + toIdString(sendLiveEventRequest.liveEventProviderNodeId) +
                               " not found in processing graph.");
      return std::nullopt;
    }

    auto processorOpt = node->getProcessor();

    if (!processorOpt) {
      juce::Logger::writeToLog("Node " + toIdString(sendLiveEventRequest.liveEventProviderNodeId) +
                               " does not have a processor.");
      return std::nullopt;
    }

    auto& processor = processorOpt.value();

    // Check if processor is a live event provider
    auto liveEventProvider = std::dynamic_pointer_cast<LiveEventProviderProcessor>(processor);
    if (liveEventProvider) {
      rfl::visit(
          [liveEventProvider](const auto& field) {
            using EventType = std::decay_t<decltype(field)>;
            if constexpr (std::is_same_v<EventType,
                              rfl::Field<"LiveEventRequestNoteOnEvent",
                                  std::shared_ptr<LiveEventRequestNoteOnEvent>>>) {
              auto& eventFromRequest = field.value();
              LiveInputEvent liveInputEvent =
                  LiveInputEvent{.sampleOffset = 0, // Handle as soon as possible
                      .inputId = eventFromRequest->noteId,
                      .event = Event(NoteOnEvent(eventFromRequest->pitch,
                          eventFromRequest->channel,
                          eventFromRequest->velocity,
                          0.0f))};
              // liveEvent.event.noteOn.pan = eventFromRequest.pan;

              liveEventProvider->addLiveInputEvent(liveInputEvent);
            } else if constexpr (std::is_same_v<EventType,
                                     rfl::Field<"LiveEventRequestNoteOffEvent",
                                         std::shared_ptr<LiveEventRequestNoteOffEvent>>>) {
              auto& eventFromRequest = field.value();
              LiveInputEvent liveInputEvent =
                  LiveInputEvent{.sampleOffset = 0, // Handle as soon as possible
                      .inputId = eventFromRequest->noteId,
                      .event = Event(
                          NoteOffEvent(eventFromRequest->pitch, eventFromRequest->channel, 0.0f))};

              liveEventProvider->addLiveInputEvent(liveInputEvent);
            } else {
              jassertfalse; // unhandled event
            }
          },
          sendLiveEventRequest.event);
    } else {
      jassertfalse;
      return std::nullopt;
    }

    return std::nullopt;
  }

  return std::nullopt;
}

} // namespace anthem
