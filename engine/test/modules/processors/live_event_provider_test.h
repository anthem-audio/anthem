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
#include "modules/processing_graph/runtime/graph_process_context.h"
#include "modules/processing_graph/runtime/graph_runtime_services.h"
#include "modules/processors/live_event_provider.h"

#include <juce_core/juce_core.h>

namespace anthem {

class LiveEventProviderProcessorTest : public juce::UnitTest {
  static constexpr int64_t nodeId = 1003;
  static constexpr LiveInputNoteId firstInputId = 101;
  static constexpr LiveInputNoteId secondInputId = 102;
  static constexpr size_t trackedNoteCapacity = 1024;

  static std::shared_ptr<Node> makeNode() {
    auto node = graph_test_helpers::makeNode(nodeId);

    node->eventOutputPorts()->push_back(graph_test_helpers::makePort(
        LiveEventProviderProcessorModelBase::eventOutputPortId, nodeId, NodePortDataType::event));

    return node;
  }

  static LiveInputEvent makeNoteOn(int sampleOffset,
      LiveInputNoteId inputId,
      int16_t pitch,
      int16_t channel = 0,
      float velocity = 1.0f,
      float detune = 0.0f) {
    return LiveInputEvent{
        .sampleOffset = sampleOffset,
        .inputId = inputId,
        .event = Event(NoteOnEvent(pitch, channel, velocity, detune)),
    };
  }

  static LiveInputEvent makeNoteOff(int sampleOffset,
      LiveInputNoteId inputId,
      int16_t pitch,
      int16_t channel = 0,
      float velocity = 0.0f) {
    return LiveInputEvent{
        .sampleOffset = sampleOffset,
        .inputId = inputId,
        .event = Event(NoteOffEvent(pitch, channel, velocity)),
    };
  }

  static LiveInputEvent makeAllVoicesOff(int sampleOffset) {
    return LiveInputEvent{
        .sampleOffset = sampleOffset,
        .inputId = invalidLiveInputNoteId,
        .event = Event(AllVoicesOffEvent()),
    };
  }

  static EventBuffer& getOutputBuffer(NodeProcessContext& context) {
    return context.getOutputEventBuffer(LiveEventProviderProcessorModelBase::eventOutputPortId);
  }

  void expectEventBase(EventBuffer& buffer,
      size_t index,
      EventType type,
      int sampleOffset,
      LiveNoteId liveId,
      const juce::String& context) {
    expect(buffer.getNumEvents() > index, context + " event index should exist");
    const auto& event = buffer.getEvent(index);

    expectEquals(static_cast<int>(event.event.type), static_cast<int>(type), context + " type");
    expectEquals(event.sampleOffset, sampleOffset, context + " offset");
    expectEquals(event.liveId, liveId, context + " live ID");
  }

  void expectNoteOn(EventBuffer& buffer,
      size_t index,
      int sampleOffset,
      LiveNoteId liveId,
      int16_t pitch,
      int16_t channel,
      float velocity,
      float detune,
      const juce::String& context) {
    expectEventBase(buffer, index, EventType::NoteOn, sampleOffset, liveId, context);

    const auto& event = buffer.getEvent(index);
    expectEquals(event.event.noteOn.pitch, pitch, context + " pitch");
    expectEquals(event.event.noteOn.channel, channel, context + " channel");
    expectWithinAbsoluteError(
        event.event.noteOn.velocity, velocity, 0.0001f, context + " velocity");
    expectWithinAbsoluteError(event.event.noteOn.detune, detune, 0.0001f, context + " detune");
  }

  void expectNoteOff(EventBuffer& buffer,
      size_t index,
      int sampleOffset,
      LiveNoteId liveId,
      int16_t pitch,
      int16_t channel,
      float velocity,
      const juce::String& context) {
    expectEventBase(buffer, index, EventType::NoteOff, sampleOffset, liveId, context);

    const auto& event = buffer.getEvent(index);
    expectEquals(event.event.noteOff.pitch, pitch, context + " pitch");
    expectEquals(event.event.noteOff.channel, channel, context + " channel");
    expectWithinAbsoluteError(
        event.event.noteOff.velocity, velocity, 0.0001f, context + " velocity");
  }

  void expectAllVoicesOff(
      EventBuffer& buffer, size_t index, int sampleOffset, const juce::String& context) {
    expectEventBase(
        buffer, index, EventType::AllVoicesOff, sampleOffset, invalidLiveNoteId, context);
  }
public:
  LiveEventProviderProcessorTest() : juce::UnitTest("LiveEventProviderProcessorTest", "Anthem") {}

  void runTest() override {
    testQueueDrainsInOrder();
    testTrackedNoteOffUsesOriginalLiveId();
    testUnmatchedNoteOffPassesThrough();
    testNonNoteEventsPassThrough();
    testTrackedNoteOverflowEmitsInvalidLiveId();
    testInputQueueOverflowReportsRejectedEvents();
  }

  void testQueueDrainsInOrder() {
    beginTest("Live event provider drains queued events in FIFO order");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});

    expect(processor.addLiveInputEvent(makeNoteOn(1, firstInputId, 60, 1, 0.75f, 2.0f)),
        "First event should be queued");
    expect(processor.addLiveInputEvent(makeAllVoicesOff(2)), "Second event should be queued");
    expect(processor.addLiveInputEvent(makeNoteOff(3, secondInputId, 64, 2, 0.25f)),
        "Third event should be queued");

