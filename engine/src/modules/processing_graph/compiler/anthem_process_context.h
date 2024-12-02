/*
  Copyright (C) 2024 Joshua Wade

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

#include <memory>
#include <vector>
#include <unordered_map>

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_events/juce_events.h>

#include "modules/processing_graph/processor/anthem_event_buffer.h"
#include "generated/lib/model/model.h"
#include "modules/util/linear_parameter_smoother.h"
#include "modules/processing_graph/model/node.h"

// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
class AnthemProcessContext {
private:
  std::unordered_map<int32_t, juce::AudioSampleBuffer> inputAudioBuffers;
  std::unordered_map<int32_t, juce::AudioSampleBuffer> outputAudioBuffers;

  std::unordered_map<int32_t, juce::AudioSampleBuffer> inputControlBuffers;
  std::unordered_map<int32_t, juce::AudioSampleBuffer> outputControlBuffers;

  std::unordered_map<int32_t, AnthemEventBuffer> inputNoteEventBuffers;
  std::unordered_map<int32_t, AnthemEventBuffer> outputNoteEventBuffers;

  std::unordered_map<int32_t, std::atomic<float>*> parameterValues;
  std::unordered_map<int32_t, std::unique_ptr<LinearParameterSmoother>> parameterSmoothers;

  std::weak_ptr<Node> graphNode;
public:
  AnthemProcessContext(std::shared_ptr<Node>& graphNode, ArenaBufferAllocator<AnthemProcessorEvent>* eventAllocator);
  ~AnthemProcessContext();

  std::shared_ptr<Node> getGraphNode() {
    // This function is for debugging. The graph node is mutated on the JUCE
    // message thread without any concern for thread safety, so we throw if
    // we're not on that thread.
    if (!juce::MessageManager::getInstance()->isThisTheMessageThread()) {
      throw std::runtime_error("AnthemProcessContext::getGraphNode() must be called on the JUCE message thread.");
    }

    return graphNode.lock();
  }

  void setParameterValue(int32_t id, float value);
  float getParameterValue(int32_t id);

  void setAllInputAudioBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers);
  void setAllOutputAudioBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers);

  juce::AudioSampleBuffer& getInputAudioBuffer(int32_t id);
  juce::AudioSampleBuffer& getOutputAudioBuffer(int32_t id);

  size_t getNumInputAudioBuffers();
  size_t getNumOutputAudioBuffers();

  void setAllInputControlBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers);
  void setAllOutputControlBuffers(const std::unordered_map<int32_t, juce::AudioSampleBuffer>& buffers);

  juce::AudioSampleBuffer& getInputControlBuffer(int32_t id);
  juce::AudioSampleBuffer& getOutputControlBuffer(int32_t id);

  size_t getNumInputControlBuffers();
  size_t getNumOutputControlBuffers();

  void setAllInputNoteEventBuffers(const std::unordered_map<int32_t, AnthemEventBuffer>& buffers);
  void setAllOutputNoteEventBuffers(const std::unordered_map<int32_t, AnthemEventBuffer>& buffers);

  AnthemEventBuffer& getInputNoteEventBuffer(int32_t id);
  AnthemEventBuffer& getOutputNoteEventBuffer(int32_t id);

  size_t getNumInputNoteEventBuffers();
  size_t getNumOutputNoteEventBuffers();

  std::unordered_map<int32_t, std::atomic<float>*>& getParameterValues() {
    return parameterValues;
  }

  std::unordered_map<int32_t, std::unique_ptr<LinearParameterSmoother>>& getParameterSmoothers() {
    return parameterSmoothers;
  }
};
