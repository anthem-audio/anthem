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
#include "modules/processing_graph/compiler/anthem_graph_process_context.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/gain.h"
#include "modules/processors/gain_parameter_mapping.h"
#include "modules/processing_graph/graph_test_helpers.h"

#include <juce_core/juce_core.h>

class GraphCompilerActionsTest : public juce::UnitTest {
  static AnthemGraphProcessContext makeGraphContext(GraphRuntimeServices& rtServices,
                                                    int blockSize = 16) {
    return AnthemGraphProcessContext(
        rtServices,
        AnthemGraphBufferLayout{
            .numAudioChannels = 2,
            .blockSize = blockSize,
        });
  }

  static std::shared_ptr<Node> makeAudioPassNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, nodeId, NodePortDataType::audio));
    return node;
  }

  static std::shared_ptr<Node> makeControlPassNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        1,
        nodeId,
        NodePortDataType::control,
        0.0,
        graph_test_helpers::makeParameterConfig(101, 0.0)));
    node->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(2, nodeId, NodePortDataType::control));
    return node;
  }

  static std::shared_ptr<Node> makeEventPassNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);
    node->eventInputPorts()->push_back(
        graph_test_helpers::makePort(1, nodeId, NodePortDataType::event));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(2, nodeId, NodePortDataType::event));
    return node;
  }
