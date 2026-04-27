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
#include "modules/processing_graph_threaded/model/runtime_graph.h"

#include <juce_core/juce_core.h>
#include <stdexcept>

namespace anthem {

class ThreadedRuntimeGraphTest : public juce::UnitTest {
  static int64_t inputPortId(int64_t nodeId) {
    return nodeId * 10 + 1;
  }

  static int64_t outputPortId(int64_t nodeId) {
    return nodeId * 10 + 2;
  }

  static std::shared_ptr<Node> addGraphNode(ProcessingGraphModel& graph, int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(inputPortId(nodeId), nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(outputPortId(nodeId), nodeId, NodePortDataType::audio));

    graph.nodes()->insert_or_assign(nodeId, node);

    return node;
  }

  static void addConnection(ProcessingGraphModel& graph,
      int64_t connectionId,
      int64_t sourceNodeId,
      int64_t destinationNodeId) {
    auto& nodes = *graph.nodes();
    auto& sourceNode = nodes.at(sourceNodeId);
    auto& destinationNode = nodes.at(destinationNodeId);

    auto connection = graph_test_helpers::makeConnection(connectionId,
        sourceNodeId,
        outputPortId(sourceNodeId),
        destinationNodeId,
        inputPortId(destinationNodeId));

    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(connectionId);
    destinationNode->audioInputPorts()->at(0)->connections()->push_back(connectionId);

    graph.connections()->insert_or_assign(connectionId, connection);
  }

  static bool hasInputNode(const threaded_graph::RuntimeGraph& runtimeGraph, int64_t nodeId) {
    for (auto* inputNode : runtimeGraph.inputNodes) {
      if (inputNode->id == nodeId) {
        return true;
      }
    }

    return false;
  }

  static bool buildThrowsRuntimeError(ProcessingGraphModel& graph) {
    try {
      (void)threaded_graph::RuntimeGraph::fromProcessingGraph(graph);
    } catch (const std::runtime_error&) {
      return true;
    }

    return false;
  }
public:
  ThreadedRuntimeGraphTest() : juce::UnitTest("ThreadedRuntimeGraphTest", "Anthem") {}

  void runTest() override {
    testBuildsNodesInputNodesAndEdges();
    testDeduplicatesNodeConnections();
    testDetectsReachableCycle();
    testDetectsCycleWithoutInputNodes();
  }

  void testBuildsNodesInputNodesAndEdges() {
    beginTest("RuntimeGraph builds nodes, input nodes, and outgoing edges");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 3);
    addConnection(*graph, 101, 2, 3);

    auto runtimeGraph = threaded_graph::RuntimeGraph::fromProcessingGraph(*graph);

    expectEquals(static_cast<int>(runtimeGraph.nodes.size()), 3, "All graph nodes should copy.");
    expectEquals(static_cast<int>(runtimeGraph.inputNodes.size()),
        2,
        "Nodes without upstream dependencies should be listed as input nodes.");
    expect(hasInputNode(runtimeGraph, 1), "Node 1 should be an input node.");
    expect(hasInputNode(runtimeGraph, 2), "Node 2 should be an input node.");
    expect(!hasInputNode(runtimeGraph, 3), "Node 3 should not be an input node.");

    auto& firstNode = runtimeGraph.nodes.at(1);
    auto& secondNode = runtimeGraph.nodes.at(2);
    auto& thirdNode = runtimeGraph.nodes.at(3);

    expectEquals(static_cast<int>(firstNode.upstreamNodeCount), 0);
    expectEquals(static_cast<int>(secondNode.upstreamNodeCount), 0);
    expectEquals(static_cast<int>(thirdNode.upstreamNodeCount), 2);

    expectEquals(static_cast<int>(firstNode.outgoingConnections.size()), 1);
    expectEquals(static_cast<int>(secondNode.outgoingConnections.size()), 1);
    expectEquals(static_cast<int>(thirdNode.outgoingConnections.size()), 0);
    expect(firstNode.outgoingConnections[0] == &thirdNode,
        "Node 1 should point to its downstream node.");
    expect(secondNode.outgoingConnections[0] == &thirdNode,
        "Node 2 should point to its downstream node.");
  }

  void testDeduplicatesNodeConnections() {
    beginTest("RuntimeGraph deduplicates multiple wires between the same two nodes");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 1, 2);

    auto runtimeGraph = threaded_graph::RuntimeGraph::fromProcessingGraph(*graph);

    auto& sourceNode = runtimeGraph.nodes.at(1);
    auto& destinationNode = runtimeGraph.nodes.at(2);

    expectEquals(static_cast<int>(sourceNode.outgoingConnections.size()),
        1,
        "Duplicate node-level edges should be collapsed.");
    expect(sourceNode.outgoingConnections[0] == &destinationNode,
        "The deduplicated edge should still point to the destination node.");
    expectEquals(static_cast<int>(destinationNode.upstreamNodeCount),
        1,
        "Duplicate node-level edges should only count as one upstream node.");
  }

  void testDetectsReachableCycle() {
    beginTest("RuntimeGraph detects a cycle reachable from an input node");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 2, 3);
    addConnection(*graph, 102, 3, 2);

    expect(buildThrowsRuntimeError(*graph),
        "RuntimeGraph should reject cycles reachable from input nodes.");
  }

  void testDetectsCycleWithoutInputNodes() {
    beginTest("RuntimeGraph detects a cycle when the graph has no input nodes");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 2, 1);

    expect(buildThrowsRuntimeError(*graph),
        "RuntimeGraph should reject pure cycles that have no input nodes.");
  }
};

static ThreadedRuntimeGraphTest threadedRuntimeGraphTest;

} // namespace anthem
