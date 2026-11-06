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
#ifndef __EMSCRIPTEN__
#include "modules/processors/vst3_processor.h"
#endif

#include <exception>
#include <memory>
#include <rfl/json.hpp>
#include <string>
#include <utility>
#include <vector>

namespace anthem {

namespace {
std::string toIdString(int64_t id) {
  return std::to_string(id);
}
} // namespace

std::optional<Response> handleProcessingGraphCommand(Request& request) {
  auto& engine = Engine::getInstance();

  if (rfl::holds_alternative<InitializeProcessingGraphNodesRequest>(request.variant())) {
    auto& initializeNodesRequest =
        rfl::get<InitializeProcessingGraphNodesRequest>(request.variant());

    juce::Logger::writeToLog("Initializing processing graph nodes from UI request...");

    auto results =
        std::make_shared<std::vector<std::shared_ptr<ProcessingGraphNodeInitializationResult>>>();
    auto requestId = initializeNodesRequest.requestBase.get().id;

    if (!engine.audioSessionController->hasActiveAudioSession()) {
      juce::Logger::writeToLog(
          "Skipping processing graph node initialization because no audio session is active.");

      return std::optional(InitializeProcessingGraphNodesResponse{.didInitialize = false,
          .results = results,
          .error = std::nullopt,
          .responseBase = ResponseBase{.id = requestId}});
    }

    // Note that this is asynchronous (still single-threaded though), so when
    // the work for this method completes, it calls the lambda we pass in here.
    engine.initializeProcessingGraphNodes(
        [requestId](std::vector<std::shared_ptr<ProcessingGraphNodeInitializationResult>>
                initializationResults) {
          auto results = std::make_shared<
              std::vector<std::shared_ptr<ProcessingGraphNodeInitializationResult>>>(
              std::move(initializationResults));

          Response response = InitializeProcessingGraphNodesResponse{.didInitialize = true,
              .results = results,
              .error = std::nullopt,
              .responseBase = ResponseBase{.id = requestId}};

          auto responseString = rfl::json::write(response);
          Engine::getInstance().comms.send(responseString);
        });

    return std::nullopt;
  } else if (rfl::holds_alternative<PublishProcessingGraphRequest>(request.variant())) {
    auto& publishProcessingGraphRequest =
        rfl::get<PublishProcessingGraphRequest>(request.variant());

    juce::Logger::writeToLog("Publishing from UI request...");

    if (!engine.audioSessionController->hasActiveAudioSession()) {
      constexpr auto error = "Cannot publish processing graph because no audio session is active.";
      juce::Logger::writeToLog(error);

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string(error),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    // We need a valid processing config in order to allocate the graph buffers
    // used by the published graph.
    if (!engine.audioSessionController->getCurrentAudioProcessingConfig().has_value()) {
      juce::Logger::writeToLog(
          "Cannot publish processing graph because no audio processing config is active.");

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string("No audio processing config is active."),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    try {
      engine.publishProcessingGraph();
    } catch (const std::exception& e) {
      juce::Logger::writeToLog("Error publishing: " + std::string(e.what()));

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string(e.what()),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    } catch (...) {
      constexpr auto unknownError = "Unknown error while publishing processing graph.";
      juce::Logger::writeToLog(unknownError);

      return std::optional(PublishProcessingGraphResponse{.success = false,
          .error = std::string(unknownError),
          .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
    }

    juce::Logger::writeToLog("Finished publishing.");

    return std::optional(PublishProcessingGraphResponse{.success = true,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = publishProcessingGraphRequest.requestBase.get().id}});
  } else if (rfl::holds_alternative<SaveProcessorSnapshotRequest>(request.variant())) {
    const auto& save = rfl::get<SaveProcessorSnapshotRequest>(request.variant());
    const auto requestId = save.requestBase.get().id;
    const auto found = engine.project->processingGraph()->nodes()->find(save.nodeId);
    auto send = [requestId](FileStorageResult<std::string> result) {
      Response response = SaveProcessorSnapshotResponse{.retentionId = std::move(result.value),
          .error = std::move(result.error),
          .responseBase = ResponseBase{.id = requestId}};
      auto message = rfl::json::write(response);
      Engine::getInstance().comms.send(message);
    };
    if (found == engine.project->processingGraph()->nodes()->end())
      send({.value = std::nullopt, .error = "Processing graph node not found."});
    else
      engine.processorStateStorage.saveSnapshot(engine, found->second, std::move(send));
    return std::nullopt;
  } else if (rfl::holds_alternative<LoadProcessorSnapshotRequest>(request.variant()) ||
             rfl::holds_alternative<FinishProcessorSnapshotLoadRequest>(request.variant())) {
    const bool beginning = rfl::holds_alternative<LoadProcessorSnapshotRequest>(request.variant());
    const auto requestId =
        beginning
            ? rfl::get<LoadProcessorSnapshotRequest>(request.variant()).requestBase.get().id
            : rfl::get<FinishProcessorSnapshotLoadRequest>(request.variant()).requestBase.get().id;
    auto send = [requestId](ProcessorSnapshotLoadResult result) {
      Response response = LoadProcessorSnapshotResponse{.operationId = result.operationId,
          .result = result.result ? std::optional(result.result) : std::nullopt,
          .error = std::move(result.error),
          .responseBase = ResponseBase{.id = requestId}};
      auto message = rfl::json::write(response);
      Engine::getInstance().comms.send(message);
    };
    if (beginning) {
      const auto& load = rfl::get<LoadProcessorSnapshotRequest>(request.variant());
      const auto found = engine.project->processingGraph()->nodes()->find(load.nodeId);
      if (found == engine.project->processingGraph()->nodes()->end())
        send({.operationId = std::nullopt,
            .result = nullptr,
            .error = "Processing graph node not found."});
      else
        engine.processorStateStorage.loadSnapshot(
            engine, found->second, load.retentionId, load.recoveryRetentionId, std::move(send));
    } else {
      const auto& finish = rfl::get<FinishProcessorSnapshotLoadRequest>(request.variant());
      engine.processorStateStorage.finishSnapshotLoad(
          finish.operationId, finish.rollback, std::move(send));
    }
    return std::nullopt;
  } else if (rfl::holds_alternative<CaptureProcessorStateRequest>(request.variant())) {
    const auto& capture = rfl::get<CaptureProcessorStateRequest>(request.variant());
    const auto requestId = capture.requestBase.get().id;
    auto& nodes = *engine.project->processingGraph()->nodes();
    const auto node = nodes.find(capture.nodeId);
    if (node == nodes.end()) {
      return std::optional(CaptureProcessorStateResponse{.relativePath = std::nullopt,
          .error = "Processing graph node not found.",
          .responseBase = ResponseBase{.id = requestId}});
    }
    engine.processorStateStorage.capture(
        node->second,
        [requestId](FileStorageResult<std::string> result) {
          Response response = CaptureProcessorStateResponse{
              .relativePath = result.value && !result.value->empty() ? result.value : std::nullopt,
              .error = std::move(result.error),
              .responseBase = ResponseBase{.id = requestId}};
          auto message = rfl::json::write(response);
          Engine::getInstance().comms.send(message);
        },
        &engine);
    return std::nullopt;
  } else if (rfl::holds_alternative<SetProcessorParameterValueRequest>(request.variant())) {
    const auto& edit = rfl::get<SetProcessorParameterValueRequest>(request.variant());
    SetProcessorParameterValueResponse response{.parameterValue = std::nullopt,
        .error = std::nullopt,
        .responseBase = ResponseBase{.id = edit.requestBase.get().id}};
    auto& nodes = *engine.project->processingGraph()->nodes();
    const auto node = nodes.find(edit.nodeId);
    const auto processor = node == nodes.end() ? nullptr : node->second->getProcessor();
    if (!processor || !processor->isPrepared || !processor->hasRestoredProjectState ||
        engine.processorStateStorage.isBusy(edit.nodeId)) {
      response.error = "The processor is not ready for parameter edits.";
    } else if (auto error = processor->setParameterValue(edit.controlPortId, edit.value)) {
      response.error = std::move(error);
    } else {
      const auto value = processor->getParameter(edit.controlPortId)->value.load();
      response.parameterValue = std::make_shared<ProcessingGraphParameterValue>(
          ProcessingGraphParameterValue{.controlPortId = edit.controlPortId,
              .value = value,
              .displayText = processor->getParameterDisplayText(edit.controlPortId, value)});
    }
    return Response(std::move(response));
  } else if (rfl::holds_alternative<OpenPluginWindowRequest>(request.variant())) {
    juce::Logger::writeToLog("Handling OpenPluginWindowRequest...");

    auto& openPluginWindowRequest = rfl::get<OpenPluginWindowRequest>(request.variant());

#ifdef __EMSCRIPTEN__
    juce::Logger::writeToLog("Plugin windows are not available on this platform.");
#else
    auto& nodes = *Engine::getInstance().project->processingGraph()->nodes();
    auto nodeIter = nodes.find(openPluginWindowRequest.nodeId);
    auto node = nodeIter != nodes.end() ? nodeIter->second : nullptr;

    if (node == nullptr) {
      juce::Logger::writeToLog(
          "Node " + toIdString(openPluginWindowRequest.nodeId) + " not found in processing graph.");
      return std::nullopt;
    }

    auto processor = node->getProcessor();

    auto vst3Processor = std::dynamic_pointer_cast<VST3Processor>(processor);

    if (vst3Processor == nullptr) {
      juce::Logger::writeToLog(
          "Node " + toIdString(openPluginWindowRequest.nodeId) + " is not a VST3 processor.");
      return std::nullopt;
    }

    auto error = vst3Processor->openPluginWindow();

    if (error.has_value()) {
      juce::Logger::writeToLog("Error opening plugin window: " + error.value());
    }
#endif

    return std::nullopt;
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

    auto processor = node->getProcessor();

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
