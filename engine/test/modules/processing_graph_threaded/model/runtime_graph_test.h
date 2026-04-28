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
#include "modules/processing_graph_threaded/executor/graph_executor.h"
#include "modules/processing_graph_threaded/executor/graph_executor_shared.h"
#include "modules/processing_graph_threaded/model/runtime_graph.h"
#include "modules/processing_graph_threaded/runtime/graph_runtime_services.h"
#include "modules/processing_graph_threaded/runtime/node_process_context.h"

#include <atomic>
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

  static std::unique_ptr<threaded_graph::RuntimeGraph> buildRuntimeGraph(
      ProcessingGraphModel& graph, GraphRuntimeServices& rtServices) {
    return threaded_graph::RuntimeGraph::fromProcessingGraph(graph,
        rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 8,
        },
        44100.0);
  }

  static bool buildThrowsRuntimeError(ProcessingGraphModel& graph) {
    GraphRuntimeServices rtServices;

    try {
      (void)buildRuntimeGraph(graph, rtServices);
    } catch (const std::runtime_error&) {
      return true;
    }

    return false;
  }

  static void processRuntimeGraph(threaded_graph::RuntimeGraph& runtimeGraph, int numSamples) {
    threaded_graph::GraphExecutor executor;
    executor.rt_processBlock(runtimeGraph, numSamples);
  }
