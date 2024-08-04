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

#include <juce_audio_basics/juce_audio_basics.h>
#include <juce_events/juce_events.h>

#include "anthem_graph_node.h"
#include "linear_parameter_smoother.h"

// This class acts as a context for node graph processors. It is passed to the
// `process()` method of each `AnthemProcessor`, and provides a way to query
// the inputs and outputs of the node associated with that processor.
class AnthemProcessContext {
private:
  std::vector<juce::AudioSampleBuffer> inputAudioBuffers;
  std::vector<juce::AudioSampleBuffer> outputAudioBuffers;

  std::vector<juce::AudioSampleBuffer> inputControlBuffers;
  std::vector<juce::AudioSampleBuffer> outputControlBuffers;

  std::vector<std::atomic<float>> parameterValues;
  std::vector<std::unique_ptr<LinearParameterSmoother>> parameterSmoothers;

  std::weak_ptr<AnthemGraphNode> graphNode;
public:
  AnthemProcessContext(std::shared_ptr<AnthemGraphNode> graphNode);

  std::shared_ptr<AnthemGraphNode> getGraphNode() {
    // This function is for debugging. The graph node is mutated on the JUCE
    // message thread without any thread safety, so we throw if we're not on
    // that thread.
    if (!juce::MessageManager::getInstance()->isThisTheMessageThread()) {
      throw std::runtime_error("AnthemProcessContext::getGraphNode() must be called on the JUCE message thread.");
    }

    return graphNode.lock();
  }

  void setParameterValue(size_t index, float value);
  float getParameterValue(size_t index);

  void setAllInputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers);
  void setAllOutputAudioBuffers(const std::vector<juce::AudioSampleBuffer>& buffers);

  juce::AudioSampleBuffer& getInputAudioBuffer(size_t index);
  juce::AudioSampleBuffer& getOutputAudioBuffer(size_t index);

  size_t getNumInputAudioBuffers();
  size_t getNumOutputAudioBuffers();

  void setAllInputControlBuffers(const std::vector<juce::AudioSampleBuffer>& buffers);
  void setAllOutputControlBuffers(const std::vector<juce::AudioSampleBuffer>& buffers);

  juce::AudioSampleBuffer& getInputControlBuffer(size_t index);
  juce::AudioSampleBuffer& getOutputControlBuffer(size_t index);

  size_t getNumInputControlBuffers();
  size_t getNumOutputControlBuffers();

  std::vector<std::atomic<float>>& getParameterValues() {
    return parameterValues;
  }

  std::vector<std::unique_ptr<LinearParameterSmoother>>& getParameterSmoothers() {
    return parameterSmoothers;
  }
};
