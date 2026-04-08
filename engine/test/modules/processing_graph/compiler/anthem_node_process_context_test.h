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

#include <juce_core/juce_core.h>

class AnthemNodeProcessContextTest : public juce::UnitTest {
  template <typename Callback>
  void expectThrowsRuntimeError(Callback&& callback, const juce::String& failureMessage) {
    bool didThrow = false;

    try {
      callback();
    } catch (const std::runtime_error&) {
      didThrow = true;
    }

    expect(didThrow, failureMessage);
  }

  static std::shared_ptr<Node> makeFullyBoundNode(int64_t nodeId) {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->audioInputPorts()->push_back(
        graph_test_helpers::makePort(1, nodeId, NodePortDataType::audio));
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(2, nodeId, NodePortDataType::audio));
    node->controlInputPorts()->push_back(
        graph_test_helpers::makePort(3,
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

  static AnthemNodeProcessContext& createNodeContext(std::shared_ptr<Node>& node,
                                                     AnthemGraphProcessContext& graphContext) {
    return graphContext.createNodeProcessContext(node);
  }
public:
  AnthemNodeProcessContextTest() : juce::UnitTest("AnthemNodeProcessContextTest", "Anthem") {}

  void runTest() override {
    testPortToBufferBinding();
    testParameterReadAndLiveNoteIdPassthrough();
    testClearBuffersClearsOnlyDocumentedBuffers();
    testMissingPortLookupsThrow();
  }

  void testPortToBufferBinding() {
    beginTest("Port IDs bind to the expected graph-owned buffers");

    auto node = makeFullyBoundNode(10);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 32,
                                           });
    graphContext.reserve(1, 2, 2, 2);

    auto& context = createNodeContext(node, graphContext);

    auto& inputAudioBuffer = context.getInputAudioBuffer(1);
    auto& outputAudioBuffer = context.getOutputAudioBuffer(2);
    auto& inputControlBuffer = context.getInputControlBuffer(3);
    auto& outputControlBuffer = context.getOutputControlBuffer(4);
    auto& inputEventBuffer = context.getInputEventBuffer(5);
    auto& outputEventBuffer = context.getOutputEventBuffer(6);

    expectEquals(
        inputAudioBuffer.getNumChannels(), 2, "Input audio should use the graph channel count.");
    expectEquals(
        outputAudioBuffer.getNumSamples(), 32, "Output audio should use the graph block size.");
    expect(&inputAudioBuffer != &outputAudioBuffer,
           "Input and output audio ports should bind to different buffers.");
    expectEquals(inputControlBuffer.getNumChannels(), 1, "Input control should be mono.");
    expectEquals(outputControlBuffer.getNumChannels(), 1, "Output control should be mono.");
    expectEquals(static_cast<int>(inputEventBuffer->getSize()),
                 DEFAULT_EVENT_BUFFER_SIZE,
                 "Input event ports should allocate the default event-buffer capacity.");
    expectEquals(static_cast<int>(outputEventBuffer->getSize()),
                 DEFAULT_EVENT_BUFFER_SIZE,
                 "Output event ports should allocate the default event-buffer capacity.");

    graphContext.cleanup();
  }

  void testParameterReadAndLiveNoteIdPassthrough() {
    beginTest("Parameter reads and live note IDs pass through the node context");

    auto node = makeFullyBoundNode(10);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 32,
                                           });
    graphContext.reserve(1, 2, 2, 2);

    auto& context = createNodeContext(node, graphContext);

    expectWithinAbsoluteError(context.getParameterValue(3),
                              0.25f,
                              0.0001f,
                              "Parameter values should be seeded from the port model.");
    expectEquals(static_cast<int>(context.rt_getInputParameterBindings().size()),
                 1,
                 "One control input should create one parameter binding.");
    expectEquals(context.rt_allocateLiveNoteId(),
                 0,
                 "Live note allocation should pass through the graph runtime services.");
    expectEquals(context.rt_allocateLiveNoteId(),
                 1,
                 "Live note allocation should remain monotonic across calls.");

    graphContext.cleanup();
  }

  void testClearBuffersClearsOnlyDocumentedBuffers() {
    beginTest("clearBuffers clears input audio and all event buffers");

    auto node = makeFullyBoundNode(10);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 16,
                                           });
    graphContext.reserve(1, 2, 2, 2);

    auto& context = createNodeContext(node, graphContext);

    auto& inputAudioBuffer = context.getInputAudioBuffer(1);
    auto& outputAudioBuffer = context.getOutputAudioBuffer(2);
    auto& inputEventBuffer = context.getInputEventBuffer(5);
    auto& outputEventBuffer = context.getOutputEventBuffer(6);

    inputAudioBuffer.setSample(0, 0, 0.75f);
    outputAudioBuffer.setSample(0, 0, 0.5f);
    inputEventBuffer->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.0,
        .liveId = 10,
        .event = AnthemEvent(AnthemNoteOnEvent(60, 0, 1.0f, 0.0f)),
    });
    outputEventBuffer->addEvent(AnthemLiveEvent{
        .sampleOffset = 0.0,
        .liveId = 11,
        .event = AnthemEvent(AnthemNoteOffEvent(60, 0, 0.0f)),
    });

    context.clearBuffers();

    expectWithinAbsoluteError(
        inputAudioBuffer.getSample(0, 0), 0.0f, 0.0001f, "Input audio buffers should be cleared.");
    expectWithinAbsoluteError(outputAudioBuffer.getSample(0, 0),
                              0.5f,
                              0.0001f,
                              "Output audio buffers should not be touched by clearBuffers().");
    expectEquals(static_cast<int>(inputEventBuffer->getNumEvents()),
                 0,
                 "Input event buffers should be cleared.");
    expectEquals(static_cast<int>(outputEventBuffer->getNumEvents()),
                 0,
                 "Output event buffers should be cleared.");

    graphContext.cleanup();
  }

  void testMissingPortLookupsThrow() {
    beginTest("Missing-port lookups throw with a useful failure path");

    auto node = makeFullyBoundNode(10);

    GraphRuntimeServices rtServices;
    AnthemGraphProcessContext graphContext(rtServices,
                                           AnthemGraphBufferLayout{
                                               .numAudioChannels = 2,
                                               .blockSize = 32,
                                           });
    graphContext.reserve(1, 2, 2, 2);

    auto& context = createNodeContext(node, graphContext);

    expectThrowsRuntimeError([&]() { (void)context.getInputAudioBuffer(9999); },
                             "Missing audio ports should throw.");
    expectThrowsRuntimeError([&]() { (void)context.getInputControlBuffer(9999); },
                             "Missing control ports should throw.");
    expectThrowsRuntimeError([&]() { (void)context.getInputEventBuffer(9999); },
                             "Missing event ports should throw.");
    expectThrowsRuntimeError([&]() { (void)context.getParameterValue(9999); },
                             "Missing parameter bindings should throw.");

    graphContext.cleanup();
  }
};

static AnthemNodeProcessContextTest anthemNodeProcessContextTest;