public:
  GraphCompilerActionsTest() : juce::UnitTest("GraphCompilerActionsTest", "Anthem") {}

  void runTest() override {
    testClearBuffersAction();
    testWriteParametersToControlInputsAction();
    testCopyAudioBufferAction();
    testCopyControlBufferAction();
    testCopyEventsAction();
    testProcessNodeAction();
  }

  void testClearBuffersAction() {
    beginTest("ClearBuffersAction clears input audio and event buffers");

    auto node = makeEventPassNode(10);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(3, 10, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(4, 10, NodePortDataType::audio));

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices);
    graphContext.reserve(1, 2, 0, 2);

    auto& context = graphContext.createNodeProcessContext(node);

    context.getInputAudioBuffer(3).setSample(0, 0, 0.75f);
    context.getOutputAudioBuffer(4).setSample(0, 0, 0.5f);
    context.getInputEventBuffer(1)->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.0,
        .liveId = 1,
        .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f)),
    });
    context.getOutputEventBuffer(2)->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.0,
        .liveId = 2,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f)),
    });

    ClearBuffersAction action(&context);
    action.execute(16);

    expectWithinAbsoluteError(
        context.getInputAudioBuffer(3).getSample(0, 0), 0.0f, 0.0001f, "Input audio should be cleared.");
    expectWithinAbsoluteError(context.getOutputAudioBuffer(4).getSample(0, 0),
                              0.5f,
                              0.0001f,
                              "Output audio should be preserved.");
    expectEquals(
        static_cast<int>(context.getInputEventBuffer(1)->getNumEvents()), 0, "Input events should be cleared.");
    expectEquals(static_cast<int>(context.getOutputEventBuffer(2)->getNumEvents()),
                 0,
                 "Output events should be cleared.");

    graphContext.cleanup();
  }

  void testWriteParametersToControlInputsAction() {
    beginTest("WriteParametersToControlInputsAction writes parameter values into control buffers");

    auto node = makeControlPassNode(10);

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices, 8);
    graphContext.reserve(1, 0, 2, 0);

    auto& context = graphContext.createNodeProcessContext(node);

    WriteParametersToControlInputsAction action(&context, 48000.0f);
    action.execute(8);

    auto& controlBuffer = context.getInputControlBuffer(1);
    for (int sample = 0; sample < 8; ++sample) {
      expectWithinAbsoluteError(controlBuffer.getSample(0, sample),
                                0.0f,
                                0.0001f,
                                "Control buffer should be initialized from the parameter value.");
    }

    graphContext.cleanup();
  }

  void testCopyAudioBufferAction() {
    beginTest("CopyAudioBufferAction adds source audio into the destination input");

    auto sourceNode = makeAudioPassNode(10);
    auto destinationNode = makeAudioPassNode(20);

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices, 4);
    graphContext.reserve(2, 4, 0, 0);

    auto& sourceContext = graphContext.createNodeProcessContext(sourceNode);
    auto& destinationContext = graphContext.createNodeProcessContext(destinationNode);

    auto& sourceBuffer = sourceContext.getOutputAudioBuffer(2);
    auto& destinationBuffer = destinationContext.getInputAudioBuffer(1);
    sourceBuffer.setSample(0, 0, 0.25f);
    sourceBuffer.setSample(1, 0, 0.5f);
    destinationBuffer.setSample(0, 0, 0.75f);
    destinationBuffer.setSample(1, 0, 0.25f);

    CopyAudioBufferAction action(&sourceContext, 2, &destinationContext, 1);
    action.execute(4);

    expectWithinAbsoluteError(
        destinationBuffer.getSample(0, 0), 1.0f, 0.0001f, "Audio copy should sum the source into the destination.");
    expectWithinAbsoluteError(destinationBuffer.getSample(1, 0),
                              0.75f,
                              0.0001f,
                              "Audio copy should sum per-channel samples independently.");

    graphContext.cleanup();
  }

  void testCopyControlBufferAction() {
    beginTest("CopyControlBufferAction overwrites destination control values");

    auto sourceNode = makeControlPassNode(10);
    auto destinationNode = makeControlPassNode(20);

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices, 4);
    graphContext.reserve(2, 0, 4, 0);

    auto& sourceContext = graphContext.createNodeProcessContext(sourceNode);
    auto& destinationContext = graphContext.createNodeProcessContext(destinationNode);

    auto& sourceBuffer = sourceContext.getOutputControlBuffer(2);
    auto& destinationBuffer = destinationContext.getInputControlBuffer(1);
    sourceBuffer.setSample(0, 0, 0.25f);
    sourceBuffer.setSample(0, 1, 0.75f);
    destinationBuffer.setSample(0, 0, 0.9f);
    destinationBuffer.setSample(0, 1, 0.1f);

    CopyControlBufferAction action(&sourceContext, 2, &destinationContext, 1);
    action.execute(4);

    expectWithinAbsoluteError(destinationBuffer.getSample(0, 0),
                              0.25f,
                              0.0001f,
                              "Control copy should overwrite existing destination samples.");
    expectWithinAbsoluteError(destinationBuffer.getSample(0, 1),
                              0.75f,
                              0.0001f,
                              "Control copy should preserve the source values exactly.");

    graphContext.cleanup();
  }

  void testCopyEventsAction() {
    beginTest("CopyEventsAction appends source events to the destination input buffer");

    auto sourceNode = makeEventPassNode(10);
    auto destinationNode = makeEventPassNode(20);

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices, 4);
    graphContext.reserve(2, 0, 0, 4);

    auto& sourceContext = graphContext.createNodeProcessContext(sourceNode);
    auto& destinationContext = graphContext.createNodeProcessContext(destinationNode);

    sourceContext.getOutputEventBuffer(2)->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.5,
        .liveId = 10,
        .event = AnthemEvent(AnthemNoteOnEvent(64, 0, 1.0f, 0.0f)),
    });
    destinationContext.getInputEventBuffer(1)->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.25,
        .liveId = 9,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f)),
    });

    CopyEventsAction action(&sourceContext, 2, &destinationContext, 1);
    action.execute(4);

    auto& destinationBuffer = destinationContext.getInputEventBuffer(1);
    expectEquals(static_cast<int>(destinationBuffer->getNumEvents()),
                 2,
                 "Event copy should append source events to existing destination events.");
    expectWithinAbsoluteError(destinationBuffer->getEvent(1).sampleOffset,
                              0.5,
                              0.0001,
                              "Copied events should preserve their sample offsets.");
    expectEquals(destinationBuffer->getEvent(1).liveId,
                 10,
                 "Copied events should preserve their live note IDs.");

    graphContext.cleanup();
  }

  void testProcessNodeAction() {
    beginTest("ProcessNodeAction delegates processing to the wrapped processor");

    auto node = graph_test_helpers::makeGainNode(10);
    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::audioInputPortId, 10, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(GainProcessorModelBase::audioOutputPortId, 10, NodePortDataType::audio));
    node->controlInputPorts()->push_back(graph_test_helpers::makePort(
        GainProcessorModelBase::gainPortId,
        10,
        NodePortDataType::control,
        kGainParameterZeroDbNormalized,
        graph_test_helpers::makeParameterConfig(101, kGainParameterZeroDbNormalized)));

    GraphRuntimeServices rtServices;
    auto graphContext = makeGraphContext(rtServices, 4);
    graphContext.reserve(1, 2, 1, 0);

    auto& context = graphContext.createNodeProcessContext(node);
    auto processor = node->getProcessor();
    expect(processor.has_value(), "Gain node should expose a processor instance.");

    auto& audioInBuffer = context.getInputAudioBuffer(GainProcessorModelBase::audioInputPortId);
    auto& audioOutBuffer = context.getOutputAudioBuffer(GainProcessorModelBase::audioOutputPortId);
    auto& controlBuffer = context.getInputControlBuffer(GainProcessorModelBase::gainPortId);

    audioInBuffer.setSample(0, 0, 0.5f);
    audioInBuffer.setSample(1, 0, 0.25f);
    for (int sample = 0; sample < 4; ++sample) {
      controlBuffer.setSample(0, sample, kGainParameterZeroDbNormalized);
    }

    ProcessNodeAction action(&context, processor.value().get());
    action.execute(4);

    auto expectedGain = gainParameterValueToLinear(kGainParameterZeroDbNormalized);
    expectWithinAbsoluteError(audioOutBuffer.getSample(0, 0),
                              0.5f * expectedGain,
                              0.0001f,
                              "Process action should invoke the processor with the node context.");
    expectWithinAbsoluteError(audioOutBuffer.getSample(1, 0),
                              0.25f * expectedGain,
                              0.0001f,
                              "Process action should write the processor output buffer.");

    graphContext.cleanup();
  }
};

static GraphCompilerActionsTest graphCompilerActionsTest;