public:
  ThreadedRuntimeGraphTest() : juce::UnitTest("ThreadedRuntimeGraphTest", "Anthem") {}

  void runTest() override {
    testBuildsNodesInputNodesAndEdges();
    testDeduplicatesNodeConnections();
    testPrepareGraphForBlockResetsRemainingUpstreamNodeCounters();
    testDecrementRemainingUpstreamNodeCounter();
    testSingleThreadedExecutorCopiesAudioToReadyDownstreamNodes();
    testSingleThreadedExecutorHandlesDuplicateEdges();
    testSingleThreadedExecutorProcessesNodesWithoutProcessors();
    testCalculatesLinearPriorities();
    testCalculatesDiamondPriorities();
    testCalculatesDisconnectedComponentPriorities();
    testAvailableTaskQueueOrdersByPriorityThenId();
    testDetectsReachableCycle();
    testDetectsCycleWithoutInputNodes();
  }

  void testBuildsNodesInputNodesAndEdges() {
    beginTest("RuntimeGraph builds nodes, input nodes, and outgoing edges");

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto firstGraphNode = addGraphNode(*graph, 1);
    auto secondGraphNode = addGraphNode(*graph, 2);
    auto thirdGraphNode = addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 3);
    addConnection(*graph, 101, 2, 3);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    expectEquals(static_cast<int>(runtimeGraph->nodes.size()), 3, "All graph nodes should copy.");
    expectEquals(static_cast<int>(runtimeGraph->inputNodes.size()),
        2,
        "Nodes without upstream dependencies should be listed as input nodes.");
    expect(hasInputNode(*runtimeGraph, 1), "Node 1 should be an input node.");
    expect(hasInputNode(*runtimeGraph, 2), "Node 2 should be an input node.");
    expect(!hasInputNode(*runtimeGraph, 3), "Node 3 should not be an input node.");

    auto& firstNode = runtimeGraph->nodes.at(1);
    auto& secondNode = runtimeGraph->nodes.at(2);
    auto& thirdNode = runtimeGraph->nodes.at(3);

    expectEquals(static_cast<int>(firstNode.upstreamNodeCount), 0);
    expectEquals(static_cast<int>(secondNode.upstreamNodeCount), 0);
    expectEquals(static_cast<int>(thirdNode.upstreamNodeCount), 2);
    expectEquals(static_cast<int>(firstNode.priority), 2);
    expectEquals(static_cast<int>(secondNode.priority), 2);
    expectEquals(static_cast<int>(thirdNode.priority), 1);
    expect(firstNode.sourceNode == firstGraphNode,
        "Runtime nodes should keep their source graph nodes alive.");
    expect(secondNode.sourceNode == secondGraphNode,
        "Runtime nodes should keep their source graph nodes alive.");
    expect(thirdNode.sourceNode == thirdGraphNode,
        "Runtime nodes should keep their source graph nodes alive.");
    expect(firstGraphNode->runtimeContext.has_value(),
        "The source node should point at the new runtime context.");
    expect(firstGraphNode->runtimeContext.value() == firstNode.nodeProcessContext,
        "The source node should point at the threaded runtime context.");

    expectEquals(static_cast<int>(firstNode.outgoingConnections.size()), 1);
    expectEquals(static_cast<int>(secondNode.outgoingConnections.size()), 1);
    expectEquals(static_cast<int>(thirdNode.outgoingConnections.size()), 0);
    expect(firstNode.outgoingConnections[0] == &thirdNode,
        "Node 1 should point to its downstream node.");
    expect(secondNode.outgoingConnections[0] == &thirdNode,
        "Node 2 should point to its downstream node.");
    expectEquals(static_cast<int>(thirdNode.incomingConnectionCopies.size()),
        2,
        "Each real incoming connection should have a copy operation.");
  }

  void testDeduplicatesNodeConnections() {
    beginTest("RuntimeGraph deduplicates multiple wires between the same two nodes");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 1, 2);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    auto& sourceNode = runtimeGraph->nodes.at(1);
    auto& destinationNode = runtimeGraph->nodes.at(2);

    expectEquals(static_cast<int>(sourceNode.outgoingConnections.size()),
        1,
        "Duplicate node-level edges should be collapsed.");
    expect(sourceNode.outgoingConnections[0] == &destinationNode,
        "The deduplicated edge should still point to the destination node.");
    expectEquals(static_cast<int>(destinationNode.upstreamNodeCount),
        1,
        "Duplicate node-level edges should only count as one upstream node.");
    expectEquals(static_cast<int>(destinationNode.incomingConnectionCopies.size()),
        2,
        "Duplicate real connections should still create separate copy operations.");
    expectEquals(static_cast<int>(sourceNode.priority),
        2,
        "Duplicate node-level edges should only contribute once to priority.");
    expectEquals(static_cast<int>(destinationNode.priority), 1);
  }

  void testPrepareGraphForBlockResetsRemainingUpstreamNodeCounters() {
    beginTest("Runtime graph block preparation resets remaining upstream node counters");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 3);
    addConnection(*graph, 101, 2, 3);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    for (auto& [_, runtimeNode] : runtimeGraph->nodes) {
      runtimeNode.rt_state.rt_remainingUpstreamNodes.store(99, std::memory_order_relaxed);
    }

    threaded_graph::GraphExecutorState executorState(*runtimeGraph);
    threaded_graph::rt_prepareGraphForBlock(executorState);

    expectEquals(static_cast<int>(runtimeGraph->nodes.at(1).rt_state.rt_remainingUpstreamNodes.load(
                     std::memory_order_relaxed)),
        0);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(2).rt_state.rt_remainingUpstreamNodes.load(
                     std::memory_order_relaxed)),
        0);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(3).rt_state.rt_remainingUpstreamNodes.load(
                     std::memory_order_relaxed)),
        2);
  }

  void testDecrementRemainingUpstreamNodeCounter() {
    beginTest("Runtime graph atomically decrements remaining upstream node counters");

    threaded_graph::RuntimeNode runtimeNode(1, nullptr);
    runtimeNode.rt_state.rt_remainingUpstreamNodes.store(2, std::memory_order_relaxed);

    expect(!threaded_graph::rt_decrementRemainingUpstreamNodes(runtimeNode),
        "The node should not be ready while one upstream node remains.");
    expectEquals(static_cast<int>(runtimeNode.rt_state.rt_remainingUpstreamNodes.load(
                     std::memory_order_relaxed)),
        1);

    expect(threaded_graph::rt_decrementRemainingUpstreamNodes(runtimeNode),
        "The node should be ready when the counter reaches zero.");
    expectEquals(static_cast<int>(runtimeNode.rt_state.rt_remainingUpstreamNodes.load(
                     std::memory_order_relaxed)),
        0);
  }

  void testSingleThreadedExecutorCopiesAudioToReadyDownstreamNodes() {
    beginTest("Single-threaded executor copies audio to ready downstream nodes");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addConnection(*graph, 100, 1, 2);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    auto& sourceOutputBuffer =
        runtimeGraph->nodes.at(1).nodeProcessContext->getOutputAudioBuffer(outputPortId(1));

    for (int channel = 0; channel < sourceOutputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        sourceOutputBuffer.setSample(channel, sample, static_cast<float>(channel * 10 + sample));
      }
    }

    processRuntimeGraph(*runtimeGraph, 4);

    auto& destinationInputBuffer =
        runtimeGraph->nodes.at(2).nodeProcessContext->getInputAudioBuffer(inputPortId(2));

    for (int channel = 0; channel < destinationInputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        expectWithinAbsoluteError(destinationInputBuffer.getSample(channel, sample),
            static_cast<float>(channel * 10 + sample),
            0.0001f);
      }
    }
  }

  void testSingleThreadedExecutorHandlesDuplicateEdges() {
    beginTest("Single-threaded executor handles duplicate edges");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 1, 2);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    auto& sourceOutputBuffer =
        runtimeGraph->nodes.at(1).nodeProcessContext->getOutputAudioBuffer(outputPortId(1));

    for (int channel = 0; channel < sourceOutputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        sourceOutputBuffer.setSample(channel, sample, static_cast<float>(sample + 1));
      }
    }

    processRuntimeGraph(*runtimeGraph, 4);

    auto& destinationInputBuffer =
        runtimeGraph->nodes.at(2).nodeProcessContext->getInputAudioBuffer(inputPortId(2));

    for (int channel = 0; channel < destinationInputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        expectWithinAbsoluteError(destinationInputBuffer.getSample(channel, sample),
            static_cast<float>((sample + 1) * 2),
            0.0001f);
      }
    }
  }

  void testSingleThreadedExecutorProcessesNodesWithoutProcessors() {
    beginTest("Single-threaded executor processes nodes without processors");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 2, 3);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    auto& firstOutputBuffer =
        runtimeGraph->nodes.at(1).nodeProcessContext->getOutputAudioBuffer(outputPortId(1));
    auto& secondOutputBuffer =
        runtimeGraph->nodes.at(2).nodeProcessContext->getOutputAudioBuffer(outputPortId(2));

    for (int channel = 0; channel < firstOutputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        firstOutputBuffer.setSample(channel, sample, static_cast<float>(sample + 1));
        secondOutputBuffer.setSample(channel, sample, static_cast<float>(sample + 10));
      }
    }

    processRuntimeGraph(*runtimeGraph, 4);

    auto& secondInputBuffer =
        runtimeGraph->nodes.at(2).nodeProcessContext->getInputAudioBuffer(inputPortId(2));
    auto& thirdInputBuffer =
        runtimeGraph->nodes.at(3).nodeProcessContext->getInputAudioBuffer(inputPortId(3));

    for (int channel = 0; channel < secondInputBuffer.getNumChannels(); ++channel) {
      for (int sample = 0; sample < 4; ++sample) {
        expectWithinAbsoluteError(
            secondInputBuffer.getSample(channel, sample), static_cast<float>(sample + 1), 0.0001f);
        expectWithinAbsoluteError(
            thirdInputBuffer.getSample(channel, sample), static_cast<float>(sample + 10), 0.0001f);
      }
    }
  }

  void testCalculatesLinearPriorities() {
    beginTest("RuntimeGraph calculates priorities for a linear chain");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 2, 3);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    expectEquals(static_cast<int>(runtimeGraph->nodes.at(1).priority), 3);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(2).priority), 2);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(3).priority), 1);
  }

  void testCalculatesDiamondPriorities() {
    beginTest("RuntimeGraph calculates priorities for a diamond graph");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addGraphNode(*graph, 4);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 1, 3);
    addConnection(*graph, 102, 2, 4);
    addConnection(*graph, 103, 3, 4);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    expectEquals(static_cast<int>(runtimeGraph->nodes.at(1).priority), 5);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(2).priority), 2);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(3).priority), 2);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(4).priority), 1);
  }

  void testCalculatesDisconnectedComponentPriorities() {
    beginTest("RuntimeGraph calculates priorities across disconnected components");

    auto graph = graph_test_helpers::makeProcessingGraph();
    addGraphNode(*graph, 1);
    addGraphNode(*graph, 2);
    addGraphNode(*graph, 3);
    addGraphNode(*graph, 4);
    addGraphNode(*graph, 5);
    addConnection(*graph, 100, 1, 2);
    addConnection(*graph, 101, 3, 4);
    addConnection(*graph, 102, 4, 5);

    GraphRuntimeServices rtServices;
    auto runtimeGraph = buildRuntimeGraph(*graph, rtServices);

    expectEquals(static_cast<int>(runtimeGraph->nodes.at(1).priority), 2);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(2).priority), 1);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(3).priority), 3);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(4).priority), 2);
    expectEquals(static_cast<int>(runtimeGraph->nodes.at(5).priority), 1);
  }

  void testAvailableTaskQueueOrdersByPriorityThenId() {
    beginTest("RuntimeGraph available task queue orders by priority, then ID");

    threaded_graph::RuntimeNode lowPriorityNode(10, nullptr);
    threaded_graph::RuntimeNode highPriorityNode(20, nullptr);
    threaded_graph::RuntimeNode lowerIdNode(1, nullptr);
    threaded_graph::RuntimeNode higherIdNode(2, nullptr);

    lowPriorityNode.priority = 1;
    highPriorityNode.priority = 3;
    lowerIdNode.priority = 2;
    higherIdNode.priority = 2;

    threaded_graph::RuntimeGraph runtimeGraph(4);
    runtimeGraph.availableTasks.push(&lowPriorityNode);
    runtimeGraph.availableTasks.push(&higherIdNode);
    runtimeGraph.availableTasks.push(&highPriorityNode);
    runtimeGraph.availableTasks.push(&lowerIdNode);

    expect(runtimeGraph.availableTasks.top() == &highPriorityNode,
        "The highest-priority node should be dequeued first.");
    runtimeGraph.availableTasks.pop();

    expect(runtimeGraph.availableTasks.top() == &lowerIdNode,
        "Lower node IDs should break equal-priority ties.");
    runtimeGraph.availableTasks.pop();

    expect(runtimeGraph.availableTasks.top() == &higherIdNode,
        "The other equal-priority node should be dequeued next.");
    runtimeGraph.availableTasks.pop();

    expect(runtimeGraph.availableTasks.top() == &lowPriorityNode,
        "The lowest-priority node should be dequeued last.");
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
