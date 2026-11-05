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

#include "allocation_tracker.h"
#include "modules/core/engine.h"
#include "modules/processing_graph/executor/graph_executor.h"
#include "modules/processing_graph/graph_processor.h"
#include "modules/processing_graph/graph_test_helpers.h"

#include <chrono>
#include <functional>
#include <thread>

namespace anthem {

class NodeProcessingTest : public juce::UnitTest {
  using Phase = NodeProcessingState::Phase;

  class Probe : public GainProcessor {
    int64_t id;
    bool source;
  public:
    std::atomic<int> calls{0};
    float inputAudio = 0.0f;
    float inputControl = 0.0f;
    size_t inputEventCount = 0;
    Probe(int64_t id, bool source)
      : GainProcessor(GainProcessorModelImpl{.nodeId = id}), id(id), source(source) {
      isPrepared = true;
    }
    void process(NodeProcessContext& context, int numSamples) override {
      ++calls;
      if (!source) {
        inputAudio = context.getInputAudioBuffer(id * 10 + 1).getSample(0, 0);
        inputControl = context.getInputControlBuffer(id * 10 + 3).getSample(0, 0);
        inputEventCount = context.getInputEventBuffer(id * 10 + 5).getNumEvents();
      }
      auto output = context.getOutputAudioBuffer(id * 10 + 2);
      for (int channel = 0; channel < output.getNumChannels(); ++channel)
        for (int sample = 0; sample < numSamples; ++sample)
          output.setSample(channel,
              sample,
              source ? 1.0f : context.getInputAudioBuffer(id * 10 + 1).getSample(channel, sample));
      auto control = context.getOutputControlBuffer(id * 10 + 4);
      for (int sample = 0; sample < numSamples; ++sample)
        control.setSample(0, sample, 0.75f);
      context.getOutputEventBuffer(id * 10 + 6)
          .addEvent(LiveEvent{
              .sampleOffset = 0,
              .liveId = 1,
              .event = Event(NoteOnEvent(60, 0, 1.0f, 0.0f)),
          });
    }
  };

  void waitFor(const std::function<bool()>& condition) {
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!condition() && std::chrono::steady_clock::now() < deadline) {
      // The unit runner has no message loop; deliver pending timer callbacks here.
      juce::Timer::callPendingTimersSynchronously();
      juce::Thread::sleep(1);
    }
    expect(condition(), "Timed out waiting for graph-processor maintenance.");
  }

  static std::shared_ptr<Project> makeProject(const std::shared_ptr<ProcessingGraphModel>& graph =
                                                  graph_test_helpers::makeProcessingGraph()) {
    return std::make_shared<Project>(ProjectModelImpl{.processingGraph = graph});
  }

  static std::shared_ptr<Node> addProbe(ProcessingGraphModel& graph,
      int64_t id,
      const std::shared_ptr<Probe>& processor,
      bool hasInput) {
    auto node = graph_test_helpers::makeGainNode(id, processor);
    if (hasInput) {
      node->audioInputPorts()->push_back(
          graph_test_helpers::makePort(id * 10 + 1, id, NodePortDataType::audio));
      node->controlInputPorts()->push_back(
          graph_test_helpers::makePort(id * 10 + 3, id, NodePortDataType::control));
      node->eventInputPorts()->push_back(
          graph_test_helpers::makePort(id * 10 + 5, id, NodePortDataType::event));
    }
    node->audioOutputPorts()->push_back(
        graph_test_helpers::makePort(id * 10 + 2, id, NodePortDataType::audio));
    node->controlOutputPorts()->push_back(
        graph_test_helpers::makePort(id * 10 + 4, id, NodePortDataType::control));
    node->eventOutputPorts()->push_back(
        graph_test_helpers::makePort(id * 10 + 6, id, NodePortDataType::event));
    graph.nodes()->insert_or_assign(id, node);
    return node;
  }
public:
  NodeProcessingTest() : juce::UnitTest("Node processing suspension", "Processing graph") {}

  void runTest() override {
    testState();
    testInFlightCall();
    testPauseLifetime();
    testProjectReplacement();
    testGraphExecution();
    testGraphProcessorLifetime();
    testAudioSessionLifecycle();
  }

