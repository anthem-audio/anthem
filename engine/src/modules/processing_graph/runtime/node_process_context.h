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

#pragma once

#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/processor/event_buffer.h"
#include "modules/sequencer/events/note_instance_id.h"
#include "modules/util/linear_parameter_smoother.h"

#include <atomic>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>
#include <stdexcept>
#include <unordered_map>
#include <unordered_set>
#include <vector>
// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
namespace anthem {

class GraphProcessContext;

class NodeProcessContext {
public:
  using PortBufferIndexMap = std::unordered_map<int64_t, size_t>;

  enum class BufferDirection : uint8_t {
    input,
    output,
  };

  // Maps node ports to graph-owned buffers. Input bindings may refer to
  // buffers owned for this node, another node's output buffer, or a shared
  // silent/empty buffer. The rt_*ToClear lists identify only the buffers this
  // node should clear before processing.
  struct BufferBindings {
    PortBufferIndexMap inputAudioBuffers;
    PortBufferIndexMap outputAudioBuffers;

    PortBufferIndexMap inputControlBuffers;
    PortBufferIndexMap outputControlBuffers;

    PortBufferIndexMap inputEventBuffers;
    PortBufferIndexMap outputEventBuffers;

    std::vector<size_t> rt_audioBuffersToClear;
    std::vector<size_t> rt_eventBuffersToClear;
    std::unordered_set<int64_t> rt_parameterInputPortsToWrite;
  };

  struct InputParameterBinding {
    int64_t portId;
    juce::AudioSampleBuffer* rt_buffer = nullptr;
    bool rt_shouldWriteToBuffer = true;
    std::unique_ptr<std::atomic<float>> value;
    std::unique_ptr<LinearParameterSmoother> rt_smoother;
  };
private:
  JUCE_LEAK_DETECTOR(NodeProcessContext)

  InputParameterBinding& findInputParameterBinding(int64_t id);
  const InputParameterBinding& findInputParameterBinding(int64_t id) const;

  PortBufferIndexMap inputAudioBuffers;
  PortBufferIndexMap outputAudioBuffers;

  PortBufferIndexMap inputControlBuffers;
  PortBufferIndexMap outputControlBuffers;

  PortBufferIndexMap inputEventBuffers;
  PortBufferIndexMap outputEventBuffers;

  std::vector<size_t> rt_audioBuffersToClear;
  std::vector<size_t> rt_eventBuffersToClear;

  std::vector<InputParameterBinding> inputParameters;

  std::weak_ptr<Node> graphNode;
  GraphProcessContext* graphProcessContext = nullptr;
public:
  NodeProcessContext(std::shared_ptr<Node>& graphNode,
      GraphProcessContext& graphProcessContext,
      BufferBindings bufferBindings);

  // Clean up the context. This must be called before the context is deallocated.
  void cleanup();

  std::shared_ptr<Node> getGraphNode() {
    // This function is for debugging. The graph node is mutated on the JUCE
    // message thread without any concern for thread safety, so we throw if
    // we're not on that thread.
    if (!juce::MessageManager::getInstance()->isThisTheMessageThread()) {
      throw std::runtime_error(
          "AnthemNodeProcessContext::getGraphNode() must be called on the JUCE message thread.");
    }

    return graphNode.lock();
  }

  void setParameterValue(int64_t id, float value);
  float getParameterValue(int64_t id);

  void clearBuffers();
  size_t getBufferIndex(NodePortDataType dataType, BufferDirection direction, int64_t id) const;

  const juce::AudioSampleBuffer& getInputAudioBuffer(int64_t id) const;
  juce::AudioSampleBuffer& getOutputAudioBuffer(int64_t id);

  const juce::AudioSampleBuffer& getInputControlBuffer(int64_t id) const;
  juce::AudioSampleBuffer& getOutputControlBuffer(int64_t id);

  const EventBuffer& getInputEventBuffer(int64_t id) const;
  EventBuffer& getOutputEventBuffer(int64_t id);

  const std::vector<InputParameterBinding>& rt_getInputParameterBindings() const {
    return inputParameters;
  }

  LiveNoteId rt_allocateLiveNoteId();
};

} // namespace anthem
