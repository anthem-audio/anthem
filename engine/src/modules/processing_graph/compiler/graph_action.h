/*
  Copyright (C) 2026 Joshua Wade

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

#include <cstddef>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <type_traits>

namespace anthem {

class EventBuffer;
class NodeProcessContext;
class Processor;

enum class GraphActionType : uint8_t {
  ClearBuffers,
  WriteParametersToControlInputs,
  ProcessNode,
  CopyAudioBuffer,
  CopyControlBuffer,
  CopyEvents,
};

struct ClearBuffersActionData {
  NodeProcessContext* context;
};

struct WriteParametersToControlInputsActionData {
  NodeProcessContext* context;
};

struct ProcessNodeActionData {
  NodeProcessContext* context;
  Processor* processor;
};

struct CopyAudioBufferActionData {
  size_t sourceBufferIndex;
  size_t destinationBufferIndex;
};

struct CopyControlBufferActionData {
  size_t sourceBufferIndex;
  size_t destinationBufferIndex;
};

struct CopyEventsActionData {
  size_t sourceBufferIndex;
  size_t destinationBufferIndex;
};

struct GraphAction {
  GraphActionType type;

  union {
    ClearBuffersActionData clearBuffers;
    WriteParametersToControlInputsActionData writeParametersToControlInputs;
    ProcessNodeActionData processNode;
    CopyAudioBufferActionData copyAudioBuffer;
    CopyControlBufferActionData copyControlBuffer;
    CopyEventsActionData copyEvents;
  };

  static GraphAction makeClearBuffers(NodeProcessContext* context) {
    GraphAction action{};
    action.type = GraphActionType::ClearBuffers;
    action.clearBuffers.context = context;
    return action;
  }

  static GraphAction makeWriteParametersToControlInputs(NodeProcessContext* context) {
    GraphAction action{};
    action.type = GraphActionType::WriteParametersToControlInputs;
    action.writeParametersToControlInputs.context = context;
    return action;
  }

  static GraphAction makeProcessNode(NodeProcessContext* context, Processor* processor) {
    GraphAction action{};
    action.type = GraphActionType::ProcessNode;
    action.processNode.context = context;
    action.processNode.processor = processor;
    return action;
  }

  static GraphAction makeCopyAudioBuffer(size_t sourceBufferIndex, size_t destinationBufferIndex) {
    GraphAction action{};
    action.type = GraphActionType::CopyAudioBuffer;
    action.copyAudioBuffer.sourceBufferIndex = sourceBufferIndex;
    action.copyAudioBuffer.destinationBufferIndex = destinationBufferIndex;
    return action;
  }

  static GraphAction makeCopyControlBuffer(
      size_t sourceBufferIndex, size_t destinationBufferIndex) {
    GraphAction action{};
    action.type = GraphActionType::CopyControlBuffer;
    action.copyControlBuffer.sourceBufferIndex = sourceBufferIndex;
    action.copyControlBuffer.destinationBufferIndex = destinationBufferIndex;
    return action;
  }

  static GraphAction makeCopyEvents(size_t sourceBufferIndex, size_t destinationBufferIndex) {
    GraphAction action{};
    action.type = GraphActionType::CopyEvents;
    action.copyEvents.sourceBufferIndex = sourceBufferIndex;
    action.copyEvents.destinationBufferIndex = destinationBufferIndex;
    return action;
  }
};

static_assert(
    std::is_trivially_copyable_v<GraphAction>, "GraphAction should remain trivially copyable.");

} // namespace anthem