  void testState() {
    beginTest("Pause claims close entry without allocating on processing threads");
    auto state = std::make_shared<NodeProcessingState>();
    bool entered;
    {
      test::AllocationScope allocations;
      entered = state->rt_tryAcquireProcessingAccess();
      state->rt_releaseProcessingAccess();
    }
    expect(entered);
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    expect(state->phase() == Phase::running);
    auto first = std::make_shared<NodeProcessingPause>(state);
    auto second = std::make_shared<NodeProcessingPause>(state);
    expect(first->isPaused());
    first->release();
    first->release();
    {
      test::AllocationScope allocations;
      entered = state->rt_tryAcquireProcessingAccess();
    }
    expect(!entered);
    expectEquals(test::allocationCount, size_t(0));
    second.reset();
    expect(state->rt_tryAcquireProcessingAccess());
    state->rt_releaseProcessingAccess();

    beginTest("Cancelling a pending pause does not leave an old acknowledgement behind");
    expect(state->rt_tryAcquireProcessingAccess());
    auto cancelled = std::make_shared<NodeProcessingPause>(state);
    expect(state->phase() == Phase::pauseRequested);
    cancelled.reset();
    auto replacement = std::make_shared<NodeProcessingPause>(state);
    expect(!replacement->isPaused());
    state->rt_releaseProcessingAccess();
    expect(replacement->isPaused());
  }

  void testInFlightCall() {
    beginTest("Pause completion waits for in-flight work, with no further audio block required");
    auto node = graph_test_helpers::makeGainNode(1);
    const auto processor = node->getProcessor();
    auto project = makeProject();
    auto& nodes = *project->processingGraph()->nodes();
    nodes.emplace(1, node);
    EngineRuntimeServices services;
    GraphProcessor graphProcessor(services, project);
    std::atomic<bool> entered{false};
    std::atomic<bool> finish{false};
    int publishedValue = 0;
    std::thread worker([&]() {
      if (!processor->rt_tryAcquireProcessingAccess())
        return;
      entered.store(true, std::memory_order_release);
      // Waiting belongs only to this test's simulated DSP call.
      while (!finish.load(std::memory_order_acquire))
        std::this_thread::yield();
      publishedValue = 42;
      processor->rt_releaseProcessingAccess();
    });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!entered.load(std::memory_order_acquire) && std::chrono::steady_clock::now() < deadline)
      std::this_thread::yield();
    expect(entered.load());
    bool completed = false;
    std::shared_ptr<NodeProcessingPause> pause;
    graphProcessor.pauseNode(1, [&](auto result, auto error) {
      expect(!error);
      completed = true;
      pause = std::move(result);
    });
    expect(!completed);
    finish.store(true, std::memory_order_release);
    worker.join();
    waitFor([&]() { return completed; });
    expect(completed && pause && pause->isPaused());
    expectEquals(publishedValue, 42);
    expect(!processor->rt_tryAcquireProcessingAccess());
    pause.reset();
    expect(processor->rt_tryAcquireProcessingAccess());
    processor->rt_releaseProcessingAccess();

