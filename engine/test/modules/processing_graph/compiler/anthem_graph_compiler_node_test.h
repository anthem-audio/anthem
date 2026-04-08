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

#include "modules/processing_graph/compiler/anthem_graph_compiler_node.h"
#include "modules/processing_graph/compiler/anthem_graph_process_context.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"

#include <juce_core/juce_core.h>

class AnthemGraphCompilerNodeTest : public juce::UnitTest {
  using NodeMap = AnthemGraphCompilerNode::NodeMap;
  using ConnectionMap = AnthemGraphCompilerNode::ConnectionMap;

  static std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>>
  buildCompilerNodeMap(std::initializer_list<std::shared_ptr<Node>> nodes,
                       AnthemGraphProcessContext& graphContext) {
    auto compilerNodes = std::map<Node*, std::shared_ptr<AnthemGraphCompilerNode>>();

    for (const auto& node : nodes) {
      auto& context =
          graphContext.createNodeProcessContext(const_cast<std::shared_ptr<Node>&>(node));
      auto compilerNode = std::make_shared<AnthemGraphCompilerNode>(node, &context);
      compilerNodes.insert_or_assign(node.get(), compilerNode);
    }

    return compilerNodes;
  }
public:
  AnthemGraphCompilerNodeTest() : juce::UnitTest("AnthemGraphCompilerNodeTest", "Anthem") {}

  void runTest() override {
    testInputAndOutputEdgesAreAssigned();
    testSharedConnectionIsDeduplicatedAcrossNodes();
    testMixedPortTypesProduceMatchingEdgeTypes();
    testInvalidPortsAreSkipped();
  }

