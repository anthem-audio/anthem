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
#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "modules/sequencer/events/note_instance_id.h"
#include "modules/util/linear_parameter_smoother.h"

#include <atomic>
#include <cstdint>
#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>
#include <memory>
#include <stdexcept>
#include <vector>
// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
class AnthemGraphProcessContext;

class AnthemNodeProcessContext {
public:
  struct InputParameterBinding {
    int64_t portId;
    juce::AudioSampleBuffer* rt_buffer = nullptr;
    std::unique_ptr<std::atomic<float>> value;
    std::unique_ptr<LinearParameterSmoother> rt_smoother;
  };
private:
  JUCE_LEAK_DETECTOR(AnthemNodeProcessContext)

  struct PortBufferHandle {
    int64_t portId;
    size_t bufferIndex;
  };

  const PortBufferHandle& findBufferHandle(
      const std::vector<PortBufferHandle>& handles, int64_t portId, const char* bufferType) const;
  InputParameterBinding& findInputParameterBinding(int64_t id);
  const InputParameterBinding& findInputParameterBinding(int64_t id) const;

  std::vector<PortBufferHandle> inputAudioBuffers;
  std::vector<PortBufferHandle> outputAudioBuffers;

  std::vector<PortBufferHandle> inputControlBuffers;
  std::vector<PortBufferHandle> outputControlBuffers;

  std::vector<PortBufferHandle> inputEventBuffers;
  std::vector<PortBufferHandle> outputEventBuffers;

  std::vector<InputParameterBinding> inputParameters;

  std::weak_ptr<Node> graphNode;
  AnthemGraphProcessContext* graphProcessContext = nullptr;
public:
  AnthemNodeProcessContext(
      std::shared_ptr<Node>& graphNode, AnthemGraphProcessContext& graphProcessContext);

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

  juce::AudioSampleBuffer& getInputAudioBuffer(int64_t id);
  juce::AudioSampleBuffer& getOutputAudioBuffer(int64_t id);

  juce::AudioSampleBuffer& getInputControlBuffer(int64_t id);
  juce::AudioSampleBuffer& getOutputControlBuffer(int64_t id);

  std::unique_ptr<AnthemEventBuffer>& getInputEventBuffer(int64_t id);
  std::unique_ptr<AnthemEventBuffer>& getOutputEventBuffer(int64_t id);

  const std::vector<InputParameterBinding>& rt_getInputParameterBindings() const {
    return inputParameters;
  }

  AnthemLiveNoteId rt_allocateLiveNoteId();
};
