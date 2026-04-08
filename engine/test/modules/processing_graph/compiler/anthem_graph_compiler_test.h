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

#include "modules/processing_graph/compiler/actions/clear_buffers_action.h"
#include "modules/processing_graph/compiler/actions/copy_audio_buffer_action.h"
#include "modules/processing_graph/compiler/actions/copy_control_buffer_action.h"
#include "modules/processing_graph/compiler/actions/copy_events_action.h"
#include "modules/processing_graph/compiler/actions/process_node_action.h"
#include "modules/processing_graph/compiler/actions/write_parameters_to_control_inputs_action.h"
#include "modules/processing_graph/compiler/anthem_graph_compiler.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"
#include "modules/processors/master_output.h"

#include <juce_core/juce_core.h>
#include <stdexcept>

class AnthemGraphCompilerTest : public juce::UnitTest {
  template <typename T> static int countActionsOfType(const AnthemGraphCompilationResult& result) {
    int count = 0;

    for (const auto& group : result.actionGroups) {
      for (const auto& action : *group) {
        if (dynamic_cast<T*>(action.get()) != nullptr) {
          count++;
        }
      }
    }

    return count;
  }

  static AnthemGraphCompileRequest buildCompileRequest(GraphRuntimeServices& rtServices,
                                                       ProcessingGraphModel& graph) {
    return AnthemGraphCompileRequest{
        .rtServices = rtServices,
        .nodes = *graph.nodes(),
        .connections = *graph.connections(),
        .bufferLayout =
            AnthemGraphBufferLayout{
                .numAudioChannels = 2,
                .blockSize = 64,
            },
        .sampleRate = 48000.0,
    };
  }
public:
  AnthemGraphCompilerTest() : juce::UnitTest("AnthemGraphCompilerTest", "Anthem") {}

  void runTest() override {
    testCompileEmptyGraphProducesOnlyInitializationGroups();
    testCompileSingleNodeGraphProducesOneProcessAction();
    testCompileTwoNodeAudioGraphProducesExpectedActionFlow();
    testCompileFanOutGraphProducesMultipleCopyActions();
    testCompileFanInGraphProducesMultipleCopyActions();
    testCompileControlGraphProducesControlCopyAction();
    testCompileEventGraphProducesEventCopyAction();
    testCompileCycleThrows();
    testCompileMalformedConnectionSkipsInvalidEdge();
  }

  void testCompileEmptyGraphProducesOnlyInitializationGroups() {
    beginTest("Empty graphs compile into empty initialization groups");

    GraphRuntimeServices rtServices;
    auto graph = graph_test_helpers::makeProcessingGraph();

    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expect(result != nullptr, "Compiling an empty graph should still produce a result.");
    expectEquals(static_cast<int>(result->actionGroups.size()),
                 2,
                 "Empty graphs should only produce the two initialization action groups.");
    expectEquals(static_cast<int>(result->actionGroups[0]->size()),
                 0,
                 "Clear-buffers group should be empty for an empty graph.");
    expectEquals(static_cast<int>(result->actionGroups[1]->size()),
                 0,
                 "Parameter-write group should be empty for an empty graph.");

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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<ProcessNodeAction>(*result),
                 1,
                 "Single-node graphs should process the node once.");
    expectEquals(countActionsOfType<CopyAudioBufferAction>(*result),
                 0,
                 "Single-node graphs should not emit copy actions.");
    expectEquals(static_cast<int>(result->actionGroups.size()),
                 4,
                 "Single-node graphs should produce init, process, and empty copy groups.");

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

