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

#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph_threaded/runtime/graph_process_context.h"
#include "modules/processing_graph_threaded/runtime/graph_runtime_services.h"
#include "modules/processors/balance.h"

#include <array>
#include <juce_core/juce_core.h>

namespace anthem {

class BalanceProcessorTest : public juce::UnitTest {
  static constexpr int64_t nodeId = 1002;
  static constexpr int blockSize = 5;
  static constexpr int channelCount = 2;

  static std::shared_ptr<Node> makeNode() {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(graph_test_helpers::makePort(
        BalanceProcessorModelBase::audioInputPortId, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        BalanceProcessorModelBase::audioOutputPortId, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        BalanceProcessorModelBase::balancePortId, nodeId, NodePortDataType::control));

    return node;
  }
public:
  BalanceProcessorTest() : juce::UnitTest("BalanceProcessorTest", "Anthem") {}

  void runTest() override {
    testProcessAppliesStereoBalance();
  }

  void testProcessAppliesStereoBalance() {
    beginTest("Balance processing applies the expected stereo gains");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = channelCount,
            .blockSize = blockSize,
        });
    graphContext.reserve(1, 2, 1, 0);

    auto& context = graphContext.createNodeProcessContext(node);
    auto& inputBuffer = context.getInputAudioBuffer(BalanceProcessorModelBase::audioInputPortId);
    auto& outputBuffer = context.getOutputAudioBuffer(BalanceProcessorModelBase::audioOutputPortId);
    auto& balanceBuffer = context.getInputControlBuffer(BalanceProcessorModelBase::balancePortId);

    const std::array<float, blockSize> balanceValues{0.0f, 0.25f, 0.5f, 0.75f, 1.0f};
    const std::array<float, blockSize> expectedLeftGains{1.0f, 1.0f, 1.0f, 0.5f, 0.0f};
    const std::array<float, blockSize> expectedRightGains{0.0f, 0.5f, 1.0f, 1.0f, 1.0f};

    for (int sample = 0; sample < blockSize; ++sample) {
      inputBuffer.setSample(0, sample, 1.0f);
      inputBuffer.setSample(1, sample, 2.0f);
      balanceBuffer.setSample(0, sample, balanceValues[static_cast<size_t>(sample)]);
    }

    auto processor = BalanceProcessor(BalanceProcessorModelImpl{.nodeId = nodeId});
    processor.process(context, blockSize);

    for (int sample = 0; sample < blockSize; ++sample) {
      const auto sampleIndex = static_cast<size_t>(sample);
      expectWithinAbsoluteError(outputBuffer.getSample(0, sample),
          1.0f * expectedLeftGains[sampleIndex],
          0.0001f,
          "Channel 0 should follow the left balance gain.");
      expectWithinAbsoluteError(outputBuffer.getSample(1, sample),
          2.0f * expectedRightGains[sampleIndex],
          0.0001f,
          "Channel 1 should follow the right balance gain.");
    }

    graphContext.cleanup();
  }
};

static BalanceProcessorTest balanceProcessorTest;

} // namespace anthem
