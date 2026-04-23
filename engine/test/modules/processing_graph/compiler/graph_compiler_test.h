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

#include "modules/processing_graph/compiler/graph_action.h"
#include "modules/processing_graph/compiler/graph_compiler.h"
#include "modules/processing_graph/compiler/node_process_context.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"
#include "modules/processors/master_output.h"

#include <algorithm>
#include <juce_core/juce_core.h>
#include <stdexcept>

namespace anthem {

class GraphCompilerTest : public juce::UnitTest {
  static int countActionsOfType(const GraphCompilationResult& result, GraphActionType type) {
    return static_cast<int>(std::count_if(result.actions.begin(),
        result.actions.end(),
        [type](const GraphAction& action) { return action.type == type; }));
  }

  static GraphCompileRequest buildCompileRequest(
      GraphRuntimeServices& rtServices, ProcessingGraphModel& graph) {
    return GraphCompileRequest{
        .rtServices = rtServices,
        .nodes = *graph.nodes(),
        .connections = *graph.connections(),
        .bufferLayout =
            GraphBufferLayout{
                .numAudioChannels = 2,
                .blockSize = 64,
            },
        .sampleRate = 48000.0,
    };
  }
public:
  GraphCompilerTest() : juce::UnitTest("AnthemGraphCompilerTest", "Anthem") {}

  void runTest() override {
    testCompileEmptyGraphProducesNoActions();
    testCompileSingleNodeGraphProducesOneProcessAction();
    testCompileTwoNodeAudioGraphProducesExpectedActionFlow();
    testCompileFanOutGraphProducesMultipleCopyActions();
    testCompileFanInGraphProducesMultipleCopyActions();
    testCompileControlGraphProducesControlCopyAction();
    testCompileEventGraphProducesEventCopyAction();
    testCompileCycleThrows();
    testCompileMalformedConnectionSkipsInvalidEdge();
  }

  void testCompileEmptyGraphProducesNoActions() {
    beginTest("Empty graphs compile into no actions");

    GraphRuntimeServices rtServices;
    auto graph = graph_test_helpers::makeProcessingGraph();

    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expect(result != nullptr, "Compiling an empty graph should still produce a result.");
    expectEquals(
        static_cast<int>(result->actions.size()), 0, "Empty graphs should not emit any actions.");
    expectWithinAbsoluteError(
        result->sampleRate, 48000.0f, 0.0001f, "Compilation should retain the sample rate.");

    result->cleanup();
    delete result;
  }