    auto connection =
        graph_test_helpers::makeConnection(connectionId,
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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expect(result != nullptr, "Compiling a simple graph should produce a result.");
    expectEquals(static_cast<int>(result->graphNodes.size()),
                 2,
                 "The result should retain both graph nodes.");
    expect(gainNode->runtimeContext.has_value(),
           "Compilation should assign a runtime context to the gain node.");
    expect(masterNode->runtimeContext.has_value(),
           "Compilation should assign a runtime context to the master-output node.");

    expectEquals(static_cast<int>(result->actionGroups.size()),
                 6,
                 "A two-node single-edge graph should produce the expected initialization, "
                 "process, and copy groups.");
    expectEquals(static_cast<int>(result->actionGroups[0]->size()),
                 2,
                 "Both nodes should get a clear-buffers action.");
    expect(dynamic_cast<ClearBuffersAction*>(result->actionGroups[0]->at(0).get()) != nullptr,
           "Initialization group 0 should contain clear-buffers actions.");
    expect(dynamic_cast<ClearBuffersAction*>(result->actionGroups[0]->at(1).get()) != nullptr,
           "Initialization group 0 should contain clear-buffers actions.");

    expectEquals(
        static_cast<int>(result->actionGroups[1]->size()),
        2,
        "Both nodes should get a parameter-write action, even if one has no control inputs.");
    expect(dynamic_cast<WriteParametersToControlInputsAction*>(
               result->actionGroups[1]->at(0).get()) != nullptr,
           "Initialization group 1 should contain parameter-write actions.");
    expect(dynamic_cast<WriteParametersToControlInputsAction*>(
               result->actionGroups[1]->at(1).get()) != nullptr,
           "Initialization group 1 should contain parameter-write actions.");

    auto* processGainAction =
        dynamic_cast<ProcessNodeAction*>(result->actionGroups[2]->at(0).get());
    expect(processGainAction != nullptr,
           "The first non-initialization group should process the root gain node.");
    expect(processGainAction->processor == gainNode->getProcessor().value().get(),
           "The root process action should target the gain processor.");

    auto* copyAudioAction =
        dynamic_cast<CopyAudioBufferAction*>(result->actionGroups[3]->at(0).get());
    expect(copyAudioAction != nullptr, "The connection group should contain an audio-copy action.");
    expectEquals(copyAudioAction->sourcePortId,
                 GainProcessorModelBase::audioOutputPortId,
                 "Audio copy should read from the gain output port.");
    expectEquals(copyAudioAction->destinationPortId,
                 MasterOutputProcessorModelBase::inputPortId,
                 "Audio copy should write to the master input port.");

    auto* processMasterAction =
        dynamic_cast<ProcessNodeAction*>(result->actionGroups[4]->at(0).get());
    expect(processMasterAction != nullptr,
           "The final non-empty process group should process the master-output node.");
    expect(processMasterAction->processor == masterNode->getProcessor().value().get(),
           "The final process action should target the master-output processor.");

    expectEquals(static_cast<int>(result->actionGroups[5]->size()),
                 0,
                 "The final connection group should be empty once all edges are consumed.");

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

    auto firstConnection =
        graph_test_helpers::makeConnection(100,
                                           sourceNodeId,
                                           GainProcessorModelBase::audioOutputPortId,
                                           firstSinkNodeId,
                                           MasterOutputProcessorModelBase::inputPortId);
    auto secondConnection =
        graph_test_helpers::makeConnection(101,
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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<CopyAudioBufferAction>(*result),
                 2,
                 "Fan-out should create one audio-copy action per outgoing edge.");
    expectEquals(countActionsOfType<ProcessNodeAction>(*result),
                 3,
                 "Source and both sinks should each be processed once.");
    expectEquals(static_cast<int>(result->actionGroups[3]->size()),
                 2,
                 "The copy group should contain both fan-out edges together.");
    expectEquals(static_cast<int>(result->actionGroups[4]->size()),
                 2,
                 "Both downstream sinks should become ready in the same process group.");

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
      nodeInfo->controlInputPorts()->push_back(graph_test_helpers::makePort(
          GainProcessorModelBase::gainPortId,
          nodeInfo->id(),
          NodePortDataType::control,
          0.5,
          graph_test_helpers::makeParameterConfig(100 + nodeInfo->id(), 0.5)));
    }

    sinkNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessorModelBase::inputPortId, sinkNodeId, NodePortDataType::audio));

    auto firstConnection =
        graph_test_helpers::makeConnection(100,
                                           firstSourceNodeId,
                                           GainProcessorModelBase::audioOutputPortId,
                                           sinkNodeId,
                                           MasterOutputProcessorModelBase::inputPortId);
    auto secondConnection =
        graph_test_helpers::makeConnection(101,
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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<CopyAudioBufferAction>(*result),
                 2,
                 "Fan-in should create one audio-copy action per incoming edge.");
    expectEquals(countActionsOfType<ProcessNodeAction>(*result),
                 3,
                 "Both sources and the sink should each be processed once.");
    expectEquals(static_cast<int>(result->actionGroups[2]->size()),
                 2,
                 "Both root sources should be processed in the same group.");
    expectEquals(static_cast<int>(result->actionGroups[3]->size()),
                 2,
                 "Both incoming edges should be copied in the same connection group.");
    expectEquals(static_cast<int>(result->actionGroups[4]->size()),
                 1,
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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<CopyControlBufferAction>(*result),
                 1,
                 "Control graphs should emit control-copy actions.");
    expectEquals(countActionsOfType<CopyAudioBufferAction>(*result),
                 0,
                 "Control-only graphs should not emit audio-copy actions.");

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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<CopyEventsAction>(*result),
                 1,
                 "Event graphs should emit event-copy actions.");
    expectEquals(countActionsOfType<ProcessNodeAction>(*result),
                 0,
                 "Processor-less event test nodes should not emit process actions.");

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
      auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));
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
    auto* result = AnthemGraphCompiler::compile(buildCompileRequest(rtServices, *graph));

    expectEquals(countActionsOfType<CopyAudioBufferAction>(*result),
                 0,
                 "Malformed connections should not produce copy actions.");
    expectEquals(countActionsOfType<ProcessNodeAction>(*result),
                 2,
                 "Without a valid edge, both nodes should behave like independent roots.");

    result->cleanup();
    delete result;
  }
};

static AnthemGraphCompilerTest anthemGraphCompilerTest;
