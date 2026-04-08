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
#include "modules/processing_graph/compiler/anthem_graph_process_context.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/model/node.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"

#include <juce_core/juce_core.h>
#include <juce_events/juce_events.h>

class ProcessingGraphModelHelpersTest : public juce::UnitTest {
  static constexpr int64_t kControlPortId = 3;

  static std::shared_ptr<Node> makeInitializedNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);
    node->initialize(node, std::shared_ptr<AnthemModelBase>());
    return node;
  }

  static std::shared_ptr<Node> makeInitializedNodeWithControlParameter(int64_t nodeId,
                                                                       double parameterValue) {
    auto node = makeInitializedNode(nodeId);
    node->controlInputPorts()->push_back(
        graph_test_helpers::makePort(kControlPortId,
                                     nodeId,
                                     NodePortDataType::control,
                                     parameterValue,
                                     graph_test_helpers::makeParameterConfig(101, parameterValue)));
    return node;
  }

  static std::shared_ptr<NodePort> makeStandaloneInitializedParameterPort(int64_t nodeId,
                                                                          double parameterValue) {
    auto port =
        graph_test_helpers::makePort(kControlPortId,
                                     nodeId,
                                     NodePortDataType::control,
                                     parameterValue,
                                     graph_test_helpers::makeParameterConfig(101, parameterValue));
    port->initialize(port, std::shared_ptr<AnthemModelBase>());
    return port;
  }

  static ModelUpdateRequest makeParameterValueUpdateRequest(double value) {
    auto fieldAccesses = std::make_shared<std::vector<std::shared_ptr<FieldAccess>>>();
    fieldAccesses->push_back(std::make_shared<FieldAccess>(FieldAccess{
        .fieldType = FieldType::raw,
        .fieldName = std::make_optional<std::string>("parameterValue"),
        .serializedMapKey = std::nullopt,
        .listIndex = std::nullopt,
    }));

    return ModelUpdateRequest{
        .updateKind = FieldUpdateKind::set,
        .fieldAccesses = fieldAccesses,
        .serializedValue = rfl::json::write(std::optional<double>(value)),
        .requestBase = RequestBase{.id = 1},
    };
  }

  static void applyParameterValueUpdate(NodePort& port, double value) {
    auto request = makeParameterValueUpdateRequest(value);
    port.handleModelUpdate(request, 0);
  }
public:
  ProcessingGraphModelHelpersTest() : juce::UnitTest("ProcessingGraphModelHelpersTest", "Anthem") {}

  void runTest() override {
    testGetPortByIdFindsAllPortKinds();
    testGetProcessorReturnsExpectedProcessorOrNullopt();
    testNodePortParameterUpdatesPropagateToRuntimeContext();
    testNodePortParameterUpdatesStayLocalWithoutRuntimeContext();
    testNodePortParameterUpdatesStayLocalWithoutNodeAncestry();
  }

  void testGetPortByIdFindsAllPortKinds() {
    beginTest("Node::getPortById finds ports across all port collections");

    auto node = makeInitializedNode(10);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, 10, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, 10, NodePortDataType::audio));
    node->controlInputPorts()->push_back(
        graph_test_helpers::makePort(3,
                                     10,
                                     NodePortDataType::control,
                                     0.25,
                                     graph_test_helpers::makeParameterConfig(101, 0.25)));
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

  void testNodePortParameterUpdatesPropagateToRuntimeContext() {
    beginTest("NodePort parameter updates propagate into the node runtime context");

    juce::ScopedJuceInitialiser_GUI juceInitialiser;

    auto node = makeInitializedNodeWithControlParameter(10, 0.25);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 16,
                                           });
    graphContext.reserve(1, 0, 1, 0);

    auto& nodeContext = graphContext.createNodeProcessContext(node);
    node->runtimeContext = std::make_optional(&nodeContext);

    auto& port = *node->controlInputPorts()->at(0);

    applyParameterValueUpdate(port, 0.75);

    expectWithinAbsoluteError(nodeContext.getParameterValue(kControlPortId),
                              0.75f,
                              0.0001f,
                              "Parameter updates should be forwarded to the runtime context.");
    expect(port.parameterValue().has_value(), "The model parameter value should also update.");
    expectWithinAbsoluteError(static_cast<float>(port.parameterValue().value()),
                              0.75f,
                              0.0001f,
                              "The model should keep the latest parameter value.");

    graphContext.cleanup();
  }

  void testNodePortParameterUpdatesStayLocalWithoutRuntimeContext() {
    beginTest("NodePort parameter updates stay local when the node has no runtime context");

    auto node = makeInitializedNodeWithControlParameter(10, 0.25);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 16,
                                           });
    graphContext.reserve(1, 0, 1, 0);

    auto& nodeContext = graphContext.createNodeProcessContext(node);
    auto& port = *node->controlInputPorts()->at(0);

    applyParameterValueUpdate(port, 0.75);

    expectWithinAbsoluteError(
        nodeContext.getParameterValue(kControlPortId),
        0.25f,
        0.0001f,
        "Without a runtime context, the audio-thread parameter binding should remain unchanged.");
    expect(port.parameterValue().has_value(), "The model parameter value should still update.");
    expectWithinAbsoluteError(static_cast<float>(port.parameterValue().value()),
                              0.75f,
                              0.0001f,
                              "The model should still store the new parameter value.");

    graphContext.cleanup();
  }

  void testNodePortParameterUpdatesStayLocalWithoutNodeAncestry() {
    beginTest("NodePort parameter updates stay local when the port is not attached to a node");

    auto port = makeStandaloneInitializedParameterPort(10, 0.25);

    applyParameterValueUpdate(*port, 0.6);

    expect(port->parameterValue().has_value(),
           "The standalone port should still store the updated model value.");
    expectWithinAbsoluteError(
        static_cast<float>(port->parameterValue().value()),
        0.6f,
        0.0001f,
        "Broken ancestry should prevent runtime propagation without blocking the model update.");
  }
};

static ProcessingGraphModelHelpersTest processingGraphModelHelpersTest;