  void testCompileSingleNodeGraphProducesOneProcessAction() {
    beginTest("A single-node graph produces one process action");

    constexpr int64_t gainNodeId = 10;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto gainNode = graph_test_helpers::makeGainNode(gainNodeId);

    gainNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioInputPortId, gainNodeId, NodePortDataType::audio));
    gainNode->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioOutputPortId, gainNodeId, NodePortDataType::audio));
    gainNode->controlInputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::gainPortId,
            gainNodeId,
            NodePortDataType::control,
            0.5,
            graph_test_helpers::makeParameterConfig(101, 0.5)));

    graph->nodes()->insert_or_assign(gainNodeId, gainNode);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::ClearBuffers),
        1,
        "Single-node graphs should emit one clear action.");
    expectEquals(countActionsOfType(*result, GraphActionType::WriteParametersToControlInputs),
        1,
        "Single-node graphs should emit one parameter-write action.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        1,
        "Single-node graphs should process the node once.");
    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        0,
        "Single-node graphs should not emit audio-copy actions.");
    expectEquals(static_cast<int>(result->actions.size()),
        3,
        "Single-node graphs should emit clear, parameter-write, and process actions.");

    expect(result->actions[0].type == GraphActionType::ClearBuffers,
        "The first action should clear buffers.");
    expect(result->actions[1].type == GraphActionType::WriteParametersToControlInputs,
        "The second action should initialize control inputs.");
    expect(result->actions[2].type == GraphActionType::ProcessNode,
        "The third action should process the node.");
    expect(result->actions[2].processNode.processor == gainNode->getProcessor().value().get(),
        "The process action should target the node's processor.");

    result->cleanup();
    delete result;
  }

  void testCompileTwoNodeAudioGraphProducesExpectedActionFlow() {
    beginTest("A simple audio graph compiles into the expected action flow");

    constexpr int64_t gainNodeId = 10;
    constexpr int64_t masterNodeId = 20;
    constexpr int64_t connectionId = 100;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto gainNode = graph_test_helpers::makeGainNode(gainNodeId);
    auto masterNode = graph_test_helpers::makeMasterOutputNode(masterNodeId);

    gainNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioInputPortId, gainNodeId, NodePortDataType::audio));
    gainNode->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioOutputPortId, gainNodeId, NodePortDataType::audio));
    gainNode->controlInputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::gainPortId,
            gainNodeId,
            NodePortDataType::control,
            0.5,
            graph_test_helpers::makeParameterConfig(101, 0.5)));

    masterNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, masterNodeId, NodePortDataType::audio));

    auto connection = graph_test_helpers::makeConnection(connectionId,
        gainNodeId,
        GainProcessorModelBase::audioOutputPortId,
        masterNodeId,
        MasterOutputProcessorModelBase::inputPortId);

    gainNode->audioOutputPorts()->at(0)->connections()->push_back(connectionId);
    masterNode->audioInputPorts()->at(0)->connections()->push_back(connectionId);

    graph->nodes()->insert_or_assign(gainNodeId, gainNode);
    graph->nodes()->insert_or_assign(masterNodeId, masterNode);
    graph->connections()->insert_or_assign(connectionId, connection);
    graph->masterOutputNodeId() = masterNodeId;

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expect(result != nullptr, "Compiling a simple graph should produce a result.");
    expectEquals(static_cast<int>(result->graphNodes.size()),
        2,
        "The result should retain both graph nodes.");
    expect(gainNode->runtimeContext.has_value(),
        "Compilation should assign a runtime context to the gain node.");
    expect(masterNode->runtimeContext.has_value(),
        "Compilation should assign a runtime context to the master-output node.");
    expectEquals(countActionsOfType(*result, GraphActionType::ClearBuffers),
        2,
        "Both nodes should get clear actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::WriteParametersToControlInputs),
        2,
        "Both nodes should get parameter-write actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        2,
        "Both nodes should get process actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        1,
        "The edge should get one audio-copy action.");
    expectEquals(static_cast<int>(result->actions.size()),
        7,
        "A two-node single-edge graph should emit all expected actions.");

    for (int index = 0; index < 2; ++index) {
      expect(result->actions[index].type == GraphActionType::ClearBuffers,
          "Initialization should begin with clear-buffer actions.");
    }

    for (int index = 2; index < 4; ++index) {
      expect(result->actions[index].type == GraphActionType::WriteParametersToControlInputs,
          "Clear actions should be followed by parameter-write actions.");
    }

    expect(result->actions[4].type == GraphActionType::ProcessNode,
        "The root node should process before copies.");
    expect(result->actions[5].type == GraphActionType::CopyAudioBuffer,
        "The connection copy should happen after the root process.");
    expect(result->actions[6].type == GraphActionType::ProcessNode,
        "The sink node should process after its incoming copy.");

    expect(result->actions[4].processNode.processor == gainNode->getProcessor().value().get(),
        "The first process action should target the gain processor.");
    expect(result->actions[6].processNode.processor == masterNode->getProcessor().value().get(),
        "The final process action should target the master-output processor.");

    auto* gainContext = gainNode->runtimeContext.value();
    auto* masterContext = masterNode->runtimeContext.value();
    expectEquals(result->actions[5].copyAudioBuffer.sourceBufferIndex,
        gainContext->getBufferIndex(NodePortDataType::audio,
            NodeProcessContext::BufferDirection::output,
            GainProcessorModelBase::audioOutputPortId),
        "The audio-copy action should use the gain output buffer index.");
    expectEquals(result->actions[5].copyAudioBuffer.destinationBufferIndex,
        masterContext->getBufferIndex(NodePortDataType::audio,
            NodeProcessContext::BufferDirection::input,
            MasterOutputProcessorModelBase::inputPortId),
        "The audio-copy action should target the master input buffer index.");

    result->cleanup();
    delete result;
  }

  void testCompileFanOutGraphProducesMultipleCopyActions() {
    beginTest("Fan-out graphs produce multiple audio-copy actions before downstream processing");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t firstSinkNodeId = 20;
    constexpr int64_t secondSinkNodeId = 30;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto sourceNode = graph_test_helpers::makeGainNode(sourceNodeId);
    auto firstSinkNode = graph_test_helpers::makeMasterOutputNode(firstSinkNodeId);
    auto secondSinkNode = graph_test_helpers::makeMasterOutputNode(secondSinkNodeId);

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

    firstSinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, firstSinkNodeId, NodePortDataType::audio));
    secondSinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, secondSinkNodeId, NodePortDataType::audio));

    auto firstConnection = graph_test_helpers::makeConnection(100,
        sourceNodeId,
        GainProcessorModelBase::audioOutputPortId,
        firstSinkNodeId,
        MasterOutputProcessorModelBase::inputPortId);
    auto secondConnection = graph_test_helpers::makeConnection(101,
        sourceNodeId,
        GainProcessorModelBase::audioOutputPortId,
        secondSinkNodeId,
        MasterOutputProcessorModelBase::inputPortId);

    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(101);
    firstSinkNode->audioInputPorts()->at(0)->connections()->push_back(100);
    secondSinkNode->audioInputPorts()->at(0)->connections()->push_back(101);

    graph->nodes()->insert_or_assign(sourceNodeId, sourceNode);
    graph->nodes()->insert_or_assign(firstSinkNodeId, firstSinkNode);
    graph->nodes()->insert_or_assign(secondSinkNodeId, secondSinkNode);
    graph->connections()->insert_or_assign(100, firstConnection);
    graph->connections()->insert_or_assign(101, secondConnection);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        2,
        "Fan-out should create one audio-copy action per outgoing edge.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        3,
        "Source and both sinks should each be processed once.");
    expectEquals(static_cast<int>(result->actions.size()),
        11,
        "Fan-out should emit initialization, one root process, two copies, and two sink "
        "processes.");
    expect(result->actions[6].type == GraphActionType::ProcessNode,
        "The source should process before any fan-out copies.");
    expect(result->actions[7].type == GraphActionType::CopyAudioBuffer,
        "Fan-out copies should come immediately after the source process.");
    expect(result->actions[8].type == GraphActionType::CopyAudioBuffer,
        "All outgoing fan-out copies should be grouped together.");
    expect(result->actions[9].type == GraphActionType::ProcessNode,
        "Downstream sinks should process after the copies.");
    expect(result->actions[10].type == GraphActionType::ProcessNode,
        "Both downstream sinks should become ready in the same phase.");

    result->cleanup();
    delete result;
  }

  void testCompileFanInGraphProducesMultipleCopyActions() {
    beginTest("Fan-in graphs produce multiple audio-copy actions into one destination");

    constexpr int64_t firstSourceNodeId = 10;
    constexpr int64_t secondSourceNodeId = 20;
    constexpr int64_t sinkNodeId = 30;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto firstSourceNode = graph_test_helpers::makeGainNode(firstSourceNodeId);
    auto secondSourceNode = graph_test_helpers::makeGainNode(secondSourceNodeId);
    auto sinkNode = graph_test_helpers::makeMasterOutputNode(sinkNodeId);

    for (auto* nodeInfo : {firstSourceNode.get(), secondSourceNode.get()}) {
      nodeInfo->audioInputPorts()->push_back(graph_test_helpers::makePort(
          GainProcessorModelBase::audioInputPortId, nodeInfo->id(), NodePortDataType::audio));
      nodeInfo->audioOutputPorts()->push_back(graph_test_helpers::makePort(
          GainProcessorModelBase::audioOutputPortId, nodeInfo->id(), NodePortDataType::audio));
      nodeInfo->controlInputPorts()->push_back(
          graph_test_helpers::makePort(GainProcessorModelBase::gainPortId,
              nodeInfo->id(),
              NodePortDataType::control,
              0.5,
              graph_test_helpers::makeParameterConfig(100 + nodeInfo->id(), 0.5)));
    }

    sinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, sinkNodeId, NodePortDataType::audio));

    auto firstConnection = graph_test_helpers::makeConnection(100,
        firstSourceNodeId,
        GainProcessorModelBase::audioOutputPortId,
        sinkNodeId,
        MasterOutputProcessorModelBase::inputPortId);
    auto secondConnection = graph_test_helpers::makeConnection(101,
        secondSourceNodeId,
        GainProcessorModelBase::audioOutputPortId,
        sinkNodeId,
        MasterOutputProcessorModelBase::inputPortId);

    firstSourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    secondSourceNode->audioOutputPorts()->at(0)->connections()->push_back(101);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(100);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(101);

    graph->nodes()->insert_or_assign(firstSourceNodeId, firstSourceNode);
    graph->nodes()->insert_or_assign(secondSourceNodeId, secondSourceNode);
    graph->nodes()->insert_or_assign(sinkNodeId, sinkNode);
    graph->connections()->insert_or_assign(100, firstConnection);
    graph->connections()->insert_or_assign(101, secondConnection);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        2,
        "Fan-in should create one audio-copy action per incoming edge.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        3,
        "Both sources and the sink should each be processed once.");
    expectEquals(static_cast<int>(result->actions.size()),
        11,
        "Fan-in should emit initialization, two root processes, two copies, and one sink process.");
    expect(result->actions[6].type == GraphActionType::ProcessNode,
        "Both root sources should process before copies.");
    expect(result->actions[7].type == GraphActionType::ProcessNode,
        "Both root sources should process in the same phase.");
    expect(result->actions[8].type == GraphActionType::CopyAudioBuffer,
        "Incoming copies should be emitted after the root processes.");
    expect(result->actions[9].type == GraphActionType::CopyAudioBuffer,
        "All incoming copies should be grouped together.");
    expect(result->actions[10].type == GraphActionType::ProcessNode,
        "The sink should process only after both incoming edges are copied.");

    result->cleanup();
    delete result;
  }

  void testCompileControlGraphProducesControlCopyAction() {
    beginTest("Control graphs produce control-copy actions");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;
    constexpr int64_t sourcePortId = 500;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto sourceNode = graph_test_helpers::makeNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeGainNode(sinkNodeId);

    sourceNode->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(sourcePortId, sourceNodeId, NodePortDataType::control));
    sinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioInputPortId, sinkNodeId, NodePortDataType::audio));
    sinkNode->audioOutputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::audioOutputPortId, sinkNodeId, NodePortDataType::audio));
    sinkNode->controlInputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::gainPortId,
            sinkNodeId,
            NodePortDataType::control,
            0.5,
            graph_test_helpers::makeParameterConfig(101, 0.5)));

    auto connection = graph_test_helpers::makeConnection(
        100, sourceNodeId, sourcePortId, sinkNodeId, GainProcessorModelBase::gainPortId);

    sourceNode->controlOutputPorts()->at(0)->connections()->push_back(100);
    sinkNode->controlInputPorts()->at(0)->connections()->push_back(100);

    graph->nodes()->insert_or_assign(sourceNodeId, sourceNode);
    graph->nodes()->insert_or_assign(sinkNodeId, sinkNode);
    graph->connections()->insert_or_assign(100, connection);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::CopyControlBuffer),
        1,
        "Control graphs should emit control-copy actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        0,
        "Control-only graphs should not emit audio-copy actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        1,
        "Only the sink node should emit a process action in this test graph.");
    expectEquals(static_cast<int>(result->actions.size()),
        6,
        "Control graphs should emit initialization, one control copy, and one sink process.");
    expect(result->actions[4].type == GraphActionType::CopyControlBuffer,
        "The control copy should happen before the sink processes.");
    expect(result->actions[5].type == GraphActionType::ProcessNode,
        "The sink should process after receiving its control input.");

    result->cleanup();
    delete result;
  }

  void testCompileEventGraphProducesEventCopyAction() {
    beginTest("Event graphs produce event-copy actions");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;
    constexpr int64_t sourcePortId = 500;
    constexpr int64_t sinkPortId = 600;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto sourceNode = graph_test_helpers::makeNode(sourceNodeId);
    auto sinkNode = graph_test_helpers::makeNode(sinkNodeId);

    sourceNode->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(sourcePortId, sourceNodeId, NodePortDataType::event));
    sinkNode->eventInputPorts()->push_back(
        graph_test_helpers::makePort(sinkPortId, sinkNodeId, NodePortDataType::event));

    auto connection =
        graph_test_helpers::makeConnection(100, sourceNodeId, sourcePortId, sinkNodeId, sinkPortId);

    sourceNode->eventOutputPorts()->at(0)->connections()->push_back(100);
    sinkNode->eventInputPorts()->at(0)->connections()->push_back(100);

    graph->nodes()->insert_or_assign(sourceNodeId, sourceNode);
    graph->nodes()->insert_or_assign(sinkNodeId, sinkNode);
    graph->connections()->insert_or_assign(100, connection);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::CopyEvents),
        1,
        "Event graphs should emit event-copy actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        0,
        "Processor-less event test nodes should not emit process actions.");
    expectEquals(static_cast<int>(result->actions.size()),
        5,
        "Event graphs should emit initialization and one event copy.");
    expect(result->actions[4].type == GraphActionType::CopyEvents,
        "The event copy should occur after initialization.");

    result->cleanup();
    delete result;
  }

  void testCompileCycleThrows() {
    beginTest("Cycles throw instead of looping forever");

    constexpr int64_t firstNodeId = 10;
    constexpr int64_t secondNodeId = 20;

    auto graph = graph_test_helpers::makeProcessingGraph();
    auto firstNode = graph_test_helpers::makeNode(firstNodeId);
    auto secondNode = graph_test_helpers::makeNode(secondNodeId);

    firstNode->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, firstNodeId, NodePortDataType::audio));
    firstNode->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, firstNodeId, NodePortDataType::audio));
    secondNode->audioInputPorts()->push_back(
        graph_test_helpers::makePort(3, secondNodeId, NodePortDataType::audio));
    secondNode->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(4, secondNodeId, NodePortDataType::audio));

    auto firstConnection = graph_test_helpers::makeConnection(100, firstNodeId, 2, secondNodeId, 3);
    auto secondConnection =
        graph_test_helpers::makeConnection(101, secondNodeId, 4, firstNodeId, 1);

    firstNode->audioInputPorts()->at(0)->connections()->push_back(101);
    firstNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    secondNode->audioInputPorts()->at(0)->connections()->push_back(100);
    secondNode->audioOutputPorts()->at(0)->connections()->push_back(101);

    graph->nodes()->insert_or_assign(firstNodeId, firstNode);
    graph->nodes()->insert_or_assign(secondNodeId, secondNode);
    graph->connections()->insert_or_assign(100, firstConnection);
    graph->connections()->insert_or_assign(101, secondConnection);

    GraphRuntimeServices rtServices;

    bool didThrow = false;
    try {
      auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));
      if (result != nullptr) {
        result->cleanup();
        delete result;
      }
    } catch (const std::runtime_error&) {
      didThrow = true;
    }

    expect(didThrow, "Cyclic graphs should throw a runtime_error.");
  }

  void testCompileMalformedConnectionSkipsInvalidEdge() {
    beginTest("Malformed connections are skipped instead of producing copy actions");

    constexpr int64_t sourceNodeId = 10;
    constexpr int64_t sinkNodeId = 20;

    auto graph = graph_test_helpers::makeProcessingGraph();
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

    auto malformedConnection = graph_test_helpers::makeConnection(
        100, sourceNodeId, GainProcessorModelBase::audioOutputPortId, sinkNodeId, 9999);

    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    sinkNode->audioInputPorts()->at(0)->connections()->push_back(100);

    graph->nodes()->insert_or_assign(sourceNodeId, sourceNode);
    graph->nodes()->insert_or_assign(sinkNodeId, sinkNode);
    graph->connections()->insert_or_assign(100, malformedConnection);

    GraphRuntimeServices rtServices;
    auto* result = GraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType(*result, GraphActionType::CopyAudioBuffer),
        0,
        "Malformed connections should not produce copy actions.");
    expectEquals(countActionsOfType(*result, GraphActionType::ProcessNode),
        2,
        "Without a valid edge, both nodes should behave like independent roots.");

    result->cleanup();
    delete result;
  }
};

static GraphCompilerTest anthemGraphCompilerTest;

} // namespace anthem
