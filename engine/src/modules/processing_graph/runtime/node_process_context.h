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
#include "modules/processing_graph/runtime/audio_buffer_slice.h"
#include "modules/sequencer/events/note_instance_id.h"

#include <atomic>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>
#include <optional>
#include <stdexcept>
#include <unordered_map>
#include <vector>
// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
namespace anthem {

class GraphProcessContext;

class NodeProcessContext {
public:
  using PortBufferIndexMap = std::unordered_map<int64_t, size_t>;
  using OptionalPortBufferIndexMap = std::unordered_map<int64_t, std::optional<size_t>>;
  using PortAudioBufferSliceMap = std::unordered_map<int64_t, AudioBufferSlice>;
  using PortAudioBufferViewMap = std::unordered_map<int64_t, juce::AudioSampleBuffer>;

  enum class BufferDirection : uint8_t {
    input,
    output,
  };

  // Maps node ports to graph-owned buffers. Input bindings may refer to
  // buffers owned for this node, another node's output buffer, or a shared
  // empty event buffer. Control input bindings may be empty for disconnected
  // parameter ports, in which case processors read the parameter value instead
  // of a buffer. Audio bindings expose slices so processors see only the
  // channels that belong to a port, even when the physical graph buffer is
  // wider. The rt_*BuffersToClear lists identify only the buffers or slices
  // this node should clear before processing.
  struct BufferBindings {
    PortAudioBufferSliceMap inputAudioBuffers;
    PortAudioBufferSliceMap outputAudioBuffers;
    std::optional<AudioBufferSlice> audioProcessBuffer;

    OptionalPortBufferIndexMap inputControlBuffers;
    PortBufferIndexMap outputControlBuffers;

    PortBufferIndexMap inputEventBuffers;
    PortBufferIndexMap outputEventBuffers;

    std::vector<AudioBufferSlice> rt_audioBuffersToClear;
    std::vector<size_t> rt_eventBuffersToClear;
  };

  struct InputParameterBinding {
    int64_t portId;
    std::unique_ptr<std::atomic<float>> value;
  };

  struct InputControlSignal {
    const juce::AudioSampleBuffer* rt_buffer = nullptr;
    float parameterValue = 0.0f;

    bool hasBuffer() const {
      return rt_buffer != nullptr;
    }

    float getSample(int sample) const {
      if (rt_buffer == nullptr) {
        return parameterValue;
      }

      return rt_buffer->getReadPointer(0)[sample];
    }
  };

  struct ConnectedInputControlPort {
    int64_t portId;
    size_t bufferIndex;
  };
private:
  JUCE_LEAK_DETECTOR(NodeProcessContext)

  InputParameterBinding& findInputParameterBinding(int64_t id);
  const InputParameterBinding& findInputParameterBinding(int64_t id) const;

  PortAudioBufferSliceMap inputAudioBuffers;
  PortAudioBufferSliceMap outputAudioBuffers;
  std::optional<AudioBufferSlice> audioProcessBuffer;

  PortAudioBufferViewMap inputAudioBufferViews;
  PortAudioBufferViewMap outputAudioBufferViews;
  std::optional<juce::AudioSampleBuffer> audioProcessBufferView;

  OptionalPortBufferIndexMap inputControlBuffers;
  PortBufferIndexMap outputControlBuffers;

  PortBufferIndexMap inputEventBuffers;
  PortBufferIndexMap outputEventBuffers;

  std::vector<AudioBufferSlice> rt_audioBuffersToClear;
  std::vector<size_t> rt_eventBuffersToClear;
  std::vector<ConnectedInputControlPort> rt_connectedInputControlPorts;

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
  float getParameterValue(int64_t id) const;

  void clearBuffers();
  size_t getBufferIndex(NodePortDataType dataType, BufferDirection direction, int64_t id) const;

  const juce::AudioSampleBuffer& getInputAudioBuffer(int64_t id) const;
  juce::AudioSampleBuffer& getMutableInputAudioBuffer(int64_t id);
  juce::AudioSampleBuffer& getOutputAudioBuffer(int64_t id);
  juce::AudioSampleBuffer& getAudioProcessBuffer();
  bool hasAudioProcessBuffer() const;

  InputControlSignal getInputControlSignal(int64_t id) const;
  const juce::AudioSampleBuffer* getInputControlBuffer(int64_t id) const;
  const juce::AudioSampleBuffer& rt_getInputControlBufferByIndex(size_t index) const;
  juce::AudioSampleBuffer& getOutputControlBuffer(int64_t id);

  const EventBuffer& getInputEventBuffer(int64_t id) const;
  EventBuffer& getOutputEventBuffer(int64_t id);

  const std::vector<InputParameterBinding>& rt_getInputParameterBindings() const {
    return inputParameters;
  }

  const std::vector<ConnectedInputControlPort>& rt_getConnectedInputControlPorts() const {
    return rt_connectedInputControlPorts;
  }

  LiveNoteId rt_allocateLiveNoteId();
};

} // namespace anthem
