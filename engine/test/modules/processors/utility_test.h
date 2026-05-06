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
#include "modules/processing_graph/runtime/graph_process_context.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain_parameter_mapping.h"
#include "modules/processors/utility.h"

#include <array>
#include <juce_core/juce_core.h>

namespace anthem {

class UtilityProcessorTest : public juce::UnitTest {
  static constexpr int64_t nodeId = 1003;
  static constexpr int blockSize = 5;
  static constexpr int channelCount = 2;

  static std::shared_ptr<Node> makeNode() {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(graph_test_helpers::makePort(
        UtilityProcessorModelBase::audioInputPortId, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        UtilityProcessorModelBase::audioOutputPortId, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        UtilityProcessorModelBase::gainPortId, nodeId, NodePortDataType::control));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        UtilityProcessorModelBase::balancePortId, nodeId, NodePortDataType::control));
    return node;
  }
public:
  UtilityProcessorTest() : juce::UnitTest("UtilityProcessorTest", "Anthem") {}

  void runTest() override {
    testProcessAppliesGainAndStereoBalance();
  }

  void testProcessAppliesGainAndStereoBalance() {
    beginTest("Utility processing applies per-sample gain and stereo balance");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = channelCount,
            .blockSize = blockSize,
        });
    graphContext.reserve(1, 2, 2, 0);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto& outputBuffer = context.getOutputAudioBuffer(UtilityProcessorModelBase::audioOutputPortId);
    auto& inputBuffer = graphContext.getAudioBuffer(context.getBufferIndex(NodePortDataType::audio,
        NodeProcessContext::BufferDirection::input,
        UtilityProcessorModelBase::audioInputPortId));
    auto& gainBuffer =
        graphContext.getControlBuffer(context.getBufferIndex(NodePortDataType::control,
            NodeProcessContext::BufferDirection::input,
            UtilityProcessorModelBase::gainPortId));
    auto& balanceBuffer =
        graphContext.getControlBuffer(context.getBufferIndex(NodePortDataType::control,
            NodeProcessContext::BufferDirection::input,
            UtilityProcessorModelBase::balancePortId));

    const std::array<float, blockSize> gainParameterValues{kGainParameterZeroDbNormalized,
        gainDbToParameterValue(-6.0f),
        gainDbToParameterValue(6.0f),
        gainDbToParameterValue(-12.0f),
        kGainParameterZeroDbNormalized};
    const std::array<float, blockSize> expectedLinearGains{
        1.0f, gainDbToLinear(-6.0f), gainDbToLinear(6.0f), gainDbToLinear(-12.0f), 1.0f};
    const std::array<float, blockSize> balanceValues{0.0f, 0.25f, 0.5f, 0.75f, 1.0f};
    const std::array<float, blockSize> expectedLeftBalanceGains{1.0f, 1.0f, 1.0f, 0.5f, 0.0f};
    const std::array<float, blockSize> expectedRightBalanceGains{0.0f, 0.5f, 1.0f, 1.0f, 1.0f};

    for (int sample = 0; sample < blockSize; ++sample) {
      inputBuffer.setSample(0, sample, 1.0f);
      inputBuffer.setSample(1, sample, 2.0f);
      gainBuffer.setSample(0, sample, gainParameterValues[static_cast<size_t>(sample)]);
      balanceBuffer.setSample(0, sample, balanceValues[static_cast<size_t>(sample)]);
    }

    auto processor = UtilityProcessor(UtilityProcessorModelImpl{.nodeId = nodeId});
    processor.process(context, blockSize);

    for (int sample = 0; sample < blockSize; ++sample) {
      const auto sampleIndex = static_cast<size_t>(sample);

      expectWithinAbsoluteError(outputBuffer.getSample(0, sample),
          1.0f * expectedLinearGains[sampleIndex] * expectedLeftBalanceGains[sampleIndex],
          0.000001f,
          "Channel 0 should combine gain with the left balance gain.");
      expectWithinAbsoluteError(outputBuffer.getSample(1, sample),
          2.0f * expectedLinearGains[sampleIndex] * expectedRightBalanceGains[sampleIndex],
          0.000001f,
          "Channel 1 should combine gain with the right balance gain.");
    }

    graphContext.cleanup();
  }
};

static UtilityProcessorTest utilityProcessorTest;

} // namespace anthem