    auto& outputBuffer = getOutputBuffer(context);
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 3, "All queued events should emit");
    expectNoteOn(outputBuffer, 0, 1, 0, 60, 1, 0.75f, 2.0f, "First queued event");
    expectAllVoicesOff(outputBuffer, 1, 2, "Second queued event");
    expectNoteOff(outputBuffer, 2, 3, invalidLiveNoteId, 64, 2, 0.25f, "Third queued event");

    outputBuffer.clear();
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 0, "The queue should be drained");

    graphContext.cleanup();
  }

  void testTrackedNoteOffUsesOriginalLiveId() {
    beginTest("Tracked live note-offs use the original live ID and note shape");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});
    auto& outputBuffer = getOutputBuffer(context);

    expect(processor.addLiveInputEvent(makeNoteOn(0, firstInputId, 60, 3, 0.8f, 4.0f)),
        "Note-on should be queued");
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 1, "One note-on should emit");
    expectNoteOn(outputBuffer, 0, 0, 0, 60, 3, 0.8f, 4.0f, "Tracked note-on");

    outputBuffer.clear();

    expect(processor.addLiveInputEvent(makeNoteOff(1, firstInputId, 99, 7, 0.3f)),
        "Note-off should be queued");
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 1, "One note-off should emit");
    expectNoteOff(outputBuffer, 0, 1, 0, 60, 3, 0.0f, "Tracked note-off");

    graphContext.cleanup();
  }

  void testUnmatchedNoteOffPassesThrough() {
    beginTest("Unmatched live note-offs pass through with an invalid live ID");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});
    auto& outputBuffer = getOutputBuffer(context);

    expect(processor.addLiveInputEvent(makeNoteOff(2, secondInputId, 67, 4, 0.35f)),
        "Unmatched note-off should be queued");
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 1, "One note-off should emit");
    expectNoteOff(outputBuffer, 0, 2, invalidLiveNoteId, 67, 4, 0.35f, "Unmatched note-off");

    graphContext.cleanup();
  }

  void testNonNoteEventsPassThrough() {
    beginTest("Non-note live events pass through with invalid live IDs");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});
    auto& outputBuffer = getOutputBuffer(context);

    expect(processor.addLiveInputEvent(makeAllVoicesOff(4)), "All-voices-off should be queued");
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 1, "One event should emit");
    expectAllVoicesOff(outputBuffer, 0, 4, "All-voices-off event");

    graphContext.cleanup();
  }

  void testTrackedNoteOverflowEmitsInvalidLiveId() {
    beginTest("Tracked note overflow emits note-ons with invalid live IDs");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});
    auto& outputBuffer = getOutputBuffer(context);

    for (size_t i = 0; i <= trackedNoteCapacity; ++i) {
      expect(processor.addLiveInputEvent(
                 makeNoteOn(static_cast<int>(i), static_cast<LiveInputNoteId>(i), 60)),
          "Note-on should fit in the input queue");
    }

    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()),
        static_cast<int>(trackedNoteCapacity + 1),
        "All queued note-ons should emit");
    expectNoteOn(outputBuffer, 0, 0, 0, 60, 0, 1.0f, 0.0f, "First tracked note");
    expectNoteOn(outputBuffer,
        trackedNoteCapacity - 1,
        static_cast<int>(trackedNoteCapacity - 1),
        static_cast<LiveNoteId>(trackedNoteCapacity - 1),
        60,
        0,
        1.0f,
        0.0f,
        "Last tracked note");
    expectNoteOn(outputBuffer,
        trackedNoteCapacity,
        static_cast<int>(trackedNoteCapacity),
        invalidLiveNoteId,
        60,
        0,
        1.0f,
        0.0f,
        "Overflow note");

    outputBuffer.clear();

    expect(processor.addLiveInputEvent(
               makeNoteOff(8, static_cast<LiveInputNoteId>(trackedNoteCapacity), 72, 2, 0.5f)),
        "Overflow note-off should be queued");
    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()), 1, "One note-off should emit");
    expectNoteOff(outputBuffer, 0, 8, invalidLiveNoteId, 72, 2, 0.5f, "Overflow note-off");

    graphContext.cleanup();
  }

  void testInputQueueOverflowReportsRejectedEvents() {
    beginTest("Input queue overflow reports rejected events");

    auto node = makeNode();
    GraphRuntimeServices rtServices;
    GraphProcessContext graphContext(rtServices,
        GraphBufferLayout{
            .numAudioChannels = 0,
            .blockSize = 1,
        });
    graphContext.reserve(1, 0, 0, 1);

    auto& context = graph_test_helpers::createStandaloneNodeProcessContext(graphContext, node);
    auto processor =
        LiveEventProviderProcessor(LiveEventProviderProcessorModelImpl{.nodeId = nodeId});
    auto& outputBuffer = getOutputBuffer(context);

    int acceptedCount = 0;
    bool sawRejectedEvent = false;

    for (int i = 0; i < 5000; ++i) {
      if (processor.addLiveInputEvent(makeAllVoicesOff(i))) {
        acceptedCount++;
        continue;
      }

      sawRejectedEvent = true;
      break;
    }

    expect(acceptedCount > 0, "The input queue should accept events before it fills");
    expect(sawRejectedEvent, "The input queue should report when it is full");

    processor.process(context, 1);

    expectEquals(static_cast<int>(outputBuffer.getNumEvents()),
        acceptedCount,
        "Only accepted input events should be emitted");
    expectAllVoicesOff(outputBuffer, 0, 0, "First accepted event");
    expectAllVoicesOff(outputBuffer,
        static_cast<size_t>(acceptedCount - 1),
        acceptedCount - 1,
        "Last accepted event");

    graphContext.cleanup();
  }
};

static LiveEventProviderProcessorTest liveEventProviderProcessorTest;

} // namespace anthem
