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

#include "modules/core/constants.h"
#include "modules/processing_graph/compiler/anthem_graph_process_context.h"
#include "modules/processing_graph/graph_test_helpers.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"

#include <juce_core/juce_core.h>

namespace anthem {

class GraphProcessContextTest : public juce::UnitTest {
  static std::shared_ptr<Node> makeFullyBoundNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(3,
        nodeId,
        NodePortDataType::control,
        0.25,
        graph_test_helpers::makeParameterConfig(101, 0.25)));
    node->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(4, nodeId, NodePortDataType::control));
    node->eventInputPorts()->push_back(
        graph_test_helpers::makePort(5, nodeId, NodePortDataType::event));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(6, nodeId, NodePortDataType::event));

    return node;
  }

  static std::shared_ptr<Node> makeEventHeavyNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->eventInputPorts()->push_back(
        graph_test_helpers::makePort(11, nodeId, NodePortDataType::event));
    node->eventInputPorts()->push_back(
        graph_test_helpers::makePort(12, nodeId, NodePortDataType::event));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(13, nodeId, NodePortDataType::event));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(14, nodeId, NodePortDataType::event));

    return node;
  }
public:
  GraphProcessContextTest() : juce::UnitTest("AnthemGraphProcessContextTest", "Anthem") {}

  void runTest() override {
    testBuffersUseExplicitLayout();
    testBufferIndicesRemainStableAndMonotonic();
    testReserveDoesNotAllocateBuffersEagerly();
    testNodeContextBindsPortsAndParameters();
    testMultipleNodeContextsShareGraphOwnedServices();
    testEachEventPortGetsItsOwnDefaultCapacityBuffer();
  }

  void testBuffersUseExplicitLayout() {
    beginTest("Graph-owned buffers use the explicit compile-time layout");

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 64,
        });

    auto audioIndex = context.allocateAudioBuffer();
    auto controlIndex = context.allocateControlBuffer();
    auto eventIndex = context.allocateEventBuffer(4);

    auto& audioBuffer = context.getAudioBuffer(audioIndex);
    auto& controlBuffer = context.getControlBuffer(controlIndex);
    auto& eventBuffer = context.getEventBuffer(eventIndex);

    expectEquals(
        audioBuffer.getNumChannels(), 2, "Audio buffer should use the configured channel count.");
    expectEquals(
        audioBuffer.getNumSamples(), 64, "Audio buffer should use the configured block size.");
    expectEquals(controlBuffer.getNumChannels(), 1, "Control buffers should stay mono.");
    expectEquals(
        controlBuffer.getNumSamples(), 64, "Control buffers should use the configured block size.");
    expectEquals(static_cast<int>(eventBuffer->getSize()),
        4,
        "Event buffer should use the requested initial capacity.");
  }

  void testBufferIndicesRemainStableAndMonotonic() {
    beginTest("Graph-owned buffer indices remain stable as buffers are appended");

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 16,
        });

    auto firstAudioIndex = context.allocateAudioBuffer();
    auto secondAudioIndex = context.allocateAudioBuffer();
    auto firstControlIndex = context.allocateControlBuffer();
    auto secondControlIndex = context.allocateControlBuffer();
    auto firstEventIndex = context.allocateEventBuffer(2);
    auto secondEventIndex = context.allocateEventBuffer(3);

    context.getAudioBuffer(firstAudioIndex).setSample(0, 0, 0.5f);
    context.getControlBuffer(firstControlIndex).setSample(0, 0, 0.25f);
    context.getEventBuffer(firstEventIndex)
        ->addEvent(LiveEvent{
            .sampleOffset = 0.0,
            .liveId = 7,
            .event = Event(NoteOnEvent(60, 0, 1.0f, 0.0f)),
        });

    auto thirdAudioIndex = context.allocateAudioBuffer();
    auto thirdControlIndex = context.allocateControlBuffer();
    auto thirdEventIndex = context.allocateEventBuffer(4);

    expectEquals(
        static_cast<int>(firstAudioIndex), 0, "First audio buffer index should start at zero.");
    expectEquals(static_cast<int>(secondAudioIndex),
        1,
        "Audio buffer indices should increment monotonically.");
    expectEquals(static_cast<int>(thirdAudioIndex),
        2,
        "Appended audio buffers should keep stable earlier indices.");
    expectEquals(
        static_cast<int>(firstControlIndex), 0, "First control buffer index should start at zero.");
    expectEquals(static_cast<int>(secondControlIndex),
        1,
        "Control buffer indices should increment monotonically.");
    expectEquals(static_cast<int>(thirdControlIndex),
        2,
        "Appended control buffers should keep stable earlier indices.");
    expectEquals(
        static_cast<int>(firstEventIndex), 0, "First event buffer index should start at zero.");
    expectEquals(static_cast<int>(secondEventIndex),
        1,
        "Event buffer indices should increment monotonically.");
    expectEquals(static_cast<int>(thirdEventIndex),
        2,
        "Appended event buffers should keep stable earlier indices.");

    expectWithinAbsoluteError(context.getAudioBuffer(firstAudioIndex).getSample(0, 0),
        0.5f,
        0.0001f,
        "Earlier audio buffers should remain reachable by their original index.");
    expectWithinAbsoluteError(context.getControlBuffer(firstControlIndex).getSample(0, 0),
        0.25f,
        0.0001f,
        "Earlier control buffers should remain reachable by their original index.");
    expectEquals(static_cast<int>(context.getEventBuffer(firstEventIndex)->getNumEvents()),
        1,
        "Earlier event buffers should remain reachable by their original index.");
  }

  void testReserveDoesNotAllocateBuffersEagerly() {
    beginTest("reserve only reserves capacity and does not allocate graph buffers eagerly");

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 32,
        });

    context.reserve(2, 4, 3, 5);

    auto audioIndex = context.allocateAudioBuffer();
    auto controlIndex = context.allocateControlBuffer();
    auto eventIndex = context.allocateEventBuffer(6);

    expectEquals(
        static_cast<int>(audioIndex), 0, "reserve should not consume audio buffer indices.");
    expectEquals(
        static_cast<int>(controlIndex), 0, "reserve should not consume control buffer indices.");
    expectEquals(
        static_cast<int>(eventIndex), 0, "reserve should not consume event buffer indices.");
    expectEquals(context.getAudioBuffer(audioIndex).getNumSamples(),
        32,
        "Buffers allocated after reserve should still use the configured block size.");
    expectEquals(static_cast<int>(context.getEventBuffer(eventIndex)->getSize()),
        6,
        "Event buffers allocated after reserve should use the requested initial capacity.");
  }

  void testNodeContextBindsPortsAndParameters() {
    beginTest("Node contexts bind ports, parameters, and live note allocation");

    constexpr int64_t nodeId = 10;
    constexpr int64_t inputPortId = GainProcessorModelBase::audioInputPortId;
    constexpr int64_t outputPortId = GainProcessorModelBase::audioOutputPortId;
    constexpr int64_t gainPortId = GainProcessorModelBase::gainPortId;

    auto node = graph_test_helpers::makeGainNode(nodeId);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(inputPortId, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(outputPortId, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(gainPortId,
        nodeId,
        NodePortDataType::control,
        0.25,
        graph_test_helpers::makeParameterConfig(101, 0.25)));

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 32,
        });
    context.reserve(1, 2, 1, 0);

    auto& nodeContext = context.createNodeProcessContext(node);

    expectEquals(nodeContext.getInputAudioBuffer(inputPortId).getNumChannels(),
        2,
        "Input audio buffer should be allocated with the graph channel count.");
    expectEquals(nodeContext.getOutputAudioBuffer(outputPortId).getNumSamples(),
        32,
        "Output audio buffer should be allocated with the graph block size.");
    expectEquals(nodeContext.getInputControlBuffer(gainPortId).getNumChannels(),
        1,
        "Control input buffers should be mono.");
    expectEquals(static_cast<int>(nodeContext.rt_getInputParameterBindings().size()),
        1,
        "A single control input should create one parameter binding.");
    expectWithinAbsoluteError(nodeContext.getParameterValue(gainPortId),
        0.25f,
        0.0001f,
        "Parameter binding should start from the port value.");
    expectEquals(nodeContext.rt_allocateLiveNoteId(),
        0,
        "The first live note ID should come from the shared runtime services.");
    expectEquals(nodeContext.rt_allocateLiveNoteId(),
        1,
        "Live note IDs should increment through the shared runtime services.");

    context.cleanup();
  }

  void testMultipleNodeContextsShareGraphOwnedServices() {
    beginTest("Multiple node contexts share the same graph-owned runtime services but not per-port "
              "buffers");

    auto firstNode = makeFullyBoundNode(10);
    auto secondNode = makeFullyBoundNode(20);

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 24,
        });
    context.reserve(2, 4, 4, 4);

    auto& firstNodeContext = context.createNodeProcessContext(firstNode);
    auto& secondNodeContext = context.createNodeProcessContext(secondNode);

    auto& firstInputAudio = firstNodeContext.getInputAudioBuffer(1);
    auto& secondInputAudio = secondNodeContext.getInputAudioBuffer(1);
    firstInputAudio.setSample(0, 0, 0.5f);
    secondInputAudio.setSample(0, 0, 0.25f);

    expect(&firstInputAudio != &secondInputAudio,
        "Each node context should get distinct graph-owned buffers for matching port shapes.");
    expectWithinAbsoluteError(secondInputAudio.getSample(0, 0),
        0.25f,
        0.0001f,
        "Writing one node context should not mutate another node context's buffers.");
    expectEquals(firstNodeContext.rt_allocateLiveNoteId(),
        0,
        "The first node context should allocate the first shared live note ID.");
    expectEquals(secondNodeContext.rt_allocateLiveNoteId(),
        1,
        "The second node context should share the same live note ID stream.");

    context.cleanup();
  }

  void testEachEventPortGetsItsOwnDefaultCapacityBuffer() {
    beginTest("Each event port gets its own default-capacity event buffer");

    auto node = makeEventHeavyNode(10);

    GraphRuntimeServices rtServices;
    GraphProcessContext context(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = 16,
        });
    context.reserve(1, 0, 0, 4);

    auto& nodeContext = context.createNodeProcessContext(node);

    auto& inputOne = nodeContext.getInputEventBuffer(11);
    auto& inputTwo = nodeContext.getInputEventBuffer(12);
    auto& outputOne = nodeContext.getOutputEventBuffer(13);
    auto& outputTwo = nodeContext.getOutputEventBuffer(14);

    expectEquals(static_cast<int>(inputOne->getSize()),
        DEFAULT_EVENT_BUFFER_SIZE,
        "Each input event port should allocate the default event-buffer capacity.");
    expectEquals(static_cast<int>(inputTwo->getSize()),
        DEFAULT_EVENT_BUFFER_SIZE,
        "Each input event port should allocate its own event buffer.");
    expectEquals(static_cast<int>(outputOne->getSize()),
        DEFAULT_EVENT_BUFFER_SIZE,
        "Each output event port should allocate the default event-buffer capacity.");
    expectEquals(static_cast<int>(outputTwo->getSize()),
        DEFAULT_EVENT_BUFFER_SIZE,
        "Each output event port should allocate its own event buffer.");
    expect(
        inputOne.get() != inputTwo.get(), "Distinct input event ports should not share storage.");
    expect(inputOne.get() != outputOne.get(),
        "Input and output event ports should not share storage.");
    expect(outputOne.get() != outputTwo.get(),
        "Distinct output event ports should not share storage.");

    context.cleanup();
  }
};

static GraphProcessContextTest anthemGraphProcessContextTest;

} // namespace anthem