    beginTest(
        "Completion callbacks cannot grant a pause for a node removed by an earlier callback");
    expect(processor->rt_tryAcquireProcessingAccess());
    std::shared_ptr<NodeProcessingPause> first;
    bool secondCancelled = false;
    graphProcessor.pauseNode(1, [&](auto pause, auto error) {
      expect(!error);
      first = std::move(pause);
      nodes.erase(1);
      node.reset();
    });
    graphProcessor.pauseNode(
        1, [&](auto pause, auto error) { secondCancelled = !pause && error.has_value(); });
    processor->rt_releaseProcessingAccess();
    waitFor([&]() { return secondCancelled; });
    expect(secondCancelled);
    expect(first && !first->isValid());
    graphProcessor.shutdown();
  }

  void testPauseLifetime() {
    beginTest("Removing or replacing a node cancels pending and held pauses");
    auto node = graph_test_helpers::makeGainNode(1);
    auto processor = node->getProcessor();
    auto project = makeProject();
    auto& nodes = *project->processingGraph()->nodes();
    nodes.emplace(1, node);
    EngineRuntimeServices services;
    GraphProcessor graphProcessor(services, project);
    expect(processor->rt_tryAcquireProcessingAccess());
    bool cancelled = false;
    graphProcessor.pauseNode(
        1, [&](auto pause, auto error) { cancelled = !pause && error.has_value(); });
    node = graph_test_helpers::makeGainNode(1);
    nodes.insert_or_assign(1, node);
    waitFor([&]() { return cancelled; });
    expect(cancelled);
    processor->rt_releaseProcessingAccess();
    expect(
        !processor->rt_tryAcquireProcessingAccess(), "Retired graph instances must stay stopped.");

    std::shared_ptr<NodeProcessingPause> held;
    graphProcessor.pauseNode(1, [&](auto pause, auto error) {
      expect(!error);
      held = std::move(pause);
    });
    expect(held && held->isPaused());
    nodes.erase(1);
    node.reset();
    waitFor([&]() { return held && !held->isValid(); });
    expect(held && !held->isValid());

    beginTest("Graph shutdown cancels pending requests and rejects new requests");
    node = graph_test_helpers::makeGainNode(1);
    nodes.insert_or_assign(1, node);
    processor = node->getProcessor();
    expect(processor->rt_tryAcquireProcessingAccess());
    cancelled = false;
    graphProcessor.pauseNode(
        1, [&](auto pause, auto error) { cancelled = !pause && error.has_value(); });
    graphProcessor.shutdown();
    expect(cancelled);
    processor->rt_releaseProcessingAccess();
    expect(!processor->rt_tryAcquireProcessingAccess());
    cancelled = false;
    graphProcessor.pauseNode(
        1, [&](auto pause, auto error) { cancelled = !pause && error.has_value(); });
    expect(cancelled);

    beginTest("Graph shutdown invalidates already-delivered pause claims");
    node = graph_test_helpers::makeGainNode(1);
    nodes.insert_or_assign(1, node);
    processor = node->getProcessor();
    GraphProcessor active(services, project);
    active.pauseNode(1, [&](auto pause, auto error) {
      expect(!error);
      held = std::move(pause);
    });
    expect(held && held->isPaused());
    active.shutdown();
    expect(held && !held->isValid());
    expect(!processor->rt_tryAcquireProcessingAccess());

    beginTest("A caller dropping its delivered handle releases its claim");
    node = graph_test_helpers::makeGainNode(1);
    nodes.insert_or_assign(1, node);
    processor = node->getProcessor();
    GraphProcessor released(services, project);
    released.pauseNode(
        1, [&](auto pause, auto error) { expect(!error && pause && pause->isPaused()); });
    expect(processor->rt_tryAcquireProcessingAccess());
    processor->rt_releaseProcessingAccess();
  }

  void testProjectReplacement() {
    beginTest("Pause requests use the current project after it is loaded or replaced");
    std::shared_ptr<Project> project;
    EngineRuntimeServices services;
    GraphProcessor graphProcessor(services, project);
    bool rejected = false;
    graphProcessor.pauseNode(
        1, [&](auto pause, auto error) { rejected = !pause && error.has_value(); });
    expect(rejected);

    project = makeProject();
    auto node = graph_test_helpers::makeGainNode(1);
    auto pendingNode = graph_test_helpers::makeGainNode(2);
    project->processingGraph()->nodes()->emplace(1, node);
    project->processingGraph()->nodes()->emplace(2, pendingNode);
    const auto processor = node->getProcessor();
    const auto pendingProcessor = pendingNode->getProcessor();
    std::shared_ptr<NodeProcessingPause> held;
    graphProcessor.pauseNode(1, [&](auto pause, auto error) {
      expect(!error);
      held = std::move(pause);
    });
    expect(held && held->isPaused());
    expect(pendingProcessor->rt_tryAcquireProcessingAccess());
    bool cancelled = false;
    graphProcessor.pauseNode(
        2, [&](auto pause, auto error) { cancelled = !pause && error.has_value(); });
    expect(!cancelled);

    const auto previousProject = project;
    project = makeProject();
    auto replacement = graph_test_helpers::makeGainNode(1);
    project->processingGraph()->nodes()->emplace(1, replacement);
    waitFor([&]() { return cancelled; });
    expect(cancelled);
    expect(held && !held->isValid());
    expect(!processor->rt_tryAcquireProcessingAccess());
    pendingProcessor->rt_releaseProcessingAccess();
    expect(!pendingProcessor->rt_tryAcquireProcessingAccess());
    expect(previousProject->processingGraph()->nodes()->at(1) == node);

    graphProcessor.pauseNode(1, [&](auto pause, auto error) {
      expect(!error);
      held = std::move(pause);
    });
    expect(held && held->isPaused());
    project.reset();
    waitFor([&]() { return held && !held->isValid(); });
    expect(held && !held->isValid());
    graphProcessor.shutdown();
  }

  void testGraphExecution() {
    beginTest("Paused nodes clear all outputs while downstream and disconnected nodes progress");
    auto graph = graph_test_helpers::makeProcessingGraph();
    auto source = std::make_shared<Probe>(1, true);
    auto destination = std::make_shared<Probe>(2, false);
    auto independent = std::make_shared<Probe>(3, true);
    auto sourceNode = addProbe(*graph, 1, source, false);
    auto destinationNode = addProbe(*graph, 2, destination, true);
    addProbe(*graph, 3, independent, false);
    graph->connections()->emplace(100, graph_test_helpers::makeConnection(100, 1, 12, 2, 21));
    graph->connections()->emplace(
        101, graph_test_helpers::makeConnection(101, 1, 14, 2, 23, NodePortDataType::control));
    graph->connections()->emplace(
        102, graph_test_helpers::makeConnection(102, 1, 16, 2, 25, NodePortDataType::event));
    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    destinationNode->audioInputPorts()->at(0)->connections()->push_back(100);
    sourceNode->controlOutputPorts()->at(0)->connections()->push_back(101);
    destinationNode->controlInputPorts()->at(0)->connections()->push_back(101);
    sourceNode->eventOutputPorts()->at(0)->connections()->push_back(102);
    destinationNode->eventInputPorts()->at(0)->connections()->push_back(102);
    EngineRuntimeServices services;
    GraphExecutor executor;
    executor.prepare({.audioBlockSize = 8,
        .sampleRate = 48000,
        .maxActiveWorkerThreadCount = 2,
        .useRealtimeWorkerScheduling = false});
    auto runtime = RuntimeGraph::fromProcessingGraph(*graph, services, {2, 8});
    auto execution = executor.createRuntimeStateForGraph(*runtime);
    executor.rt_processBlock(*runtime, *execution, 8);
    expectEquals(source->calls.load(), 1);
    expectEquals(destination->calls.load(), 1);
    expectEquals(destination->inputAudio, 1.0f);
    expectEquals(destination->inputControl, 0.75f);
    expectEquals(destination->inputEventCount, size_t(1));
    auto project = makeProject(graph);
    GraphProcessor graphProcessor(services, project);
    std::shared_ptr<NodeProcessingPause> pause;
    graphProcessor.pauseNode(1, [&](auto result, auto error) {
      expect(!error);
      pause = std::move(result);
    });
    expect(pause->isPaused());
    {
      test::AllocationScope allocations;
      executor.rt_processBlock(*runtime, *execution, 8);
    }
    expectEquals(test::allocationCount, size_t(0));
    expectEquals(test::deallocationCount, size_t(0));
    expectEquals(source->calls.load(), 1);
    expectEquals(destination->calls.load(), 2);
    expectEquals(independent->calls.load(), 2);
    expectEquals(destination->inputAudio, 0.0f);
    expectEquals(destination->inputControl, 0.0f);
    expectEquals(destination->inputEventCount, size_t(0));

    beginTest("Graph replacement preserves pause ownership and resumption restores processing");
    runtime = RuntimeGraph::fromProcessingGraph(*graph, services, {2, 8});
    execution = executor.createRuntimeStateForGraph(*runtime);
    executor.rt_processBlock(*runtime, *execution, 8);
    expectEquals(source->calls.load(), 1);
    expectEquals(destination->calls.load(), 3);
    pause.reset();
    executor.rt_processBlock(*runtime, *execution, 8);
    expectEquals(source->calls.load(), 2);
    expectEquals(destination->inputAudio, 1.0f);

    beginTest("Replacing a node retains and stops its processor in an older runtime graph");
    graphProcessor.pauseNode(1, [&](auto result, auto error) {
      expect(!error);
      pause = std::move(result);
    });
    auto replacement = std::make_shared<Probe>(1, true);
    sourceNode = addProbe(*graph, 1, replacement, false);
    std::weak_ptr<Probe> retired = source;
    source.reset();
    waitFor([&]() { return !pause->isValid(); });
    expect(!pause->isValid());
    expect(!retired.expired(), "The old runtime graph must retain its source node and processor.");
    executor.rt_processBlock(*runtime, *execution, 8);
    expectEquals(retired.lock()->calls.load(), 2);
    expectEquals(destination->inputAudio, 0.0f);
    runtime = RuntimeGraph::fromProcessingGraph(*graph, services, {2, 8});
    execution = executor.createRuntimeStateForGraph(*runtime);
    expect(retired.expired());
    executor.rt_processBlock(*runtime, *execution, 8);
    expectEquals(replacement->calls.load(), 1);
    expectEquals(destination->inputAudio, 1.0f);
  }

  void testGraphProcessorLifetime() {
    beginTest("Graph-processor destruction invalidates pauses retained across graph clearing");
    auto node = graph_test_helpers::makeGainNode(1);
    auto project = makeProject();
    project->processingGraph()->nodes()->emplace(1, node);
    EngineRuntimeServices services;
    std::shared_ptr<NodeProcessingPause> pause;
    {
      GraphProcessor graphProcessor(services, project);
      graphProcessor.pauseNode(1, [&](auto result, auto error) {
        expect(!error);
        pause = std::move(result);
      });
      expect(pause && pause->isPaused());
      graphProcessor.clearRuntimeGraph();
      expect(pause && pause->isPaused());
    }
    expect(pause && !pause->isValid());
  }

  void testAudioSessionLifecycle() {
    beginTest("Master output suspension is rejected without affecting processing");
    Engine engine;
    auto graph = graph_test_helpers::makeProcessingGraph();
    auto source = std::make_shared<Probe>(1, true);
    auto sourceNode = addProbe(*graph, 1, source, false);
    auto masterNode = graph_test_helpers::makeMasterOutputNode(4);
    auto master = std::dynamic_pointer_cast<MasterOutputProcessor>(masterNode->getProcessor());
    master->isPrepared = true;
    master->buffer.setSize(2, 8);
    masterNode->audioInputPorts()->push_back(graph_test_helpers::makePort(
        MasterOutputProcessor::inputPortId, 4, NodePortDataType::audio));
    graph->nodes()->emplace(4, masterNode);
    graph->masterOutputNodeId() = 4;
    graph->connections()->emplace(
        100, graph_test_helpers::makeConnection(100, 1, 12, 4, MasterOutputProcessor::inputPortId));
    sourceNode->audioOutputPorts()->at(0)->connections()->push_back(100);
    masterNode->audioInputPorts()->at(0)->connections()->push_back(100);
    engine.project = std::make_shared<Project>(ProjectModelImpl{.processingGraph = graph});
    const auto start = [&]() {
      expect(engine.audioSessionController->startRenderAudioSession(48000, 8, 2).has_value());
      auto runtime =
          RuntimeGraph::fromProcessingGraph(*graph, *engine.engineRuntimeServices, {2, 8});
      engine.graphProcessor->publishRuntimeGraph(
          runtime.release(), engine.audioSessionController->getAudioProcessingConfigGeneration());
    };
    const auto process = [&]() {
      const auto result = engine.audioBlockProcessor->processAudioBlock(
          8, 48000, engine.audioSessionController->getAudioProcessingConfigGeneration());
      expect(result.didProcessGraph);
    };
    start();
    process();
    expectEquals(master->buffer.getSample(0, 0), 1.0f);
    bool rejected = false;
    engine.graphProcessor->pauseNode(
        4, [&](auto result, auto error) { rejected = !result && error.has_value(); });
    expect(rejected);
    process();
    expectEquals(master->buffer.getSample(0, 0), 1.0f);
    expectEquals(source->calls.load(), 2);

    beginTest("Held pause claims survive an audio-session stop and restart");
    std::shared_ptr<NodeProcessingPause> sourcePause;
    engine.graphProcessor->pauseNode(1, [&](auto result, auto error) {
      expect(!error);
      sourcePause = std::move(result);
    });
    process();
    expectEquals(source->calls.load(), 2);
    expectEquals(master->buffer.getSample(0, 0), 0.0f);
    engine.audioSessionController->stopAudio();
    expect(sourcePause && sourcePause->isPaused());
    start();
    process();
    expectEquals(master->buffer.getSample(0, 0), 0.0f);
    expectEquals(source->calls.load(), 2);
    sourcePause.reset();
    process();
    expectEquals(source->calls.load(), 3);
    expectEquals(master->buffer.getSample(0, 0), 1.0f);

    beginTest("Engine shutdown cancels pending and delivered graph-processor pauses");
    engine.graphProcessor->pauseNode(1, [&](auto result, auto error) {
      expect(!error);
      sourcePause = std::move(result);
    });
    expect(sourcePause && sourcePause->isPaused());
    auto pendingNode = graph_test_helpers::makeGainNode(2);
    graph->nodes()->emplace(2, pendingNode);
    const auto pendingProcessor = pendingNode->getProcessor();
    expect(pendingProcessor->rt_tryAcquireProcessingAccess());
    bool cancelled = false;
    engine.graphProcessor->pauseNode(
        2, [&](auto result, auto error) { cancelled = !result && error.has_value(); });
    expect(!cancelled);
    engine.shutdown();
    expect(cancelled);
    expect(sourcePause && !sourcePause->isValid());
    pendingProcessor->rt_releaseProcessingAccess();
    bool rejectedAfterShutdown = false;
    engine.graphProcessor->pauseNode(
        1, [&](auto result, auto error) { rejectedAfterShutdown = !result && error.has_value(); });
    expect(rejectedAfterShutdown);
  }
};

inline NodeProcessingTest nodeProcessingTest;

} // namespace anthem
