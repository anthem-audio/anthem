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

#include "generated/lib/engine_api/messages/messages.h"
#include "modules/core/engine_runtime_services.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/runtime/graph_process_context.h"
#include "modules/processing_graph/runtime/node_process_context.h"
#include "modules/processors/gain.h"

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>

namespace anthem {

class ProcessingGraphModelHelpersTest : public juce::UnitTest {
  static constexpr int64_t kControlPortId = 3;

  static std::shared_ptr<Node> makeInitializedNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);
    node->initialize(node, std::shared_ptr<ModelBase>());
    return node;
  }
public:
  ProcessingGraphModelHelpersTest() : juce::UnitTest("ProcessingGraphModelHelpersTest", "Anthem") {}

  void runTest() override {
    testGetPortByIdFindsAllPortKinds();
    testGetProcessorReturnsExpectedProcessorOrNullopt();
    testProcessorOwnedParameterBindings();
    testControlledParameterReports();
  }

  void testGetPortByIdFindsAllPortKinds() {
    beginTest("Node::getPortById finds ports across all port collections");

    auto node = makeInitializedNode(10);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, 10, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, 10, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        3, 10, NodePortDataType::control, graph_test_helpers::makeParameterConfig(101, 0.25)));
    node->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(4, 10, NodePortDataType::control));
    node->eventInputPorts()->push_back(
        graph_test_helpers::makePort(5, 10, NodePortDataType::event));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(6, 10, NodePortDataType::event));

    expect(node->getPortById(1).has_value(), "Audio input ports should be discoverable by ID.");
    expect(node->getPortById(2).has_value(), "Audio output ports should be discoverable by ID.");
    expect(node->getPortById(3).has_value(), "Control input ports should be discoverable by ID.");
    expect(node->getPortById(4).has_value(), "Control output ports should be discoverable by ID.");
    expect(node->getPortById(5).has_value(), "Event input ports should be discoverable by ID.");
    expect(node->getPortById(6).has_value(), "Event output ports should be discoverable by ID.");
    expect(!node->getPortById(9999).has_value(), "Missing port IDs should return nullopt.");
  }

  void testGetProcessorReturnsExpectedProcessorOrNullopt() {
    beginTest("Node::getProcessor returns the wrapped processor instance when present");

    auto processorlessNode = graph_test_helpers::makeNode(10);
    auto gainNode = graph_test_helpers::makeGainNode(20);

    auto missingProcessor = processorlessNode->getProcessor();
    auto processor = gainNode->getProcessor();

    expect(!missingProcessor.has_value(), "Nodes without processors should return nullopt.");
    expect(processor.has_value(), "Nodes with processors should return a processor instance.");
    expect(dynamic_cast<GainProcessor*>(processor.value().get()) != nullptr,
        "The returned processor should preserve its concrete processor type.");
  }

  void testProcessorOwnedParameterBindings() {
    beginTest("Compiled contexts retain the same processor-owned base values");
    auto node = graph_test_helpers::makeGainNode(10);
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(kControlPortId,
        10,
        NodePortDataType::control,
        graph_test_helpers::makeParameterConfig(kControlPortId, 0.25)));
    graph_test_helpers::prepareTestParameters(node);
    const auto processor = *node->getProcessor();
    expect(!processor->setParameterValue(kControlPortId, 0.75));
    EngineRuntimeServices services;
    GraphProcessContext first(services, {.numAudioChannels = 2, .blockSize = 16});
    GraphProcessContext::Builder firstBuilder(first);
    firstBuilder.reserve(1, 0, 1, 0);
    auto& before =
        graph_test_helpers::createStandaloneNodeProcessContext(first, firstBuilder, node);
    expectWithinAbsoluteError(before.getParameterValue(kControlPortId), 0.75f, 0.0001f);
    GraphProcessContext second(services, {.numAudioChannels = 2, .blockSize = 16});
    GraphProcessContext::Builder secondBuilder(second);
    secondBuilder.reserve(1, 0, 1, 0);
    auto& after =
        graph_test_helpers::createStandaloneNodeProcessContext(second, secondBuilder, node);
    expect(!processor->setParameterValue(kControlPortId, 0.6));
    expectWithinAbsoluteError(before.getParameterValue(kControlPortId), 0.6f, 0.0001f);
    expectWithinAbsoluteError(after.getParameterValue(kControlPortId), 0.6f, 0.0001f);
    first.cleanup();
    second.cleanup();
  }

  void testControlledParameterReports() {
    beginTest("Automation and delayed reports preserve the base value");
    GainProcessor processor(GainProcessorModelImpl{.nodeId = 10});
    processor.restoreParameterValues({{kControlPortId, 0.25}});
    const auto parameter = processor.getParameter(kControlPortId);
    expect(parameter->acceptChange(0.5f, 0));
    parameter->rt_setControlled(true);
    const auto controlled = parameter->controlRevision.load();
    expect(!parameter->acceptChange(0.9f, controlled));
    parameter->rt_setControlled(false);
    expect(!parameter->acceptChange(0.9f, controlled));
    expect(!parameter->acceptChange(0.8f, 0));
    expectWithinAbsoluteError(parameter->value.load(), 0.5f, 0.0001f);
    expect(parameter->acceptChange(0.6f, parameter->controlRevision.load()));
  }
};

static ProcessingGraphModelHelpersTest processingGraphModelHelpersTest;

} // namespace anthem
