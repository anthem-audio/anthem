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

#include <juce_audio_devices/juce_audio_devices.h>

#include "modules/processing_graph/anthem_graph.h"
#include "modules/core/constants.h"
#include "modules/processors/master_output_node.h"

class AnthemAudioCallback : public juce::AudioIODeviceCallback
{
private:
  std::shared_ptr<AnthemGraph> processingGraph;
  std::shared_ptr<AnthemGraphNode> masterOutputNode;
public:
  AnthemAudioCallback(
    std::shared_ptr<AnthemGraph> graph,
    std::shared_ptr<AnthemGraphNode> masterOutputNode
  ) : processingGraph(graph), masterOutputNode(masterOutputNode) {}

  void audioDeviceIOCallbackWithContext(const float* const* inputChannelData,
                                                   int numInputChannels,
                                                   float* const* outputChannelData,
                                                   int numOutputChannels,
                                                   int numSamples,
                                                   const juce::AudioIODeviceCallbackContext& context) override;
  void audioDeviceAboutToStart(juce::AudioIODevice* device) override;
  void audioDeviceStopped() override;
};
