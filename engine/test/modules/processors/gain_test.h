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

#include "modules/processing_graph/compiler/graph_process_context.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"

#include <array>
#include <juce_core/juce_core.h>

namespace anthem {

class GainProcessorTest : public juce::UnitTest {
  static constexpr int64_t nodeId = 1001;
  static constexpr int blockSize = 4;
  static constexpr int channelCount = 2;

  static std::shared_ptr<Node> makeNode() {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioInputPortId, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioOutputPortId, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::gainPortId, nodeId, NodePortDataType::control));

    return node;
  }
public:
  GainProcessorTest() : juce::UnitTest("GainProcessorTest", "Anthem") {}

  void runTest() override {
    testProcessAppliesPerSampleGain();
  }

  void testProcessAppliesPerSampleGain() {
    beginTest("Gain processing applies per-sample gain to every channel");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = channelCount,
            .blockSize = blockSize,
        });
    graphContext.reserve(1, 2, 1, 0);

    auto& context = graphContext.createNodeProcessContext(node);
    auto& inputBuffer = context.getInputAudioBuffer(GainProcessorModelBase::audioInputPortId);
    auto& outputBuffer = context.getOutputAudioBuffer(GainProcessorModelBase::audioOutputPortId);
    auto& gainBuffer = context.getInputControlBuffer(GainProcessorModelBase::gainPortId);

    const std::array<float, blockSize> channel0Samples{1.0f, -1.0f, 0.5f, 0.25f};
    const std::array<float, blockSize> channel1Samples{0.2f, -0.4f, 1.0f, -1.0f};
    const std::array<float, blockSize> gainParameterValues{
        kGainParameterZeroDbNormalized,
        gainDbToParameterValue(-6.0f),
        gainDbToParameterValue(6.0f),
        0.0f,
    };
    const std::array<float, blockSize> expectedLinearGains{
        1.0f,
        gainDbToLinear(-6.0f),
        gainDbToLinear(6.0f),
        0.0f,
    };

    for (int sample = 0; sample < blockSize; ++sample) {
      inputBuffer.setSample(0, sample, channel0Samples[static_cast<size_t>(sample)]);
      inputBuffer.setSample(1, sample, channel1Samples[static_cast<size_t>(sample)]);
      gainBuffer.setSample(0, sample, gainParameterValues[static_cast<size_t>(sample)]);
    }

    auto processor = GainProcessor(GainProcessorModelImpl{.nodeId = nodeId});
    processor.process(context, blockSize);

    for (int sample = 0; sample < blockSize; ++sample) {
      const auto sampleIndex = static_cast<size_t>(sample);
      expectWithinAbsoluteError(outputBuffer.getSample(0, sample),
          channel0Samples[sampleIndex] * expectedLinearGains[sampleIndex],
          0.0001f,
          "Channel 0 should be multiplied by the per-sample gain.");
      expectWithinAbsoluteError(outputBuffer.getSample(1, sample),
          channel1Samples[sampleIndex] * expectedLinearGains[sampleIndex],
          0.0001f,
          "Channel 1 should be multiplied by the per-sample gain.");
    }

    graphContext.cleanup();
  }
};

static GainProcessorTest gainProcessorTest;

} // namespace anthem