  void testInputAndOutputEdgesAreAssigned() {
    beginTest("Input and output edges are assigned for a simple audio connection");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;
    constexpr int64_t connectionId = 100;

    auto sourceNode = graph_test_helpers::makeGainNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeMasterOutputNode(sinkNodeId);

    sourceNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioInputPortId, sourceNodeId, NodePortDataType::audio));
    sourceNode->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioOutputPortId, sourceNodeId, NodePortDataType::audio));
    sourceNode->controlInputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::gainPortId,
                                     sourceNodeId,
                                     NodePortDataType::control,
                                     0.5,
                                     graph_test_helpers::makeParameterConfig(101, 0.5)));
    sinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, sinkNodeId, NodePortDataType::audio));

    auto connection =
        graph_test_helpers::makeConnection(connectionId,
                                           sourceNodeId,
                                           GainProcessorModelBase::audioOutputPortId,
                                           sinkNodeId,
                                           MasterOutputProcessorModelBase::inputPortId);

    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(connectionId);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(connectionId);

    NodeMap nodes;
    nodes.insert_or_assign(sourceNodeId, sourceNode);
    nodes.insert_or_assign(sinkNodeId, sinkNode);

    ConnectionMap connections;
    connections.insert_or_assign(connectionId, connection);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 64,
                                           });
    graphContext.reserve(2, 3, 1, 0);

    auto compilerNodes = buildCompilerNodeMap({sourceNode, sinkNode}, graphContext);
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

    compilerNodes.at(sourceNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);
    compilerNodes.at(sinkNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);

    auto& sourceCompilerNode = *compilerNodes.at(sourceNode.get());
    auto& sinkCompilerNode = *compilerNodes.at(sinkNode.get());

    expectEquals(static_cast<int>(sourceCompilerNode.outputEdges.size()),
                 1,
                 "The source node should expose one output edge.");
    expectEquals(static_cast<int>(sinkCompilerNode.inputEdges.size()),
                 1,
                 "The sink node should expose one input edge.");
    expect(sourceCompilerNode.outputEdges.at(0) == sinkCompilerNode.inputEdges.at(0),
           "The source and sink should reference the same compiler edge.");
    expectEquals(static_cast<int>(sourceCompilerNode.outputEdges.at(0)->type),
                 static_cast<int>(NodePortDataType::audio),
                 "The assigned edge type should match the source port type.");

    graphContext.cleanup();
  }

  void testSharedConnectionIsDeduplicatedAcrossNodes() {
    beginTest("Shared connections are deduplicated across source and destination nodes");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;
    constexpr int64_t connectionId = 100;

    auto sourceNode = graph_test_helpers::makeNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeNode(sinkNodeId);

    sourceNode->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(1, sourceNodeId, NodePortDataType::event));
    sinkNode->eventInputPorts()->push_back(
        graph_test_helpers::makePort(2, sinkNodeId, NodePortDataType::event));

    auto connection =
        graph_test_helpers::makeConnection(connectionId, sourceNodeId, 1, sinkNodeId, 2);
    sourceNode->eventOutputPorts()->at(0)->connections()->push_back(connectionId);
    sinkNode->eventInputPorts()->at(0)->connections()->push_back(connectionId);

    NodeMap nodes;
    nodes.insert_or_assign(sourceNodeId, sourceNode);
    nodes.insert_or_assign(sinkNodeId, sinkNode);

    ConnectionMap connections;
    connections.insert_or_assign(connectionId, connection);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 64,
                                           });
    graphContext.reserve(2, 0, 0, 2);

    auto compilerNodes = buildCompilerNodeMap({sourceNode, sinkNode}, graphContext);
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

    compilerNodes.at(sourceNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);
    compilerNodes.at(sinkNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);

    expectEquals(static_cast<int>(connectionToCompilerEdge.size()),
                 1,
                 "The shared connection should create only one compiler edge instance.");
    expect(compilerNodes.at(sourceNode.get())->outputEdges.at(0) ==
               compilerNodes.at(sinkNode.get())->inputEdges.at(0),
           "Both nodes should reuse the same compiler edge object.");

    graphContext.cleanup();
  }

  void testMixedPortTypesProduceMatchingEdgeTypes() {
    beginTest("Mixed port types produce matching compiler edge types");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;

    auto sourceNode = graph_test_helpers::makeNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeNode(sinkNodeId);

    sourceNode->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(1, sourceNodeId, NodePortDataType::audio));
    sourceNode->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(2, sourceNodeId, NodePortDataType::control));
    sourceNode->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(3, sourceNodeId, NodePortDataType::event));

    sinkNode->audioInputPorts()->push_back(
        graph_test_helpers::makePort(4, sinkNodeId, NodePortDataType::audio));
    sinkNode->controlInputPorts()->push_back(
        graph_test_helpers::makePort(5, sinkNodeId, NodePortDataType::control, 0.5));
    sinkNode->eventInputPorts()->push_back(
        graph_test_helpers::makePort(6, sinkNodeId, NodePortDataType::event));

    auto audioConnection = graph_test_helpers::makeConnection(100, sourceNodeId, 1, sinkNodeId, 4);
    auto controlConnection =
        graph_test_helpers::makeConnection(101, sourceNodeId, 2, sinkNodeId, 5);
    auto eventConnection = graph_test_helpers::makeConnection(102, sourceNodeId, 3, sinkNodeId, 6);

    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    sourceNode->controlOutputPorts()->at(0)->connections()->push_back(101);
    sourceNode->eventOutputPorts()->at(0)->connections()->push_back(102);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(100);
    sinkNode->controlInputPorts()->at(0)->connections()->push_back(101);
    sinkNode->eventInputPorts()->at(0)->connections()->push_back(102);

    NodeMap nodes;
    nodes.insert_or_assign(sourceNodeId, sourceNode);
    nodes.insert_or_assign(sinkNodeId, sinkNode);

    ConnectionMap connections;
    connections.insert_or_assign(100, audioConnection);
    connections.insert_or_assign(101, controlConnection);
    connections.insert_or_assign(102, eventConnection);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 64,
                                           });
    graphContext.reserve(2, 2, 2, 2);

    auto compilerNodes = buildCompilerNodeMap({sourceNode, sinkNode}, graphContext);
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

    compilerNodes.at(sourceNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);

    expectEquals(static_cast<int>(compilerNodes.at(sourceNode.get())->outputEdges.size()),
                 3,
                 "All outgoing edge types should be discovered.");
    expectEquals(static_cast<int>(compilerNodes.at(sourceNode.get())->outputEdges.at(0)->type),
                 static_cast<int>(NodePortDataType::audio),
                 "Audio edges should keep the audio type.");
    expectEquals(static_cast<int>(compilerNodes.at(sourceNode.get())->outputEdges.at(1)->type),
                 static_cast<int>(NodePortDataType::control),
                 "Control edges should keep the control type.");
    expectEquals(static_cast<int>(compilerNodes.at(sourceNode.get())->outputEdges.at(2)->type),
                 static_cast<int>(NodePortDataType::event),
                 "Event edges should keep the event type.");

    graphContext.cleanup();
  }

  void testInvalidPortsAreSkipped() {
    beginTest("Invalid ports are skipped instead of producing compiler edges");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;
    constexpr int64_t connectionId = 100;

    auto sourceNode = graph_test_helpers::makeNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeNode(sinkNodeId);

    sourceNode->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(1, sourceNodeId, NodePortDataType::audio));
    sinkNode->audioInputPorts()->push_back(
        graph_test_helpers::makePort(2, sinkNodeId, NodePortDataType::audio));

    auto invalidConnection =
        graph_test_helpers::makeConnection(connectionId, sourceNodeId, 1, sinkNodeId, 9999);
    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(connectionId);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(connectionId);

    NodeMap nodes;
    nodes.insert_or_assign(sourceNodeId, sourceNode);
    nodes.insert_or_assign(sinkNodeId, sinkNode);

    ConnectionMap connections;
    connections.insert_or_assign(connectionId, invalidConnection);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 64,
                                           });
    graphContext.reserve(2, 2, 0, 0);

    auto compilerNodes = buildCompilerNodeMap({sourceNode, sinkNode}, graphContext);
    std::map<NodeConnection*, std::shared_ptr<AnthemGraphCompilerEdge>> connectionToCompilerEdge;

    compilerNodes.at(sourceNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);
    compilerNodes.at(sinkNode.get())
        ->assignEdges(nodes, connections, compilerNodes, connectionToCompilerEdge);

    expectEquals(static_cast<int>(connectionToCompilerEdge.size()),
                 0,
                 "Invalid ports should prevent compiler-edge creation.");
    expectEquals(static_cast<int>(compilerNodes.at(sourceNode.get())->outputEdges.size()),
                 0,
                 "Invalid edges should not appear in the source output edge list.");
    expectEquals(static_cast<int>(compilerNodes.at(sinkNode.get())->inputEdges.size()),
                 0,
                 "Invalid edges should not appear in the destination input edge list.");

    graphContext.cleanup();
  }
};

static AnthemGraphCompilerNodeTest anthemGraphCompilerNodeTest;
